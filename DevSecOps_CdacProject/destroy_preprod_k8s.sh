#!/bin/bash

###############################################################################
# Bash Strict Mode
###############################################################################
set -euo pipefail

###############################################################################
# Change to the directory containing this script
###############################################################################
cd "$(dirname "$0")"

###############################################################################
# Verify Kubernetes Cluster Connectivity
# (kubeconfig is already configured by the calling workflow step)
###############################################################################
echo "=================================================="
echo "Verifying cluster connectivity..."
echo "=================================================="
kubectl get nodes

echo ""
echo "=================================================="
echo "Deleting Kubernetes Resources..."
echo "=================================================="

###############################################################################
# Target namespace selection for this teardown run
###############################################################################
TARGET_NAMESPACE="${TARGET_NAMESPACE:-preprod}"
GRACE_WAIT_SECONDS="${GRACE_WAIT_SECONDS:-20}"
NAMESPACE_WAIT_SECONDS="${NAMESPACE_WAIT_SECONDS:-60}"
WAIT_FOR_NODES_READY="${WAIT_FOR_NODES_READY:-false}"

wait_for_jobs() {
  local failed=0
  local pid

  for pid in "$@"; do
    wait "$pid" || failed=1
  done

  return "$failed"
}

###############################################################################
# Change to Kubernetes manifests directory
###############################################################################
MANIFEST_DIR="k8s/preprod"
cd "$MANIFEST_DIR"

###############################################################################
# Delete Frontend, Backend, Database Resources (no blocking wait)
###############################################################################
echo "Deleting Frontend..."
kubectl delete -f frontend-hpa.yaml --ignore-not-found --wait=false || true &
delete_frontend_hpa_pid=$!
kubectl delete -f frontend-deployment.yaml --ignore-not-found --wait=false || true &
delete_frontend_deploy_pid=$!
kubectl delete -f frontend-service.yaml --ignore-not-found --wait=false || true &
delete_frontend_svc_pid=$!

echo "Deleting Backend..."
kubectl delete -f backend-hpa.yaml --ignore-not-found --wait=false || true &
delete_backend_hpa_pid=$!
kubectl delete -f backend-deployment.yaml --ignore-not-found --wait=false || true &
delete_backend_deploy_pid=$!
kubectl delete -f backend-service.yaml --ignore-not-found --wait=false || true &
delete_backend_svc_pid=$!

echo "Deleting Database..."
kubectl delete -f database-deployment.yaml --ignore-not-found --wait=false || true &
delete_database_deploy_pid=$!
kubectl delete -f database-service.yaml --ignore-not-found --wait=false || true &
delete_database_svc_pid=$!

wait_for_jobs \
  "$delete_frontend_hpa_pid" \
  "$delete_frontend_deploy_pid" \
  "$delete_frontend_svc_pid" \
  "$delete_backend_hpa_pid" \
  "$delete_backend_deploy_pid" \
  "$delete_backend_svc_pid" \
  "$delete_database_deploy_pid" \
  "$delete_database_svc_pid" || true

###############################################################################
# Delete Monitoring Stack (Prometheus + Grafana via kube-prometheus-stack)
###############################################################################
echo ""
echo "Deleting Monitoring Stack..."
if command -v helm >/dev/null 2>&1; then
  helm uninstall monitoring --namespace monitoring || true &
  helm_uninstall_pid=$!
else
  echo "helm not found on runner, skipping helm uninstall (install helm in the calling workflow step before running this script)"
  helm_uninstall_pid=""
fi
kubectl delete secret grafana-admin-secret -n monitoring --ignore-not-found --wait=false || true &
delete_grafana_secret_pid=$!
kubectl delete namespace monitoring --ignore-not-found --wait=false || true &
delete_monitoring_ns_pid=$!

if [ -n "$helm_uninstall_pid" ]; then
  wait_for_jobs "$helm_uninstall_pid" "$delete_grafana_secret_pid" "$delete_monitoring_ns_pid" || true
else
  wait_for_jobs "$delete_grafana_secret_pid" "$delete_monitoring_ns_pid" || true
fi

###############################################################################
# Give pods a short grace period to terminate normally
###############################################################################
echo ""
echo "Waiting up to ${GRACE_WAIT_SECONDS}s for pods to terminate gracefully..."
for i in $(seq 1 "$GRACE_WAIT_SECONDS"); do
  all_pods=$(kubectl get pods -n "$TARGET_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}' || true)
  if [ -z "$all_pods" ]; then
    break
  fi
  sleep 1
done

###############################################################################
# Force-delete any pods still stuck in Terminating
###############################################################################
echo "Force-deleting any stuck Terminating pods..."
for ns in "$TARGET_NAMESPACE"; do
  all_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '{print $1}' || true)
  if [ -n "$all_pods" ]; then
    echo "  Force-deleting all remaining pods in namespace '$ns'..."
    kubectl delete pods -n "$ns" --all --grace-period=0 --force 2>/dev/null || true
  fi
done

###############################################################################
# Delete focused namespaces
###############################################################################
echo "Deleting Namespaces..."
kubectl delete namespace "$TARGET_NAMESPACE" --ignore-not-found --wait=false || true

###############################################################################
# Wait for namespaces to fully terminate
###############################################################################
echo ""
echo "Waiting for namespaces to fully terminate..."
for ns in "$TARGET_NAMESPACE"; do
  echo -n "  Waiting for namespace '$ns'..."
  terminated=false
  for i in $(seq 1 "$NAMESPACE_WAIT_SECONDS"); do
    if ! kubectl get namespace "$ns" &>/dev/null; then
      echo " gone."
      terminated=true
      break
    fi
    echo -n "."
    sleep 1
  done
  if [ "$terminated" = false ]; then
    echo ""
    echo "  WARNING: '$ns' still stuck after ${NAMESPACE_WAIT_SECONDS}s — force-patching finalizers..."
    kubectl get namespace "$ns" -o json \
      | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
      | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
    sleep 5
    if ! kubectl get namespace "$ns" &>/dev/null; then
      echo "  '$ns' gone after finalizer patch."
    else
      echo "  WARNING: '$ns' still present — manual cleanup may be needed."
    fi
  fi
done

echo ""
echo "=================================================="
echo "Kubernetes resources deleted successfully!"
echo "=================================================="

###############################################################################
# Verify Remaining Resources
###############################################################################
kubectl get all -n "$TARGET_NAMESPACE" 2>&1 || echo "$TARGET_NAMESPACE namespace no longer exists."

###############################################################################
# Wait for all nodes to return to Ready
###############################################################################
if [ "$WAIT_FOR_NODES_READY" != "true" ]; then
  echo ""
  echo "Skipping node readiness wait. Set WAIT_FOR_NODES_READY=true to enable it."
  echo ""
  echo "=================================================="
  echo "Destroy complete. Safe to deploy."
  echo "=================================================="
  exit 0
fi

echo ""
echo "Waiting for all nodes to be Ready (up to 5 minutes)..."
for i in $(seq 1 60); do
  not_ready=$(kubectl get nodes --no-headers 2>/dev/null \
    | grep -vc " Ready " || true)
  if [ "$not_ready" -eq 0 ]; then
    echo "All nodes are Ready."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "WARNING: Some nodes still NotReady after 300s — proceeding anyway."
    kubectl get nodes
    break
  fi
  if [ $(( i % 6 )) -eq 0 ]; then
    echo ""
    echo "  Status at ${i}x5s:"
    kubectl get nodes --no-headers 2>/dev/null || true
  else
    echo -n "  ($not_ready node(s) not ready)."
  fi
  sleep 5
done

echo ""
echo "=================================================="
echo "Destroy complete. Safe to deploy."
echo "=================================================="
