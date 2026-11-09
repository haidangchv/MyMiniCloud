# Script tự động khởi tạo & kiểm thử toàn bộ phần việc của TV3 - Nguyễn Hải Đăng
# (Keycloak OIDC Realm/Token, MinIO S3 Buckets/Upload/Public URL, Bind9 DNS Zone cloud.local)

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " 1. KIEM TRA KEYCLOAK OIDC (MUC 4 CO BAN & MO RONG - REALM_SV001)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$TokenUrl = "http://localhost:8081/realms/realm_sv001/protocol/openid-connect/token"
Write-Host "-> Dang lay Access Token cho user 'sv01' (client: flask-app) tai: $TokenUrl"

try {
    $TokenResp = Invoke-RestMethod -Method Post -Uri $TokenUrl -ContentType "application/x-www-form-urlencoded" -Body @{
        client_id  = "flask-app"
        grant_type = "password"
        username   = "sv01"
        password   = "sv01"
    }
    $AccessToken = $TokenResp.access_token
    Write-Host "[OK] Lay Access Token thanh cong! (Do dai token: $($AccessToken.Length) ky tu)" -ForegroundColor Green

    Write-Host "-> Goi thu API bao mat /secure tren Flask Backend voi Bearer Token:"
    $SecureResp = Invoke-RestMethod -Method Get -Uri "http://localhost:8085/secure" -Headers @{
        Authorization = "Bearer $AccessToken"
    }
    $SecureResp | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Green

    Write-Host "-> Goi thu /api/secure qua API Gateway (port 80):"
    $GatewaySecureResp = Invoke-RestMethod -Method Get -Uri "http://localhost/api/secure" -Headers @{
        Authorization = "Bearer $AccessToken"
    }
    $GatewaySecureResp | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Green
} catch {
    Write-Host "[WARN] Keycloak dang khoi dong hoac chua san sang: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 2. KHOI TAO & KIEM TRA MINIO OBJECT STORAGE (MUC 5 CO BAN & MO RONG)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$WebHtmlPath = Join-Path $ProjectRoot "web-frontend-server\html"
$SampleFilesPath = Join-Path $ProjectRoot "object-storage-server\sample-files"

Write-Host "-> Tao bucket 'demo', 'profile-pics', 'documents' va upload file mau..."
docker run --rm --network cloud-net `
    -v "${WebHtmlPath}:/web:ro" `
    -v "${SampleFilesPath}:/samples:ro" `
    --entrypoint /bin/sh minio/mc:latest -c "
    mc alias set myminio http://object-storage-server:9000 minioadmin minioadmin &&
    mc mb --ignore-existing myminio/demo &&
    mc mb --ignore-existing myminio/profile-pics &&
    mc mb --ignore-existing myminio/documents &&
    mc anonymous set download myminio/demo &&
    mc anonymous set download myminio/profile-pics &&
    mc cp /web/index.html myminio/demo/index.html &&
    mc cp /samples/avatar.jpg myminio/profile-pics/avatar.jpg &&
    mc cp /samples/report-tv3.pdf myminio/documents/report-tv3.pdf &&
    mc ls myminio/demo &&
    mc ls myminio/profile-pics &&
    mc ls myminio/documents
"

try {
    $AvatarCheck = Invoke-WebRequest -Uri "http://localhost:9000/profile-pics/avatar.jpg" -UseBasicParsing -Method Head
    Write-Host "[OK] Public URL http://localhost:9000/profile-pics/avatar.jpg -> HTTP $([int]$AvatarCheck.StatusCode) ($($AvatarCheck.Headers['Content-Type']))" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Khong the truy cap public URL MinIO: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 3. KIEM TRA BIND9 INTERNAL DNS SERVER (MUC 6 CO BAN & MO RONG)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$DnsHosts = @(
    "web-frontend-server.cloud.local",
    "app-backend.cloud.local",
    "minio.cloud.local",
    "keycloak.cloud.local"
)

foreach ($h in $DnsHosts) {
    $digResult = docker exec internal-dns-server dig '@127.0.0.1' $h +short
    Write-Host ("dig {0,-34} -> {1}" -f $h, $digResult) -ForegroundColor Green
}

