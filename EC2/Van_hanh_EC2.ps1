[CmdletBinding()]
param(
    [ValidateSet('Status','Http','Start','Credentials','Renew')][string]$Action='Status',
    [string]$Ec2Ip='54.227.182.163',
    [string]$KeyPath='D:\download\myminicloud-tv1.pem'
)
$ErrorActionPreference='Stop'
if($Action -eq 'Http') {
    foreach($path in @('/','/api/hello','/api/student','/api/students-db','/profile-pics/avatar.jpg')) {
        $response=Invoke-WebRequest -Uri "https://$Ec2Ip$path" -TimeoutSec 20
        [pscustomobject]@{Url="https://$Ec2Ip$path";Status=[int]$response.StatusCode;Node=($response.Headers['X-Served-By'] -join ',');Upstream=($response.Headers['X-Upstream-Addr'] -join ',')}
    }
    1..10 | ForEach-Object {
        $response=Invoke-WebRequest -Uri "https://$Ec2Ip/node" -TimeoutSec 20
        $node=$response.Headers['X-Served-By'] -join ','
        if($response.Content.Trim() -ne "Web Server Node: $node"){throw 'Node body and X-Served-By do not match'}
        [pscustomobject]@{Url="https://$Ec2Ip/node (#$_)";Status=[int]$response.StatusCode;Node=$node;Upstream=($response.Headers['X-Upstream-Addr'] -join ',')}
    }
    exit
}
if(-not(Test-Path -LiteralPath $KeyPath -PathType Leaf)){throw 'Khong tim thay khoa SSH. Truyen -KeyPath dung vi tri PEM.'}
$commands=@{
    Status='cd /home/ubuntu/MyMiniCloud && docker compose ps && free -h && df -h / && systemctl list-timers myminicloud-certificate.timer --no-pager'
    Start='cd /home/ubuntu/MyMiniCloud && .local/full/start.sh'
    Renew='sudo /usr/local/sbin/myminicloud-renew-certificate'
    Credentials='cd /home/ubuntu/MyMiniCloud && python3 -c ''import json; from pathlib import Path; e=dict(x.split("=",1) for x in Path(".env").read_text().splitlines() if "=" in x and not x.startswith("#")); names=["KEYCLOAK_ADMIN_USER","KEYCLOAK_ADMIN_PASSWORD","MINIO_ROOT_USER","MINIO_ROOT_PASSWORD","GRAFANA_ADMIN_USER","GRAFANA_ADMIN_PASSWORD"]; print(json.dumps({k:e[k] for k in names if k in e},indent=2)); print("Demo users:"); print(Path(".local/full/demo-users-private.json").read_text())'''
}
if($Action -eq 'Credentials'){Write-Warning 'Chi xem tren man hinh rieng. Khong ghi vao bao cao, quay video hoac chia se log nay.'}
& ssh.exe -i $KeyPath -o BatchMode=yes -o ConnectTimeout=20 "ubuntu@$Ec2Ip" $commands[$Action]
if($LASTEXITCODE -ne 0){throw "EC2 action failed: $Action (exit $LASTEXITCODE)"}
