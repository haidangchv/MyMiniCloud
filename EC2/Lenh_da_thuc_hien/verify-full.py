import base64, csv, datetime, hashlib, hmac, json, os, shutil, subprocess, sys, urllib.error, urllib.parse, urllib.request
from pathlib import Path

ROOT=Path('/home/ubuntu/MyMiniCloud')
os.chdir(ROOT)
OUT=ROOT/'.local/full'/('evidence-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
OUT.mkdir(mode=0o700)
(ROOT/'.local/full/evidence-current').write_text(str(OUT))
BASE='https://54.227.182.163'
ENV=dict(line.split('=',1) for line in (ROOT/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
CLIENT=urllib.request.build_opener(urllib.request.ProxyHandler({}))
RESULTS=[]

def cmd(*args):
    return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT).strip()

def request(url,method='GET',data=None,headers=None):
    req=urllib.request.Request(url,data=data,method=method,headers=headers or {})
    try:
        with CLIENT.open(req,timeout=25) as r: return r.status,r.read(),dict(r.headers)
    except urllib.error.HTTPError as e: return e.code,e.read(),dict(e.headers)

def jsget(url,headers=None):
    code,body,_=request(url,headers=headers)
    assert code==200,(url,code,body[:120])
    return json.loads(body)

def test(name,func):
    try:
        detail=func()
        RESULTS.append({'test':name,'status':'PASS','detail':detail})
        print('PASS '+name,flush=True)
    except Exception as e:
        # Do not include request headers, credentials, tokens, or full API replies.
        RESULTS.append({'test':name,'status':'FAIL','detail':str(e)[:240]})
        print('FAIL '+name+': '+str(e)[:240],flush=True)

containers={}
def runtime():
    names=cmd('docker','ps','--format','{{.Names}}').splitlines()
    assert len(names)==12, len(names)
    raw=json.loads(cmd('docker','inspect',*names))
    for c in raw:
        name=c['Name'].lstrip('/')
        st=c['State']
        assert st['Running'] and not st['OOMKilled'],name
        if 'Health' in st: assert st['Health']['Status']=='healthy',(name,st['Health']['Status'])
        assert c['HostConfig']['RestartPolicy']['Name']=='unless-stopped',name
        net=c['NetworkSettings']['Networks']['cloud-net']
        containers[name]={'name':name,'image':c['Config']['Image'],'image_id':c['Image'],'ip':net['IPAddress'],
                          'aliases':net['Aliases'],'health':st.get('Health',{}).get('Status','running'),
                          'restart_policy':'unless-stopped','restart_count':c['RestartCount'],'oom_killed':st['OOMKilled'],
                          'ports':c['NetworkSettings']['Ports']}
    expected={'web-frontend-server':'10.10.10.10','web-frontend-server-2':'10.10.10.11',
     'application-backend-server':'10.10.10.20','object-storage-server':'10.10.10.30',
     'authentication-identity-server':'10.10.10.40','relational-database-server':'10.10.10.50',
     'internal-dns-server':'10.10.10.53','api-gateway-proxy-server':'10.10.10.60'}
    for name,ip in expected.items(): assert containers[name]['ip']==ip,(name,containers[name]['ip'])
    (OUT/'containers.json').write_text(json.dumps(list(containers.values()),indent=2))
    return {'running':len(containers),'static_ips_matched':len(expected),'oom_killed':False}
test('Runtime twelve containers and static IPs',runtime)

def web():
    from html.parser import HTMLParser
    class Links(HTMLParser):
        def __init__(self): super().__init__(); self.images=[]; self.links=[]
        def handle_starttag(self,tag,attrs):
            a=dict(attrs)
            if tag=='img' and a.get('src'): self.images.append(a['src'])
            if tag=='a' and a.get('href'): self.links.append(a['href'])
    rows=[]
    for path in ['/','/blog/blog1.html','/blog/blog2.html','/blog/blog3.html']:
        status,body,headers=request(BASE+path); assert status==200,(path,status)
        parser=Links(); parser.feed(body.decode())
        assert parser.images,path
        if path!='/': assert any(urllib.parse.urlparse(urllib.parse.urljoin(BASE+path,x)).path in ['/','/index.html'] for x in parser.links)
        for image in parser.images:
            url=urllib.parse.urljoin(BASE+path,image); ipath=urllib.parse.urlparse(url).path
            code,data,h=request(url)
            assert code==200 and h.get('Content-Type','').startswith('image/'),ipath
            assert hashlib.sha256(data).digest()==hashlib.sha256((ROOT/'web-frontend-server/html'/ipath.lstrip('/')).read_bytes()).digest(),ipath
            rows.append({'path':ipath,'status':code,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
    (OUT/'web-images.json').write_text(json.dumps(rows,indent=2))
    return {'pages':4,'image_checks':len(rows),'checksum_match':True,'home_links':True}
test('HTTPS blogs images and home links',web)

def routing():
    rows=[]
    for scheme in ['http','https']:
        for path in ['/api/hello','/api/student','/student','/student/','/students-db','/api/students-db']:
            value=jsget(scheme+'://54.227.182.163'+path)
            if 'student' in path: assert value['count']==5 and len(value['data'])==5,path
            else: assert value['message']=='Hello from App Server!'
            rows.append({'url':scheme+'://54.227.182.163'+path,'status':200})
    (OUT/'routing.json').write_text(json.dumps(rows,indent=2))
    return {'routes':len(rows),'students':5}
test('Flask routing HTTP and HTTPS',routing)

def round_robin():
    # Keep this short sequence separate from screenshot collection to avoid concurrent page requests.
    rows=[]
    for n in range(10):
        status,data,h=request(BASE+'/node'); assert status==200
        node=data.decode().strip().removeprefix('Web Server Node: ')
        assert h.get('X-Served-By')==node
        assert node in ['web-frontend-server1','web-frontend-server2']
        expected='10.10.10.10:80' if node.endswith('1') else '10.10.10.11:80'
        assert h.get('X-Upstream-Addr')==expected
        rows.append({'request':n+1,'node':node,'upstream':h['X-Upstream-Addr']})
    assert all(rows[i]['node']!=rows[i-1]['node'] for i in range(1,len(rows))),rows
    (OUT/'round-robin.json').write_text(json.dumps(rows,indent=2))
    return {'requests':10,'alternating':True}
test('Round Robin ten consecutive requests',round_robin)

def oidc():
    discovery=jsget(BASE+'/auth/realms/realm_sv001/.well-known/openid-configuration')
    assert discovery['issuer']==BASE+'/auth/realms/realm_sv001'
    users=json.loads((ROOT/'.local/full/demo-users-private.json').read_text())
    output=[]
    for user,pw in users.items():
        form=urllib.parse.urlencode({'client_id':'flask-app','grant_type':'password','username':user,'password':pw}).encode()
        status,body,_=request(discovery['token_endpoint'],'POST',form,{'Content-Type':'application/x-www-form-urlencoded'})
        assert status==200,(user,status)
        token=json.loads(body)['access_token']
        claim=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))
        assert claim['iss']==discovery['issuer']
        assert 'flask-app' in ([claim['aud']] if isinstance(claim['aud'],str) else claim['aud'])
        for url in [BASE+'/api/secure','http://127.0.0.1:8085/secure','http://127.0.0.1/api/secure']:
            result=jsget(url,{'Authorization':'Bearer '+token})
            assert result['message']=='Secure resource OK' and result['preferred_username']==user
        output.append({'username':user,'issuer':claim['iss'],'audience':claim['aud'],'token_type':'Bearer','secure_status':200,'token_saved':False})
    for header in [{},{'Authorization':'Bearer invalid-token'}]:
        assert request(BASE+'/api/secure',headers=header)[0]==401
    (OUT/'oidc.json').write_text(json.dumps({'discovery':discovery,'users':output,'missing_or_invalid_token':401},indent=2))
    return {'realm':'realm_sv001','client':'flask-app','users':2,'secure_calls':6,'negative_checks':2}
test('Keycloak realm users tokens and protected Flask',oidc)

def s3(method,path,body=b'',public=False):
    url='http://127.0.0.1:9000'+path
    if public: return request(url,method,data=body if method=='PUT' else None)
    now=datetime.datetime.now(datetime.timezone.utc); stamp=now.strftime('%Y%m%dT%H%M%SZ'); day=now.strftime('%Y%m%d')
    hashed=hashlib.sha256(body).hexdigest(); parsed=urllib.parse.urlparse(path)
    host='127.0.0.1:9000'; signed='host;x-amz-content-sha256;x-amz-date'
    canonical='\n'.join([method,parsed.path,parsed.query,'host:'+host+'\nx-amz-content-sha256:'+hashed+'\nx-amz-date:'+stamp+'\n',signed,hashed])
    scope=day+'/us-east-1/s3/aws4_request'
    string='AWS4-HMAC-SHA256\n'+stamp+'\n'+scope+'\n'+hashlib.sha256(canonical.encode()).hexdigest()
    key=('AWS4'+ENV['MINIO_ROOT_PASSWORD']).encode()
    for value in [day,'us-east-1','s3','aws4_request']: key=hmac.new(key,value.encode(),hashlib.sha256).digest()
    signature=hmac.new(key,string.encode(),hashlib.sha256).hexdigest()
    auth='AWS4-HMAC-SHA256 Credential='+ENV['MINIO_ROOT_USER']+'/'+scope+', SignedHeaders='+signed+', Signature='+signature
    return request(url,method,body if method in ['PUT','POST'] else None,{'Host':host,'X-Amz-Date':stamp,'X-Amz-Content-Sha256':hashed,'Authorization':auth})

def minio():
    assert request('http://127.0.0.1:9000/minio/health/live')[0]==200
    for bucket in ['demo','profile-pics','documents']:
        code,data,_=s3('PUT','/'+bucket)
        assert code in [200,409],(bucket,code)
    objects=[('demo','index.html',ROOT/'web-frontend-server/html/index.html'),
             ('profile-pics','avatar.jpg',ROOT/'object-storage-server/sample-files/avatar.jpg'),
             ('documents','report-tv3.pdf',ROOT/'object-storage-server/sample-files/report-tv3.pdf')]
    rows=[]
    for bucket,key,path in objects:
        data=path.read_bytes(); url='/'+bucket+'/'+key
        code,_,_=s3('PUT',url,data); assert code==200,(url,code)
        code,downloaded,_=s3('GET',url)
        assert code==200 and downloaded==data,(url,code)
        rows.append({'bucket':bucket,'key':key,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'upload':200,'download':200,'source_match':True})
    for bucket,key in [('demo','index.html'),('profile-pics','avatar.jpg')]:
        policy={'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'AWS':['*']},'Action':['s3:GetObject'],'Resource':['arn:aws:s3:::'+bucket+'/'+key]}]}
        code,_,_=s3('PUT','/'+bucket+'?policy=',json.dumps(policy).encode()); assert code==204,(bucket,code)
        code,data,_=request(BASE+'/'+bucket+'/'+key)
        assert code==200 and hashlib.sha256(data).hexdigest()==next(x['sha256'] for x in rows if x['bucket']==bucket),(bucket,code)
    assert s3('GET','/documents/report-tv3.pdf',public=True)[0]==403
    (OUT/'minio.json').write_text(json.dumps({'objects':rows,'public_objects':['/demo/index.html','/profile-pics/avatar.jpg'],'private_pdf_anonymous_status':403},indent=2))
    return {'buckets':3,'uploads':3,'downloads':3,'checksum_match':True,'public_checks':2,'private_pdf':403}
test('MinIO buckets upload download public avatar',minio)

def monitoring():
    targets=jsget('http://127.0.0.1:9090/api/v1/targets')['data']['activeTargets']
    assert len(targets)==4 and all(x['health']=='up' for x in targets)
    queries=['node_cpu_seconds_total','node_memory_MemAvailable_bytes','node_network_receive_bytes_total','container_cpu_usage_seconds_total{name!=""}']
    metrics={}
    for query in queries:
        result=jsget('http://127.0.0.1:9090/api/v1/query?'+urllib.parse.urlencode({'query':query}))['data']['result']
        assert result,query
        metrics[query]=result
    names={x['metric'].get('name') for x in metrics[queries[-1]]}
    assert set(containers).issubset(names),sorted(set(containers)-names)
    total=jsget('http://127.0.0.1:9090/api/v1/query?query=node_memory_MemTotal_bytes')['data']['result']
    assert float(total[0]['value'][1])>7*1024**3
    (OUT/'prometheus-targets.json').write_text(json.dumps(targets,indent=2))
    (OUT/'prometheus-metrics.json').write_text(json.dumps(metrics,indent=2))
    return {'targets_up':4,'metric_queries':len(queries),'named_containers':len(names),'host_memory_over_7GiB':True}
test('Prometheus targets and host container metrics',monitoring)

def grafana():
    auth=base64.b64encode((ENV.get('GRAFANA_ADMIN_USER','admin')+':'+ENV['GRAFANA_ADMIN_PASSWORD']).encode()).decode()
    headers={'Authorization':'Basic '+auth}
    health=jsget('http://127.0.0.1:3000/api/health'); assert health['database']=='ok'
    dashboard=jsget('http://127.0.0.1:3000/api/dashboards/uid/system-health',headers)
    panels=dashboard['dashboard']['panels']; assert len(panels)>=3
    ds=jsget('http://127.0.0.1:3000/api/datasources/uid/prometheus/health',headers); assert ds['status']=='OK'
    (OUT/'grafana-dashboard.json').write_text(json.dumps(dashboard,indent=2))
    (OUT/'grafana-health.json').write_text(json.dumps({'health':health,'datasource':ds},indent=2))
    return {'title':dashboard['dashboard']['title'],'panels':len(panels),'datasource':'OK'}
test('Grafana datasource and saved System Health dashboard',grafana)

def dns():
    expected={'web-frontend-server': '10.10.10.10','web':'10.10.10.10','web-frontend-server1':'10.10.10.10',
      'web2':'10.10.10.11','web-frontend-server2':'10.10.10.11','app-server':'10.10.10.20','app-backend':'10.10.10.20',
      'db':'10.10.10.50','minio':'10.10.10.30','keycloak':'10.10.10.40','proxy':'10.10.10.60','dns-server':'10.10.10.53','ns':'10.10.10.53'}
    for alias,name in [('prometheus','monitoring-prometheus-server'),('grafana','monitoring-grafana-dashboard-server'),('node','monitoring-node-exporter-server'),('cadvisor','monitoring-cadvisor-server')]:
        expected[alias]=containers[name]['ip']
    rows=[]
    for zone in ['cloud.local','myminicloud.local']:
        for name,ip in expected.items():
            for protocol in ['udp','tcp']:
                args=['docker','exec','internal-dns-server','dig','@127.0.0.1',name+'.'+zone,'+short']
                if protocol=='tcp': args.append('+tcp')
                value=cmd(*args); assert value==ip,(name,zone,protocol,value,ip)
                rows.append({'name':name+'.'+zone,'protocol':protocol,'answer':value,'expected':ip})
    (OUT/'dns.json').write_text(json.dumps(rows,indent=2))
    return {'queries':len(rows),'all_match':True}
test('Bind9 both zones UDP and TCP records',dns)

def database():
    sql='SELECT COUNT(*) FROM minicloud.notes; SELECT COUNT(*) FROM studentdb.students;'
    result=cmd('docker','exec','relational-database-server','sh','-ec','mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e '+repr(sql))
    values=[int(x) for x in result.splitlines()]
    assert values[0]>=1 and values[1]>=3,values
    (OUT/'database-counts.txt').write_text('minicloud.notes='+str(values[0])+'\nstudentdb.students='+str(values[1])+'\n')
    return {'notes':values[0],'students':values[1]}
test('MariaDB persistent initialized data',database)

for filename,args in {'compose-ps.txt':['docker','compose','ps'], 'resources.txt':['docker','stats','--no-stream'],
                      'memory.txt':['free','-h'],'disk.txt':['df','-h','/'],'git-status.txt':['git','status','--short'],
                      'source-commit.txt':['git','rev-parse','HEAD'],
                      'certificate-timer.txt':['systemctl','list-timers','myminicloud-certificate.timer','--no-pager']}.items():
    (OUT/filename).write_text(cmd(*args)+'\n')
(OUT/'nginx-effective.txt').write_text(cmd('docker','exec','api-gateway-proxy-server','nginx','-T'))
summary={'status':'PASS' if all(r['status']=='PASS' for r in RESULTS) else 'FAIL',
 'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'base_url':BASE,'tests':RESULTS,
 'passed':sum(r['status']=='PASS' for r in RESULTS),'failed':sum(r['status']=='FAIL' for r in RESULTS),
 'credentials_or_tokens_included':False}
(OUT/'result.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
with (OUT/'result.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=['test','status','detail']);writer.writeheader();writer.writerows(RESULTS)
print(json.dumps({'status':summary['status'],'passed':summary['passed'],'failed':summary['failed'],'evidence':str(OUT)}))
sys.exit(0 if summary['status']=='PASS' else 1)
