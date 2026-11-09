# Script tự động kiểm thử phần việc của TV1 & TV2 (Web Server, Blog, API Gateway, Round Robin Load Balancing, Flask API, MariaDB)
$BaseUrl = "http://localhost"

Write-Host "=== 1. KIEM TRA TRANG THAI CONTAINER ===" -ForegroundColor Cyan
docker compose ps

Write-Host "`n=== 2. KIEM TRA CAC DUONG DAN WEB, BLOG & API QUA API GATEWAY (PORT 80) ===" -ForegroundColor Cyan
$Paths = @(
    "/",
    "/blog/",
    "/blog/blog1.html",
    "/blog/blog2.html",
    "/blog/blog3.html",
    "/images/docker-flow.svg",
    "/images/nginx-flow.svg",
    "/images/network-flow.svg",
    "/styles.css",
    "/gateway-health",
    "/node",
    "/api/hello",
    "/api/student",
    "/student/",
    "/api/students-db"
)

$Results = foreach ($p in $Paths) {
    try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl$p" -UseBasicParsing -Method Get
        [PSCustomObject]@{
            Path       = $p
            HttpStatus = [int]$resp.StatusCode
            ServedBy   = $resp.Headers["X-Served-By"]
            Upstream   = $resp.Headers["X-Upstream-Addr"]
        }
    } catch {
        [PSCustomObject]@{
            Path       = $p
            HttpStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            ServedBy   = "N/A"
            Upstream   = "N/A"
        }
    }
}
$Results | Format-Table -AutoSize
$Results | Select-Object Path, HttpStatus | Export-Csv -Path "$PSScriptRoot\blog-http-results.csv" -NoTypeInformation -Encoding UTF8

Write-Host "=== 3. KIEM CHUNG CAN BANG TAI ROUND ROBIN (6 REQUEST LIEN TIEP) ===" -ForegroundColor Cyan
1..6 | ForEach-Object {
    $nodeResp = Invoke-WebRequest -Uri "$BaseUrl/node" -UseBasicParsing
    Write-Host ("Request #{0}: {1} (Upstream: {2})" -f $_, $nodeResp.Content.Trim(), $nodeResp.Headers["X-Upstream-Addr"])
}

Write-Host "`n=== 4. KIEM TRA DINH TUYEN /api/student QUA GATEWAY ===" -ForegroundColor Cyan
curl.exe -i "$BaseUrl/api/student"

