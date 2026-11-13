#!/bin/bash

###############################################################################
# Exit on error, undefined variable, or pipeline failure
###############################################################################
set -euo pipefail

PROJECT_ROOT="/home/veena/DevSecOps_CdacProject"

BASE_DIR="$PROJECT_ROOT/infra/terraform"
EKS_DIR="$BASE_DIR/eks"
TOOLS_DIR="$BASE_DIR/monitoring-security"

LOG_DIR="/tmp/destroy-logs-$$"
mkdir -p "$LOG_DIR"

run_terraform_destroy() {
  local name="$1"
  local dir="$2"

  echo ""
  echo "=================================================="
  echo "Destroying ${name} Terraform stack..."
  echo "=================================================="

  cd "$dir"
  terraform init -input=false
  terraform validate
  rm -f destroy.tfplan
  terraform plan -destroy -out=destroy.tfplan -input=false
  terraform apply -input=false -auto-approve destroy.tfplan
}

cleanup_kubernetes_resources() {
  local cluster_name

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found; skipping Kubernetes resource cleanup."
    return 0
  fi

  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI not found; skipping Kubernetes resource cleanup."
    return 0
  fi

  cd "$EKS_DIR"

  if ! terraform output -raw cluster_name >/tmp/destroy-cluster-name 2>/dev/null; then
    echo "No EKS cluster output found; skipping Kubernetes resource cleanup."
    return 0
  fi

  cluster_name="$(cat /tmp/destroy-cluster-name)"
  if [ -z "$cluster_name" ]; then
    echo "EKS cluster output was empty; skipping Kubernetes resource cleanup."
    return 0
  fi

  if ! aws eks describe-cluster --region us-east-1 --name "$cluster_name" >/dev/null 2>&1; then
    echo "EKS cluster '$cluster_name' is not reachable; skipping Kubernetes resource cleanup."
    return 0
  fi

  aws eks update-kubeconfig --region us-east-1 --name "$cluster_name"

  echo ""
  echo "=================================================="
  echo "Cleaning Kubernetes resources before EKS destroy..."
  echo "=================================================="

  if command -v helm >/dev/null 2>&1; then
    helm uninstall monitoring --namespace monitoring || true
  else
    echo "helm not found; skipping monitoring Helm release uninstall."
  fi

  kubectl delete -f "$PROJECT_ROOT/k8s/wazuh-agent-daemonset.yaml" --ignore-not-found --wait=false || true
  kubectl delete -f "$PROJECT_ROOT/k8s/preprod" --ignore-not-found --wait=false || true
  kubectl delete namespace preprod --ignore-not-found --wait=false || true
  kubectl delete secret grafana-admin-secret -n monitoring --ignore-not-found --wait=false || true
  kubectl delete namespace monitoring --ignore-not-found --wait=false || true

  echo "Waiting briefly for Kubernetes load balancers and finalizers to clear..."
  sleep 30
}

echo "=================================================="
echo "Destroying Infrastructure"
echo "=================================================="
echo "This removes the EKS stack plus SonarQube, DefectDojo, and Wazuh EC2 instances."

###############################################################################
# Kubernetes cleanup first, so service load balancers/finalizers do not block
# subnet, security group, or VPC deletion during the EKS Terraform destroy.
###############################################################################
cleanup_kubernetes_resources > "$LOG_DIR/kubernetes-cleanup.log" 2>&1 || true

echo ""
echo "----- Kubernetes cleanup output -----"
cat "$LOG_DIR/kubernetes-cleanup.log"

###############################################################################
# Destroy Terraform-managed infrastructure.
#
# The tools stack and EKS stack are independent Terraform states. After the
# Kubernetes cleanup above, they can be destroyed in parallel.
###############################################################################
run_terraform_destroy "EKS" "$EKS_DIR" \
  > "$LOG_DIR/eks-destroy.log" 2>&1 &
EKS_DESTROY_PID=$!

run_terraform_destroy "security tooling EC2" "$TOOLS_DIR" \
  > "$LOG_DIR/tools-destroy.log" 2>&1 &
TOOLS_DESTROY_PID=$!

EKS_DESTROY_STATUS=0
TOOLS_DESTROY_STATUS=0
wait "$EKS_DESTROY_PID" || EKS_DESTROY_STATUS=$?
wait "$TOOLS_DESTROY_PID" || TOOLS_DESTROY_STATUS=$?

echo ""
echo "----- EKS destroy output -----"
cat "$LOG_DIR/eks-destroy.log"

echo ""
echo "----- Tools destroy output -----"
cat "$LOG_DIR/tools-destroy.log"

if [ "$EKS_DESTROY_STATUS" -ne 0 ] || [ "$TOOLS_DESTROY_STATUS" -ne 0 ]; then
  echo ""
  echo "ERROR: one or both Terraform destroys failed (eks=$EKS_DESTROY_STATUS, tools=$TOOLS_DESTROY_STATUS)."
  echo "Full logs for this run are in: $LOG_DIR"
  exit 1
fi

echo ""
echo "=================================================="
echo "Infrastructure destroyed successfully!"
echo "Full logs for this run are in: $LOG_DIR"
echo "=================================================="
