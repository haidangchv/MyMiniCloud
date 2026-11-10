#!/usr/bin/env bash
# Muc 10: kiem tra thong mang - ping tat ca server trong cloud-net (TV4)
# Dung: ./scripts/ping-test.sh | tee docs/evidence/tv4/ping-test.txt
set -u

TARGETS=(
  api-gateway-proxy-server
  web-frontend-server
  web-frontend-server-2
  application-backend-server
  relational-database-server
  authentication-identity-server
  object-storage-server
  internal-dns-server
  monitoring-node-exporter-server
  monitoring-cadvisor-server
  monitoring-prometheus-server
  monitoring-grafana-dashboard-server
)

echo "=== Ping test trong mang cloud-net - $(date '+%F %T') ==="

pass=0; fail=0; skip=0
for t in "${TARGETS[@]}"; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$t"; then
    printf "%-40s SKIP (container chua chay)\n" "$t"; skip=$((skip+1)); continue
  fi
  # busybox co san lenh ping, chay tam trong cloud-net
  if out=$(docker run --rm --network cloud-net busybox:stable ping -c 3 -W 2 "$t" 2>&1); then
    printf "%-40s OK   %s\n" "$t" "$(echo "$out" | grep -E 'packet loss|round-trip' | tr '\n' ' ')"
    pass=$((pass+1))
  else
    printf "%-40s FAIL\n" "$t"; fail=$((fail+1))
  fi
done

echo
echo "Ket qua: $pass OK, $fail FAIL, $skip SKIP"
echo
echo "--- Kiem tra HTTP tu host ---"
for url in http://localhost:8080 http://localhost:8080/api/hello http://localhost:9090/-/healthy http://localhost:9100/metrics http://localhost:8083/healthz http://localhost:3000/api/health; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || echo ERR)
  printf "%-45s HTTP %s\n" "$url" "$code"
done

[ "$fail" -eq 0 ]
