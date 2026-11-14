#!/usr/bin/env bash
set -euo pipefail
docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /home/ubuntu/MyMiniCloud/.local/full/acme-webroot:/var/www/certbot \
  certbot/certbot:v5.5.0 renew --quiet
docker exec api-gateway-proxy-server nginx -t
docker exec api-gateway-proxy-server nginx -s reload
