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
# Read Terraform Outputs
###############################################################################
INFRA_DIR="infra/terraform/eks/"
WEB_APP_NAMESPACE="${WEB_APP_NAMESPACE:-web-app}"
WAZUH_NAMESPACE="${WAZUH_NAMESPACE:-wazuh}"

CLUSTER_NAME=$(terraform -chdir="$INFRA_DIR" output -raw cluster_name)
AWS_REGION=$(terraform -chdir="$INFRA_DIR" output -raw region)

echo "=================================================="
echo "Updating Kubernetes Configuration..."
echo "=================================================="

echo "Cluster Name : $CLUSTER_NAME"
echo "AWS Region   : $AWS_REGION"
echo "App Namespace: $WEB_APP_NAMESPACE"
echo "Wazuh Namespace: $WAZUH_NAMESPACE"

###############################################################################
# Configure kubectl to access the EKS cluster
###############################################################################
aws eks update-kubeconfig \
    --region "$AWS_REGION" \
    --name "$CLUSTER_NAME"

###############################################################################
# Verify Kubernetes Cluster Connectivity
###############################################################################
kubectl get nodes

###############################################################################
# Ensure required namespaces exist
###############################################################################
kubectl get namespace "$WEB_APP_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$WEB_APP_NAMESPACE"
kubectl get namespace "$WAZUH_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$WAZUH_NAMESPACE"

echo ""
echo "=================================================="
echo "Restarting Kubernetes Deployments..."
echo "=================================================="

###############################################################################
# Restart Database Deployment
###############################################################################
kubectl rollout restart deployment/database -n "$WEB_APP_NAMESPACE"
kubectl rollout status deployment/database -n "$WEB_APP_NAMESPACE" --timeout=300s

###############################################################################
# Restart Backend Deployment
###############################################################################
kubectl rollout restart deployment/backend -n "$WEB_APP_NAMESPACE"
kubectl rollout status deployment/backend -n "$WEB_APP_NAMESPACE" --timeout=300s

###############################################################################
# Restart Frontend Deployment
###############################################################################
kubectl rollout restart deployment/frontend -n "$WEB_APP_NAMESPACE"
kubectl rollout status deployment/frontend -n "$WEB_APP_NAMESPACE" --timeout=300s

echo ""
echo "=================================================="
echo "Rollout Restart completed successfully!"
echo "=================================================="

kubectl get all -n "$WEB_APP_NAMESPACE"