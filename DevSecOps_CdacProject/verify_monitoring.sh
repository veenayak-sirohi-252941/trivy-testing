#!/bin/bash
###############################################################################
# verify_monitoring.sh
#
# Verifies kube-prometheus-stack resources, Grafana service exposure, and
# Prometheus readiness/query health.
###############################################################################
set -euo pipefail

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-9090}"

cleanup() {
  if [ -n "${PORT_FORWARD_PID:-}" ]; then
    kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "=================================================="
echo "Monitoring namespace resources"
echo "=================================================="
kubectl get pods -n "$MONITORING_NAMESPACE"
kubectl get svc monitoring-grafana -n "$MONITORING_NAMESPACE"
kubectl get svc -n "$MONITORING_NAMESPACE" | grep -i prometheus

GRAFANA_HOSTNAME="$(kubectl get svc monitoring-grafana -n "$MONITORING_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
if [ -n "$GRAFANA_HOSTNAME" ]; then
  echo "Grafana URL: http://${GRAFANA_HOSTNAME}"
else
  echo "Grafana LoadBalancer hostname is not ready yet."
fi

echo ""
echo "=================================================="
echo "Prometheus readiness and query verification"
echo "=================================================="
kubectl port-forward -n "$MONITORING_NAMESPACE" svc/monitoring-prometheus "${LOCAL_PROMETHEUS_PORT}:9090" >/tmp/prometheus-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${LOCAL_PROMETHEUS_PORT}/-/ready" >/dev/null; then
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "ERROR: Prometheus did not become ready through port-forward."
    cat /tmp/prometheus-port-forward.log || true
    exit 1
  fi
  sleep 1
done

curl "http://localhost:${LOCAL_PROMETHEUS_PORT}/-/ready"
echo ""

QUERY_RESPONSE="$(curl -s "http://localhost:${LOCAL_PROMETHEUS_PORT}/api/v1/query?query=up")"
echo "$QUERY_RESPONSE"
echo "$QUERY_RESPONSE" | grep -q '"status":"success"'

echo ""
echo "Prometheus query succeeded and returned scrape target data."
