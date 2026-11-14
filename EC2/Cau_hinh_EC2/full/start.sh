#!/usr/bin/env bash
set -euo pipefail
cd /home/ubuntu/MyMiniCloud
docker compose -f docker-compose.yml -f .local/full/compose.ec2.yml -f .local/full/compose.https.yml up -d --no-build --wait --wait-timeout 420
