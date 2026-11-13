#!/bin/bash

###############################################################################
# Exit on error, undefined variables and pipeline failures
###############################################################################
set -euo pipefail

###############################################################################
# Variables
###############################################################################
PROJECT_ROOT="/home/veena/DevSecOps_CdacProject"

EKS_DIR="$PROJECT_ROOT/infra/terraform/eks"
TOOLS_DIR="$PROJECT_ROOT/infra/terraform/monitoring-security"
ANSIBLE_DIR="$PROJECT_ROOT/infra/ansible"

SSH_KEY="/home/veena/.ssh/eks-key.pem"

SONAR_PROJECT_KEY="AnzenOps"
SONAR_ADMIN_USER="admin"

DOJO_ADMIN_USER="admin"

LOG_DIR="/tmp/provision-logs-$$"
mkdir -p "$LOG_DIR"

set_github_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local attempts="${3:-5}"
  local delay="${4:-10}"
  local attempt

  for attempt in $(seq 1 "$attempts"); do
    if gh secret set "$secret_name" --body "$secret_value"; then
      echo "Successfully wrote GitHub secret: ${secret_name}"
      return 0
    fi

    if [ "$attempt" -lt "$attempts" ]; then
      echo "Warning: failed to write GitHub secret '${secret_name}' (attempt ${attempt}/${attempts}). Retrying in ${delay}s..."
      sleep "$delay"
    else
      echo "Warning: failed to write GitHub secret '${secret_name}' after ${attempts} attempts. Continuing without this secret."
      return 1
    fi
  done

  return 1
}

# Runs terraform fmt/init/validate/plan/apply in a given directory.
# Meant to be invoked inside a subshell backgrounded with `&`.
run_terraform_apply() {
  local dir="$1"
  cd "$dir"
  terraform fmt -recursive
  terraform init -input=false
  terraform validate
  rm -f tfplan
  terraform plan -out=tfplan -input=false
  terraform apply -input=false tfplan
}

# Polls until `ssh ... echo READY` succeeds, or gives up after $3 seconds.
wait_for_ssh() {
  local name="$1" ip="$2" timeout="${3:-600}" waited=0
  until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" ubuntu@"$ip" "echo READY" >/dev/null 2>&1; do
    if [ "$waited" -ge "$timeout" ]; then
      echo "ERROR: $name ($ip) did not become SSH-reachable within ${timeout}s"
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "$name SSH is ready ($ip)"
}

# Polls an HTTP(S) endpoint instead of blindly sleeping a fixed amount.
wait_http() {
  local name="$1" url="$2" timeout="${3:-120}" waited=0
  until curl -sk -o /dev/null -m 5 "$url"; do
    if [ "$waited" -ge "$timeout" ]; then
      echo "WARNING: $name did not respond within ${timeout}s at $url (continuing anyway)"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "$name is responding at $url"
}

###############################################################################
# Header
###############################################################################
echo "=================================================="
echo "Starting Infrastructure Provisioning"
echo "=================================================="

###############################################################################
# Pre-flight: required CLI tools
###############################################################################
echo ""
echo "Checking required tools..."

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found — installing..."
  sudo apt-get update -y
  sudo apt-get install -y jq
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) not found. Install it and run 'gh auth login' first."
  exit 1
fi

gh auth status >/dev/null 2>&1 || {
  echo "ERROR: 'gh' is not authenticated. Run 'gh auth login' first."
  exit 1
}

###############################################################################
# Verify AWS Credentials
###############################################################################
echo ""
echo "Checking AWS Credentials..."
aws sts get-caller-identity

###############################################################################
# Provision EKS + tool EC2s IN PARALLEL
#
# These are two independent Terraform projects (separate state) with no
# dependency on each other's resources — the SonarQube/DefectDojo/Wazuh/
# EC2 instances don't need the EKS cluster to exist, and vice versa. Running
# them sequentially was pure wasted time. EKS typically takes ~15-18 min to go
# ACTIVE; the tool EC2s usually finish in 2-3 min, so overlapping them costs
# nothing and saves the EC2 leg almost entirely.
###############################################################################
echo ""
echo "=================================================="
echo "Provisioning EKS and tool EC2 instances in parallel..."
echo "Monitoring is handled by Prometheus and Grafana."
echo "=================================================="

( run_terraform_apply "$EKS_DIR" ) > "$LOG_DIR/eks-apply.log" 2>&1 &
EKS_APPLY_PID=$!

( run_terraform_apply "$TOOLS_DIR" ) > "$LOG_DIR/tools-apply.log" 2>&1 &
TOOLS_APPLY_PID=$!

EKS_APPLY_STATUS=0
TOOLS_APPLY_STATUS=0
wait "$EKS_APPLY_PID" || EKS_APPLY_STATUS=$?
wait "$TOOLS_APPLY_PID" || TOOLS_APPLY_STATUS=$?

echo ""
echo "----- EKS terraform apply output -----"
cat "$LOG_DIR/eks-apply.log"
echo ""
echo "----- Tools terraform apply output -----"
cat "$LOG_DIR/tools-apply.log"

if [ "$EKS_APPLY_STATUS" -ne 0 ] || [ "$TOOLS_APPLY_STATUS" -ne 0 ]; then
  echo ""
  echo "ERROR: one or both Terraform applies failed (eks=$EKS_APPLY_STATUS, tools=$TOOLS_APPLY_STATUS)."
  exit 1
fi

###############################################################################
# kubeconfig + cluster verification (needs EKS output)
###############################################################################
echo ""
echo "Updating kubeconfig..."

cd "$EKS_DIR"
CLUSTER_NAME=$(terraform output -raw cluster_name)

aws eks update-kubeconfig \
    --region us-east-1 \
    --name "$CLUSTER_NAME"

echo ""
echo "Verifying EKS Cluster"

kubectl get nodes
kubectl get ns

###############################################################################
# Get tool EC2 Public IPs
###############################################################################
cd "$TOOLS_DIR"

echo ""
echo "Terraform Outputs"
terraform output

SONAR_IP=$(terraform output -raw sonarqube_public_ip)
DOJO_IP=$(terraform output -raw defectdojo_public_ip)
WAZUH_IP=$(terraform output -raw wazuh_public_ip)

for name_value in "SONAR_IP:$SONAR_IP" "DOJO_IP:$DOJO_IP" "WAZUH_IP:$WAZUH_IP"; do
  var_name="${name_value%%:*}"
  var_val="${name_value#*:}"
  if [ -z "$var_val" ]; then
    echo "ERROR: $var_name came back empty from 'terraform output'."
    echo "Check that the corresponding output block exists in ${TOOLS_DIR} and that apply succeeded."
    exit 1
  fi
done

echo ""
echo "SonarQube Public IP  : $SONAR_IP"
echo "DefectDojo Public IP : $DOJO_IP"
echo "Wazuh Public IP      : $WAZUH_IP"

###############################################################################
# Generate the Wazuh agent DaemonSet manifest from template
#
# NOTE: Wazuh EC2 lives in a different VPC than the EKS cluster with no VPC
# peering configured, so the private IP is not routable from EKS pods. We use
# the public IP instead.
#
# NOTE: This is always regenerated FROM THE TEMPLATE
# (wazuh-agent-daemonset.yaml.tpl) rather than sed-edited in place. Editing
# in place is not idempotent: once the placeholder WAZUH_PUBLIC_IP is
# replaced, a second run finds nothing to replace and silently keeps
# whatever IP was baked in before — even if the Wazuh EC2 was destroyed and
# recreated with a new IP. Generating fresh output from an untouched
# template every run avoids that.
###############################################################################
WAZUH_DAEMONSET_TEMPLATE="$PROJECT_ROOT/k8s/wazuh-agent-daemonset.yaml.tpl"
WAZUH_DAEMONSET_FILE="$PROJECT_ROOT/k8s/wazuh-agent-daemonset.yaml"

if [ -f "$WAZUH_DAEMONSET_TEMPLATE" ]; then
  sed "s|WAZUH_PUBLIC_IP|${WAZUH_IP}|g" "$WAZUH_DAEMONSET_TEMPLATE" > "$WAZUH_DAEMONSET_FILE"
  echo "Generated ${WAZUH_DAEMONSET_FILE} from template with Wazuh public IP: ${WAZUH_IP}"
else
  echo "WARNING: ${WAZUH_DAEMONSET_TEMPLATE} not found — skipping Wazuh agent manifest generation."
fi

echo "Setting GitHub secret: WAZUH_PUBLIC_IP"
set_github_secret "WAZUH_PUBLIC_IP" "$WAZUH_IP" || true

###############################################################################
# Wait for SSH on all three EC2 hosts IN PARALLEL
###############################################################################
echo ""
echo "Waiting for SSH on all 3 tool EC2 hosts (in parallel)..."

wait_for_ssh "SonarQube"  "$SONAR_IP"      > "$LOG_DIR/ssh-sonar.log"  2>&1 & SSH_SONAR_PID=$!
wait_for_ssh "DefectDojo" "$DOJO_IP"       > "$LOG_DIR/ssh-dojo.log"   2>&1 & SSH_DOJO_PID=$!
wait_for_ssh "Wazuh"      "$WAZUH_IP"      > "$LOG_DIR/ssh-wazuh.log" 2>&1 & SSH_WAZUH_PID=$!

ssh_fail=0
for pid_var in SSH_SONAR_PID SSH_DOJO_PID SSH_WAZUH_PID; do
  pid="${!pid_var}"
  wait "$pid" || ssh_fail=1
done

cat "$LOG_DIR"/ssh-*.log

if [ "$ssh_fail" -ne 0 ]; then
  echo "ERROR: one or more hosts never became SSH-reachable."
  exit 1
fi

###############################################################################
# Update Inventory
###############################################################################
echo ""
echo "Updating Ansible Inventory..."

cd "$ANSIBLE_DIR"

sed -i "s|^sonarqube1.*|sonarqube1 ansible_host=$SONAR_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY|" inventory.ini
sed -i "s|^defectdojo1.*|defectdojo1 ansible_host=$DOJO_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY|" inventory.ini
sed -i "s|^wazuh1.*|wazuh1 ansible_host=$WAZUH_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY|" inventory.ini

echo ""
echo "Updated Inventory"
cat inventory.ini

###############################################################################
# Verify Connectivity (parallel — these are cheap but no reason to serialize)
###############################################################################
echo ""
echo "Running Ansible Ping..."

ANSIBLE_HOST_KEY_CHECKING=False ansible -i inventory.ini sonarqube          -m ping > "$LOG_DIR/ping-sonar.log" 2>&1 & PING_SONAR_PID=$!
ANSIBLE_HOST_KEY_CHECKING=False ansible -i inventory.ini defectdojo         -m ping > "$LOG_DIR/ping-dojo.log"  2>&1 & PING_DOJO_PID=$!
ANSIBLE_HOST_KEY_CHECKING=False ansible -i inventory.ini wazuh              -m ping > "$LOG_DIR/ping-wazuh.log" 2>&1 & PING_WAZUH_PID=$!

ping_fail=0
for pid_var in PING_SONAR_PID PING_DOJO_PID PING_WAZUH_PID; do
  pid="${!pid_var}"
  wait "$pid" || ping_fail=1
done
cat "$LOG_DIR"/ping-*.log
if [ "$ping_fail" -ne 0 ]; then
  echo "ERROR: ansible ping failed against one or more hosts."
  exit 1
fi

###############################################################################
# Configure SonarQube + DefectDojo + Wazuh IN PARALLEL
#
# Each playbook targets a completely different host, so there's no reason
# to run them one after another. Output is captured per-service so the
# DefectDojo admin-password grep still works exactly as before.
###############################################################################
echo ""
echo "=================================================="
echo "Running all 3 configuration playbooks in parallel..."
echo "=================================================="

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini sonarqube-setup.yml \
  > "$LOG_DIR/pb-sonar.log" 2>&1 & PB_SONAR_PID=$!

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini defectdojo-setup.yml \
  > "$LOG_DIR/pb-dojo.log" 2>&1 & PB_DOJO_PID=$!

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini wazuh-setup.yml \
  > "$LOG_DIR/pb-wazuh.log" 2>&1 & PB_WAZUH_PID=$!

pb_fail=0
wait "$PB_SONAR_PID" || pb_fail=1
wait "$PB_DOJO_PID"  || pb_fail=1
wait "$PB_WAZUH_PID" || pb_fail=1

echo "----- SonarQube playbook -----";        cat "$LOG_DIR/pb-sonar.log"
echo "----- DefectDojo playbook -----";        cat "$LOG_DIR/pb-dojo.log"
echo "----- Wazuh playbook -----";             cat "$LOG_DIR/pb-wazuh.log"

if [ "$pb_fail" -ne 0 ]; then
  echo "ERROR: one or more Ansible playbooks failed. See logs above / in $LOG_DIR."
  exit 1
fi

# Use a case-insensitive match and allow the initializer to log either the
# expected `Admin password:` line or a slightly different casing.
DOJO_ADMIN_PASS=$(grep -oiP 'Admin password:\s*\K[^"[:space:]]+' "$LOG_DIR/pb-dojo.log" | tail -1 || true)
DOJO_ADMIN_PASS=$(printf '%s' "$DOJO_ADMIN_PASS" | tr -d '\r\n"')

if [ -z "$DOJO_ADMIN_PASS" ]; then
  echo "WARNING: Could not auto-extract the DefectDojo admin password from the playbook output."
  read -s -p "Enter DefectDojo admin password manually: " DOJO_ADMIN_PASS
  echo
fi

###############################################################################
# Health checks IN PARALLEL — poll instead of blind sleep 60 x 3
###############################################################################
echo ""
echo "Waiting for services to respond (polling in parallel instead of fixed sleeps)..."

wait_http "SonarQube"  "http://$SONAR_IP:9000"  120 > "$LOG_DIR/health-sonar.log" 2>&1 & H_SONAR_PID=$!
wait_http "DefectDojo" "http://$DOJO_IP:8080"   120 > "$LOG_DIR/health-dojo.log"  2>&1 & H_DOJO_PID=$!
wait_http "Wazuh"      "https://$WAZUH_IP:443"  120 > "$LOG_DIR/health-wazuh.log" 2>&1 & H_WAZUH_PID=$!

wait "$H_SONAR_PID"
wait "$H_DOJO_PID"
wait "$H_WAZUH_PID"

cat "$LOG_DIR"/health-*.log

###############################################################################
# Generate SonarQube token, create project, push GitHub secrets
###############################################################################
echo ""
echo "=================================================="
echo "Configuring SonarQube project + token..."
echo "=================================================="

SONAR_HOST_URL="http://$SONAR_IP:9000"

# If you already have a Global Analysis Token generated in the SonarQube UI
# (My Account > Security > Generate Tokens, type = Global Analysis Token),
# export it before running this script and it will be reused as-is instead
# of generating a new one:
#   export SONAR_TOKEN="squ_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SONAR_TOKEN="${SONAR_TOKEN:-}"

# Default SonarQube admin password. Override with:
#   export SONAR_ADMIN_PASS="yourpassword"
SONAR_ADMIN_PASS="${SONAR_ADMIN_PASS:-admin}"

curl -s -X POST -u "${SONAR_ADMIN_USER}:${SONAR_ADMIN_PASS}" \
  "${SONAR_HOST_URL}/api/projects/create" \
  -d "project=${SONAR_PROJECT_KEY}" \
  -d "name=${SONAR_PROJECT_KEY}" > /tmp/sonar-project.json

if grep -q "already exists" /tmp/sonar-project.json; then
  echo "Project '${SONAR_PROJECT_KEY}' already exists — continuing."
elif grep -q '"errors"' /tmp/sonar-project.json; then
  echo "ERROR creating SonarQube project:"
  cat /tmp/sonar-project.json
  exit 1
else
  cat /tmp/sonar-project.json
fi
echo ""

if [ -z "$SONAR_TOKEN" ]; then
  echo "No SONAR_TOKEN provided — generating a new Global Analysis Token..."
  SONAR_TOKEN=$(curl -s -X POST -u "${SONAR_ADMIN_USER}:${SONAR_ADMIN_PASS}" \
    "${SONAR_HOST_URL}/api/user_tokens/generate" \
    -d "name=github-actions-token-$(date +%s)" \
    -d "type=GLOBAL_ANALYSIS_TOKEN" | jq -r '.token')
else
  echo "Using pre-supplied Global Analysis Token from \$SONAR_TOKEN."
fi

if [ -z "$SONAR_TOKEN" ] || [ "$SONAR_TOKEN" == "null" ]; then
  echo "ERROR: Failed to generate/obtain SonarQube token. Check admin credentials or SONAR_TOKEN."
  exit 1
fi

echo "Setting GitHub secrets: SONAR_HOST_URL, SONAR_TOKEN"
set_github_secret "SONAR_HOST_URL" "$SONAR_HOST_URL" || true
set_github_secret "SONAR_TOKEN" "$SONAR_TOKEN" || true

###############################################################################
# Generate DefectDojo token, push GitHub secrets
###############################################################################
echo ""
echo "=================================================="
echo "Configuring DefectDojo API token..."
echo "=================================================="

DEFECTDOJO_URL="http://$DOJO_IP:8080"

# If you already have an API v2 Key from the DefectDojo UI (top-right user
# menu > API Key, or /api/key-v2), export it before running this script and
# it will be reused as-is instead of generating a new one:
#   export DEFECTDOJO_API_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
DEFECTDOJO_API_KEY="${DEFECTDOJO_API_KEY:-}"

if [ -n "$DEFECTDOJO_API_KEY" ]; then
  echo "Using pre-supplied API key from \$DEFECTDOJO_API_KEY."
else

DOJO_RAW_RESPONSE="/tmp/dojo-token-response-$$.json"

# Retry a few times — the app can still be warming up right after the
# containers report "running", even though the health check curl succeeded.
DOJO_TOKEN_ATTEMPTS=5
DOJO_TOKEN_DELAY=15

for attempt in $(seq 1 "$DOJO_TOKEN_ATTEMPTS"); do
  echo "Attempt ${attempt}/${DOJO_TOKEN_ATTEMPTS}: requesting DefectDojo API token..."

  HTTP_STATUS=$(curl -s -o "$DOJO_RAW_RESPONSE" -w "%{http_code}" \
    -X POST "${DEFECTDOJO_URL}/api/v2/api-token-auth/" \
    -H "content-type: application/json" \
    -d "$(jq -n --arg u "$DOJO_ADMIN_USER" --arg p "$DOJO_ADMIN_PASS" '{username: $u, password: $p}')")

  DEFECTDOJO_API_KEY=$(jq -r '.token // empty' "$DOJO_RAW_RESPONSE" 2>/dev/null || true)

  if [ -n "$DEFECTDOJO_API_KEY" ] && [ "$DEFECTDOJO_API_KEY" != "null" ]; then
    echo "Token obtained."
    break
  fi

  echo "  -> HTTP $HTTP_STATUS, response body:"
  sed 's/^/     /' "$DOJO_RAW_RESPONSE"

  if [ "$attempt" -lt "$DOJO_TOKEN_ATTEMPTS" ]; then
    echo "  Retrying in ${DOJO_TOKEN_DELAY}s..."
    sleep "$DOJO_TOKEN_DELAY"
  fi
done

rm -f "$DOJO_RAW_RESPONSE"

if [ -z "${DEFECTDOJO_API_KEY:-}" ] || [ "$DEFECTDOJO_API_KEY" == "null" ]; then
  echo "ERROR: Failed to generate DefectDojo token after ${DOJO_TOKEN_ATTEMPTS} attempts."
  echo "Common causes: wrong admin password (may have been changed since the"
  echo "initializer ran), api-token-auth endpoint disabled"
  echo "(DD_API_TOKEN_AUTH_ENDPOINT_ENABLED=False), or the app is still starting up."
  echo ""
  echo "Fix: grab your key from ${DEFECTDOJO_URL}/api/key-v2 and re-run with:"
  echo "  export DEFECTDOJO_API_KEY=\"<your-key>\""
  echo "  bash \$0"
  exit 1
fi

fi

echo "Setting GitHub secrets: DEFECTDOJO_URL, DEFECTDOJO_API_KEY"
set_github_secret "DEFECTDOJO_URL" "$DEFECTDOJO_URL" || true
set_github_secret "DEFECTDOJO_API_KEY" "$DEFECTDOJO_API_KEY" || true

echo ""
echo "Current GitHub secrets:"
gh secret list

echo ""
echo "=================================================="
echo "Infrastructure Provisioned Successfully!"
echo ""
echo "Service Access Summary"
echo "----------------------"
echo "SonarQube URL: http://$SONAR_IP:9000"
echo "SonarQube Login: admin / ${SONAR_ADMIN_PASS:-admin}"
echo ""
echo "DefectDojo URL: http://$DOJO_IP:8080"
echo "DefectDojo Login: ${DOJO_ADMIN_USER} / ${DOJO_ADMIN_PASS:-<check-playbook-output>}"
echo ""
echo "Wazuh Dashboard URL: https://$WAZUH_IP:443"
echo "Wazuh Login: check Wazuh dashboard configuration / default admin credentials"
echo "=================================================="
echo ""
echo "Full logs for this run are in: $LOG_DIR"
