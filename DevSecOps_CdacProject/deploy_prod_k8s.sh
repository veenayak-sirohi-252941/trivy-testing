#!/bin/bash

###############################################################################
# Bash Strict Mode
###############################################################################
set -euo pipefail

###############################################################################
# Change to the directory containing this script
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
echo "Deploying Kubernetes Resources..."
echo "=================================================="

###############################################################################
# Namespace selection for this deployment run
###############################################################################
APP_NAMESPACE="${APP_NAMESPACE:-prod}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.7.2}"

wait_for_jobs() {
  local failed=0
  local pid

  for pid in "$@"; do
    wait "$pid" || failed=1
  done

  return "$failed"
}

###############################################################################
# Change to the Kubernetes manifests directory
###############################################################################
MANIFEST_DIR="k8s/prod"
cd "$MANIFEST_DIR"

###############################################################################
# Create Namespace
###############################################################################
kubectl apply -f ../namespace.yaml

echo ""
echo "=================================================="
echo "Ensuring Metrics Server is installed for HPA..."
echo "=================================================="
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

###############################################################################
# Apply Secrets
###############################################################################
kubectl apply -f secrets.yaml

###############################################################################
# Deploy workloads and services in parallel, then wait for rollouts in parallel
###############################################################################
kubectl apply -f database-deployment.yaml &
apply_db_deploy_pid=$!
kubectl apply -f database-service.yaml &
apply_db_svc_pid=$!
kubectl apply -f backend-deployment.yaml &
apply_backend_deploy_pid=$!
kubectl apply -f backend-service.yaml &
apply_backend_svc_pid=$!
kubectl apply -f frontend-deployment.yaml &
apply_frontend_deploy_pid=$!
kubectl apply -f frontend-service.yaml &
apply_frontend_svc_pid=$!
kubectl apply -f backend-hpa.yaml &
apply_backend_hpa_pid=$!
kubectl apply -f frontend-hpa.yaml &
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

kubectl rollout status deployment/database -n "$APP_NAMESPACE" --timeout=300s &
rollout_db_pid=$!
kubectl rollout status deployment/backend -n "$APP_NAMESPACE" --timeout=300s &
rollout_backend_pid=$!
kubectl rollout status deployment/frontend -n "$APP_NAMESPACE" --timeout=300s &
rollout_frontend_pid=$!

wait_for_jobs "$rollout_db_pid" "$rollout_backend_pid" "$rollout_frontend_pid"

echo ""
echo "=================================================="
echo "Deployment completed successfully!"
echo "=================================================="

kubectl get all -n "$APP_NAMESPACE"
kubectl get hpa -n "$APP_NAMESPACE"

kubectl get svc frontend -n "$APP_NAMESPACE"
