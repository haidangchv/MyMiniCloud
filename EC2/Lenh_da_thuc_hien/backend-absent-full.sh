cd /home/ubuntu/MyMiniCloud
EVIDENCE_DIR=$(cat .local/full/evidence-current)
compose() { docker compose -f docker-compose.yml -f .local/full/compose.ec2.yml -f .local/full/compose.https.yml "$@"; }
restore_backend() {
  rc=$?
  trap - EXIT
  compose up -d --no-deps --no-build --pull never --wait --wait-timeout 180 application-backend-server || rc=1
  exit "$rc"
}
trap restore_backend EXIT
compose rm --stop --force application-backend-server
if docker inspect application-backend-server >/dev/null 2>&1; then echo 'Backend still exists' >&2; exit 1; fi
compose restart api-gateway-proxy-server
for attempt in $(seq 1 40); do
  status=$(docker inspect --format '{{.State.Health.Status}}' api-gateway-proxy-server)
  [ "$status" = healthy ] && break
  sleep 1
done
test "$status" = healthy
python3 - "$EVIDENCE_DIR" <<'PY'
import datetime,json,pathlib,sys,urllib.request,urllib.error
rows=[]
for base in ['http://127.0.0.1','https://54.227.182.163']:
 for path in ['/','/blog/blog1.html','/blog/blog2.html','/blog/blog3.html','/api/hello','/student','/student/','/students-db']:
  try:
   with urllib.request.urlopen(base+path,timeout=15) as r: code,body=r.status,r.read()
  except urllib.error.HTTPError as r: code,body=r.code,r.read()
  expected=503 if path in ['/api/hello','/student','/student/','/students-db'] else 200
  match=code==expected and (expected!=503 or json.loads(body)=={'error':'backend_unavailable'})
  rows.append({'url':base+path,'status':code,'expected':expected,'match':match})
result={'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS' if all(r['match'] for r in rows) else 'FAIL','backend_container_absent':True,'gateway_started_independently':True,'requests':rows}
(pathlib.Path(sys.argv[1])/'backend-absent-test.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'status':result['status'],'requests':len(rows),'backend_container_absent':True}))
assert result['status']=='PASS'
PY
