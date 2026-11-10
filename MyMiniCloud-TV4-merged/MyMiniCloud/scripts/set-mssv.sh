#!/usr/bin/env bash
# Dat ten dashboard Grafana thanh "System Health of <MSSV>" (yeu cau Muc 8)
# Dung: ./scripts/set-mssv.sh 2212345 && docker restart monitoring-grafana-dashboard-server
set -eu
[ $# -eq 1 ] || { echo "Dung: $0 <MSSV>"; exit 1; }
F="monitoring-grafana-dashboard-server/dashboards/system-health.json"
sed -i -E "s/\"title\": \"System Health of [^\"]*\"/\"title\": \"System Health of $1\"/" "$F"
grep -m1 '"title": "System Health' "$F"
