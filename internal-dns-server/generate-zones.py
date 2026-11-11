"""Render authoritative zones from Docker DNS; never publish container-loopback A records."""
import os
from pathlib import Path
import pwd
import socket
import subprocess
import time

services = {
    'ns1': 'internal-dns-server',
    'gateway': 'api-gateway-proxy-server',
    'web1': 'web-frontend-server1',
    'web2': 'web-frontend-server2',
    'api': 'application-backend-server',
    'db': 'relational-database-server',
    'auth': 'authentication-identity-server',
    'storage': 'object-storage-server',
    'prometheus': 'monitoring-prometheus-server',
    'grafana': 'monitoring-grafana-dashboard-server',
    'node': 'monitoring-node-exporter-server',
    'cadvisor': 'monitoring-cadvisor-server',
}
optional = {'prometheus', 'grafana', 'node', 'cadvisor'}
addresses = {}
for label, service in services.items():
    try:
        addresses[label] = socket.gethostbyname(service)
    except socket.gaierror:
        if label not in optional:
            raise RuntimeError(f'Required DNS target is missing: {service}') from None
        print(f'Optional monitoring DNS target absent: {service}', flush=True)
aliases = {
    'proxy': 'gateway',
    'web': 'web1',
    'web-frontend-server': 'web1',
    'web-frontend-server1': 'web1',
    'web-frontend-server2': 'web2',
    'web-frontend-server-2': 'web2',
    'app-server': 'api',
    'app-backend': 'api',
    'keycloak': 'auth',
    'minio': 'storage',
    'dns-server': 'ns1',
    'ns': 'ns1',
}
for alias, target in aliases.items():
    addresses[alias] = addresses[target]
addresses['@'] = addresses['gateway']
records = '\n'.join(f'{label} IN A {ip}' for label, ip in addresses.items())
cache = Path('/var/cache/bind')
cache.mkdir(parents=True, exist_ok=True)
account = pwd.getpwnam('bind')
os.chown(cache, account.pw_uid, account.pw_gid)
for zone in ('cloud.local', 'myminicloud.local'):
    text = (Path('/opt/zones') / f'db.{zone}').read_text()
    text = text.replace('__ZONE__', zone).replace('__SERIAL__', str(int(time.time()))).replace('__RECORDS__', records)
    path = cache / f'db.{zone}'
    path.write_text(text)
    os.chown(path, account.pw_uid, account.pw_gid)
    subprocess.run(['named-checkzone', zone, str(path)], check=True)
subprocess.run(['named-checkconf', '/etc/bind/named.conf'], check=True)
os.execvp('named', ['named', '-g', '-u', 'bind', '-c', '/etc/bind/named.conf'])
