#!/bin/bash
###############################################################################
# deploy_preprod_k8s.sh
#
# Deploys the application (namespaces, secrets, database/backend/frontend)
# to the preprod EKS environment.
#
# NOTE: Monitoring is handled by Prometheus/Grafana. Keep this script focused
# on Kubernetes application manifests only.
#
# Requires: aws cli v2, kubectl already pointed at the target cluster
# (kubeconfig set up by the calling workflow step).
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

K8S_DIR="$SCRIPT_DIR/k8s"
PREPROD_DIR="$K8S_DIR/preprod"
APP_NAMESPACE="${APP_NAMESPACE:-preprod}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.7.2}"

wait_for_jobs() {
  local failed=0
  local pid

  for pid in "$@"; do
    wait "$pid" || failed=1
  done

  return "$failed"
}

echo "=================================================="
echo "Verifying cluster connectivity..."
echo "=================================================="
kubectl get nodes

echo ""
echo "=================================================="
echo "Deploying Kubernetes Resources..."
echo "=================================================="

echo ""
echo "=================================================="
echo "Ensuring Metrics Server is installed for HPA..."
echo "=================================================="
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

# --- Namespaces -------------------------------------------------------------
kubectl apply -f "$K8S_DIR/namespace.yaml"

# --- Secrets ------------------------------------------------------------
kubectl apply -f "$PREPROD_DIR/secrets.yaml"

# --- Workloads and Services ---------------------------------------------
kubectl apply -f "$PREPROD_DIR/database-pvc.yaml"

kubectl apply -f "$PREPROD_DIR/database-deployment.yaml" &
apply_db_deploy_pid=$!
kubectl apply -f "$PREPROD_DIR/database-service.yaml" &
apply_db_svc_pid=$!
kubectl apply -f "$PREPROD_DIR/backend-deployment.yaml" &
apply_backend_deploy_pid=$!
kubectl apply -f "$PREPROD_DIR/backend-service.yaml" &
apply_backend_svc_pid=$!
kubectl apply -f "$PREPROD_DIR/frontend-deployment.yaml" &
apply_frontend_deploy_pid=$!
kubectl apply -f "$PREPROD_DIR/frontend-service.yaml" &
apply_frontend_svc_pid=$!
kubectl apply -f "$PREPROD_DIR/backend-hpa.yaml" &
apply_backend_hpa_pid=$!
kubectl apply -f "$PREPROD_DIR/frontend-hpa.yaml" &
apply_frontend_hpa_pid=$!

wait_for_jobs \
  "$apply_db_deploy_pid" \
  "$apply_db_svc_pid" \
  "$apply_backend_deploy_pid" \
  "$apply_backend_svc_pid" \
  "$apply_frontend_deploy_pid" \
  "$apply_frontend_svc_pid" \
  "$apply_backend_hpa_pid" \
  "$apply_frontend_hpa_pid"

kubectl rollout status deployment/database -n "$APP_NAMESPACE" --timeout=180s &
rollout_db_pid=$!
kubectl rollout status deployment/backend -n "$APP_NAMESPACE" --timeout=180s &
rollout_backend_pid=$!
kubectl rollout status deployment/frontend -n "$APP_NAMESPACE" --timeout=180s &
rollout_frontend_pid=$!

wait_for_jobs "$rollout_db_pid" "$rollout_backend_pid" "$rollout_frontend_pid"

###############################################################################
# Deploy Wazuh agent DaemonSet
#
# Regenerated from template every run (not sed-edited in place) for the same
# idempotency reason as provision_infrastructure.sh: once WAZUH_PUBLIC_IP is
# replaced in a committed file, a second run would find nothing to replace
# and silently keep a stale IP if the Wazuh EC2 was ever recreated.
###############################################################################
WAZUH_TEMPLATE="$K8S_DIR/wazuh-agent-daemonset.yaml.tpl"
WAZUH_MANIFEST="$K8S_DIR/wazuh-agent-daemonset.yaml"

if [ -z "${WAZUH_PUBLIC_IP:-}" ]; then
  echo ""
  echo "WARNING: WAZUH_PUBLIC_IP is not set — skipping Wazuh agent deployment."
elif [ ! -f "$WAZUH_TEMPLATE" ]; then
  echo ""
  echo "WARNING: $WAZUH_TEMPLATE not found — skipping Wazuh agent deployment."
else
  echo ""
  echo "=================================================="
  echo "Deploying Wazuh agent DaemonSet..."
  echo "=================================================="
  sed "s|WAZUH_PUBLIC_IP|${WAZUH_PUBLIC_IP}|g" "$WAZUH_TEMPLATE" > "$WAZUH_MANIFEST"
  kubectl apply -f "$WAZUH_MANIFEST"
  kubectl -n wazuh rollout status daemonset/wazuh-agent --timeout=120s || \
    echo "WARNING: Wazuh agent DaemonSet did not report ready within timeout — check 'kubectl get pods -n wazuh'."
fi

echo ""
echo "=================================================="
echo "Preprod deployment complete."
echo "=================================================="
kubectl get pods -n "$APP_NAMESPACE"
kubectl get svc -n "$APP_NAMESPACE"
kubectl get hpa -n "$APP_NAMESPACE"
kubectl get pods -n wazuh 2>/dev/null || true
