#!/bin/bash
###############################################################################
# deploy_monitoring.sh
#
# Installs/updates Prometheus + Grafana on the current Kubernetes cluster using
# kube-prometheus-stack.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
KUBE_PROMETHEUS_STACK_VERSION="${KUBE_PROMETHEUS_STACK_VERSION:-62.7.0}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
VALUES_FILE="$SCRIPT_DIR/k8s/monitoring/monitoring-values.yaml"

if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
  echo "ERROR: GRAFANA_ADMIN_PASSWORD is required for Grafana admin login."
  echo "Set it as a GitHub Actions secret for CI or export it before running this script locally."
  exit 1
fi

echo "=================================================="
echo "Verifying cluster connectivity..."
echo "=================================================="
kubectl get nodes

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is required to deploy kube-prometheus-stack."
  exit 1
fi

echo ""
echo "=================================================="
echo "Creating monitoring namespace and Grafana secret..."
echo "=================================================="
kubectl create namespace "$MONITORING_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic grafana-admin-secret \
  --namespace "$MONITORING_NAMESPACE" \
  --from-literal=admin-user="$GRAFANA_ADMIN_USER" \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=================================================="
echo "Installing kube-prometheus-stack ${KUBE_PROMETHEUS_STACK_VERSION}..."
echo "=================================================="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NAMESPACE" \
  --version "$KUBE_PROMETHEUS_STACK_VERSION" \
  -f "$VALUES_FILE" \
  --wait \
  --timeout 10m

echo ""
echo "=================================================="
echo "Monitoring deployment complete."
echo "=================================================="
kubectl get pods -n "$MONITORING_NAMESPACE"
kubectl get svc monitoring-grafana -n "$MONITORING_NAMESPACE"
kubectl get svc -n "$MONITORING_NAMESPACE" | grep -i prometheus || true

echo ""
echo "Waiting for Grafana LoadBalancer hostname..."
GRAFANA_HOSTNAME=""
for i in $(seq 1 30); do
  GRAFANA_HOSTNAME="$(kubectl get svc monitoring-grafana -n "$MONITORING_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [ -n "$GRAFANA_HOSTNAME" ]; then
    break
  fi
  sleep 10
done

if [ -n "$GRAFANA_HOSTNAME" ]; then
  echo "Grafana URL: http://${GRAFANA_HOSTNAME}"
  echo "Grafana username: ${GRAFANA_ADMIN_USER}"
else
  echo "Grafana LoadBalancer hostname is not ready yet. Recheck with:"
  echo "kubectl get svc monitoring-grafana -n ${MONITORING_NAMESPACE}"
fi
