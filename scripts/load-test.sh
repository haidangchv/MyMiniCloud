#!/usr/bin/env bash
# Tao tai de quan sat tren Grafana (TV4)
# Dung: ./scripts/load-test.sh [URL] [SO_REQUEST] [DONG_THOI]
#   VD: ./scripts/load-test.sh http://localhost/ 20000 50
# Ket qua luu o docs/evidence/tv4/load-test-<timestamp>.txt
# Yeu cau: he thong dang chay (docker compose up -d --build)
set -u

URL="${1:-http://localhost/}"
REQUESTS="${2:-10000}"
CONCURRENCY="${3:-50}"
OUT_DIR="docs/evidence/tv4"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/load-test-$(date +%Y%m%d-%H%M%S).txt"

# Kiem tra URL truoc khi tao tai (tranh ghi file ket qua rong)
if ! curl -s -o /dev/null --max-time 5 "$URL"; then
  echo "LOI: khong truy cap duoc $URL - hay chay 'docker compose up -d --build' truoc." >&2
  exit 1
fi

{
  echo "=== Load test $(date '+%F %T') ==="
  echo "URL=$URL  requests=$REQUESTS  concurrency=$CONCURRENCY"
  echo
} | tee "$OUT"

if command -v ab >/dev/null 2>&1; then
  ab -n "$REQUESTS" -c "$CONCURRENCY" "$URL" 2>&1 | tee -a "$OUT"
else
  # Khong co ApacheBench: chay ab trong container thuoc cloud-net (hoat dong ca tren Docker Desktop)
  # Resolve host entry points to the corresponding service on cloud-net.
  NET_URL="$(echo "$URL" | sed -E 's#//(localhost|127\.0\.0\.1):8080(/|$)#//web-frontend-server:80\2#; s#//(localhost|127\.0\.0\.1):8082(/|$)#//web-frontend-server-2:80\2#; s#//(localhost|127\.0\.0\.1):80(/|$)#//api-gateway-proxy-server:80\2#; s#//(localhost|127\.0\.0\.1)/#//api-gateway-proxy-server:80/#')"
  echo "(ab chua cai - chay trong container, URL noi bo: $NET_URL)" | tee -a "$OUT"
  docker run --rm --network cloud-net httpd:2.4-alpine \
    ab -n "$REQUESTS" -c "$CONCURRENCY" "$NET_URL" 2>&1 | tee -a "$OUT"
fi

echo
echo "Xong. Mo Grafana http://<host>:3000 de chup man hinh CPU/RAM/Network luc co tai." | tee -a "$OUT"
