cd /home/ubuntu/MyMiniCloud
EVIDENCE_DIR=$(cat .local/full/evidence-current)
bash scripts/ping-test.sh | tee "$EVIDENCE_DIR/ping-test.txt"
docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /home/ubuntu/MyMiniCloud/.local/full/acme-webroot:/var/www/certbot \
  certbot/certbot:v5.5.0 renew --dry-run --non-interactive --agree-tos --register-unsafely-without-email 2>&1 | tee "$EVIDENCE_DIR/certificate-renewal-dry-run.txt"
sudo openssl x509 -in /etc/letsencrypt/live/54.227.182.163/fullchain.pem -noout -issuer -dates -ext subjectAltName > "$EVIDENCE_DIR/certificate.txt"
docker compose ps > "$EVIDENCE_DIR/compose-ps-final.txt"
docker stats --no-stream > "$EVIDENCE_DIR/resources-final.txt"
docker exec api-gateway-proxy-server nginx -t
