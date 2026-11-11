[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://127.0.0.1',
    [string]$OutputDirectory = '',
    [string]$GitSha = '',
    [string]$DirectFlaskUrl = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseUri = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$baseUri) -or
    $baseUri.Scheme -notin @('http','https') -or $baseUri.UserInfo -or $baseUri.Query -or $baseUri.Fragment) {
    throw 'BaseUrl must be an absolute HTTP(S) URL without credentials, query or fragment'
}
$BaseUrl = $BaseUrl.TrimEnd('/')
$headSha = $null
$dirty = $null
if ((Test-Path -LiteralPath (Join-Path $repoRoot '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $headSha = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git HEAD' }
    $dirty = @(& git -C $repoRoot status --porcelain).Count -gt 0
}
$shaSource = 'explicit deployment SHA supplied by caller'
if (-not $GitSha) {
    if ($headSha) { $GitSha = $headSha; $shaSource = 'Git HEAD of checkout; see dirty flag' }
    else {
        $manifest = Join-Path $repoRoot 'release-info.json'
        if (-not (Test-Path -LiteralPath $manifest)) { throw 'No Git checkout or release-info.json; pass -GitSha with the full deployment SHA' }
        $GitSha = (Get-Content -Raw -Encoding UTF8 $manifest | ConvertFrom-Json).git_sha
        $shaSource = 'release-info.json substituted by git archive'
    }
}
if ($GitSha -notmatch '^(?:[a-f0-9]{40}|[a-f0-9]{64})$') { throw 'A full Git SHA is required; unexpanded archive placeholders are not accepted' }
$start = [DateTimeOffset]::UtcNow
$localStart = $start.ToOffset([TimeSpan]::FromHours(7))
$runId = '{0}_{1}_{2}' -f $localStart.ToString('yyyyMMdd-HHmmssfff'),$GitSha.Substring(0,12),([Guid]::NewGuid().ToString('N').Substring(0,8))
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot "runs/$runId" }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'OutputDirectory already exists; choose a new directory to preserve old evidence' }
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$logPath = Join-Path $OutputDirectory 'verify-tv1.log'
$httpRows = New-Object 'System.Collections.Generic.List[object]'
$nodeRows = New-Object 'System.Collections.Generic.List[object]'
$sourceHashes = [ordered]@{}
foreach ($path in @('docker-compose.yml','docker-compose.monitoring.yml','api-gateway-proxy-server/conf.default','api-gateway-proxy-server/nginx.conf','web-frontend-server/conf.default','application-backend-server/app.py','application-backend-server/students.json','docs/evidence/tv1/verify-tv1.ps1')) {
    $fullPath = Join-Path $repoRoot $path
    if (Test-Path -LiteralPath $fullPath) { $sourceHashes[$path] = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$result = [ordered]@{
    status = 'FAILED'; started_at_utc = $start.ToString('o'); started_at_asia_saigon = $localStart.ToString('o')
    base_url = $BaseUrl; git_sha = $GitSha; git_sha_source = $shaSource; checkout_head_sha = $headSha
    git_dirty_before_run = $dirty; source_sha256 = $sourceHashes; http = @(); nodes = @(); error = $null
}
function Write-CheckLog([string]$Message) {
    $line = '[{0}] {1}' -f ([DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')),$Message
    [IO.File]::AppendAllText($logPath,$line+"`n",$utf8)
    Write-Host $line
}
$curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curlCommand) { $curlCommand = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue }
$bodyFile = [IO.Path]::GetTempFileName()
$headerFile = [IO.Path]::GetTempFileName()
function Get-CheckedHttp([string]$Path,[string]$Purpose='required') {
    if (-not $curlCommand) { throw 'curl executable is required' }
    $url = "$BaseUrl$Path"
    $ErrorActionPreference = 'Continue'
    $native = @(& $curlCommand.Source --noproxy '*' --silent --show-error --fail --max-time 15 --request GET --dump-header $headerFile --output $bodyFile --write-out '%{http_code}' $url 2>&1 | ForEach-Object { $_.ToString() })
    $curlExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $code = if ($native.Count) { [string]$native[-1] } else { '000' }
    $row = [pscustomobject]@{path=$Path;method='GET';http_status=$code;curl_exit=$curlExit;purpose=$Purpose;sha256=$null;content_match=$null}
    $httpRows.Add($row)
    Write-CheckLog "GET $url -> HTTP $code (curl exit $curlExit)"
    if ($curlExit -ne 0 -or $code -ne '200') { throw "Required GET failed: $Path (HTTP $code, curl exit $curlExit)" }
    $row.sha256 = (Get-FileHash -LiteralPath $bodyFile -Algorithm SHA256).Hash.ToLowerInvariant()
    return [pscustomobject]@{row=$row;body=[IO.File]::ReadAllText($bodyFile,[Text.Encoding]::UTF8);headers=[IO.File]::ReadAllText($headerFile)}
}
try {
    Write-CheckLog "TV1 acceptance; URL=$BaseUrl; GitSHA=$GitSha; dirty=$dirty; source=$shaSource"
    $static = [ordered]@{
        '/'='index.html'; '/blog/'='blog/index.html'
        '/blog/blog1.html'='blog/blog1.html'; '/blog/blog2.html'='blog/blog2.html'; '/blog/blog3.html'='blog/blog3.html'
        '/images/docker-flow.svg'='images/docker-flow.svg'; '/images/nginx-flow.svg'='images/nginx-flow.svg'; '/images/network-flow.svg'='images/network-flow.svg'; '/styles.css'='styles.css'
    }
    $covers = @('dtn-store-and-forward.svg', 'dtn-missions.svg', 'dtn-space-relay.svg')
    foreach ($cover in $covers) {
        $static["/images/$cover"] = "images/$cover"
    }
    $static['/blog/article.css'] = 'blog/article.css'
    $static['/blog/article.js'] = 'blog/article.js'
    foreach ($path in $static.Keys) {
        $response = Get-CheckedHttp $path 'static-content'
        $expected = (Get-FileHash -LiteralPath (Join-Path $repoRoot "web-frontend-server/html/$($static[$path])") -Algorithm SHA256).Hash.ToLowerInvariant()
        $response.row.content_match = $response.row.sha256 -eq $expected
        if (-not $response.row.content_match) { throw "Content SHA256 differs from checkout/release source: $path" }
        if ($path -eq '/') {
            for ($i = 0; $i -lt $covers.Count; $i++) {
                $link = [regex]::Escape("blog/blog$($i + 1).html")
                $image = [regex]::Escape("images/$($covers[$i])")
                if ($response.body -notmatch "<a\s+href=""$link""[^>]*>\s*<div[^>]*>\s*<img\s+src=""$image""") {
                    throw "Home must link to blog$($i + 1).html with its SVG cover"
                }
            }
        }
        Write-CheckLog "Content MATCH $path SHA256=$expected"
    }
    $responses = @{}
    foreach ($path in @('/_gateway/health','/api/hello','/api/student','/student/','/api/students-db')) { $responses[$path] = Get-CheckedHttp $path }
    if ($responses['/_gateway/health'].body.Trim() -ne 'gateway ok') { throw 'Unexpected Gateway health body' }
    if (($responses['/api/hello'].body | ConvertFrom-Json).message -ne 'Hello from App Server!') { throw 'Unexpected hello JSON' }
    if ($responses['/api/student'].body -cne $responses['/student/'].body) { throw 'Student endpoints returned different JSON bodies' }
    $student = $responses['/api/student'].body | ConvertFrom-Json
    if ($student.status -ne 'success' -or $student.count -ne 5 -or @($student.data).Count -ne 5) { throw 'Expected count=5 and five data records in the TV2 envelope' }
    $sourceStudents = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'application-backend-server/students.json') | ConvertFrom-Json
    for ($i=0; $i -lt 5; $i++) {
        $record = $student.data[$i]
        if ((@($record.PSObject.Properties.Name | Sort-Object) -join ',') -ne 'gpa,id,major,name') { throw 'Student record fields differ from id/name/major/gpa' }
        foreach ($field in @('id','name','major')) { if ($record.$field -cne $sourceStudents[$i].$field) { throw "Student record $i differs from source" } }
        if ([double]$record.gpa -ne [double]$sourceStudents[$i].gpa) { throw "Student GPA $i differs from source" }
    }
    $db = $responses['/api/students-db'].body | ConvertFrom-Json
    if ($db.status -ne 'success' -or $db.count -lt 3 -or @($db.data).Count -ne $db.count) { throw 'MariaDB API must return count/data with at least three student records' }
    $result.student_count = 5
    $result.student_json_identical = $true
    $result.student_json_sha256 = $responses['/api/student'].row.sha256
    $result.db_student_count = $db.count
    Write-CheckLog "Student JSON identical; count=5; MariaDB count=$($db.count)"

    # No other Gateway requests are issued between these eight node requests.
    for ($i=1; $i -le 8; $i++) {
        $response = Get-CheckedHttp '/_web/node' "round-robin-$i"
        $node = $response.body.Trim()
        if ($node -notin @('web-frontend-server1','web-frontend-server2')) { throw "Unexpected node identity at request $i" }
        $servedBy = [regex]::Match($response.headers,'(?im)^X-Served-By:\s*([^\r\n]+)').Groups[1].Value.Trim()
        $upstream = [regex]::Match($response.headers,'(?im)^X-Upstream-Addr:\s*([^\r\n]+)').Groups[1].Value.Trim()
        if ($servedBy -ne $node -or -not $upstream) { throw "Missing/mismatched node headers at request $i" }
        $nodeRows.Add([pscustomobject]@{request=$i;node=$node;served_by=$servedBy;upstream=$upstream})
        Write-CheckLog "Node request #${i}: $node; upstream=$upstream"
    }
    $order = @($nodeRows | ForEach-Object { $_.node })
    $alternating = $true
    for ($i=1; $i -lt 8; $i++) { if ($order[$i] -eq $order[$i-1]) { $alternating=$false } }
    $result.node_order = $order
    $result.round_robin_alternating = $alternating
    if (@($order | Select-Object -Unique).Count -ne 2 -or -not $alternating) { throw 'Eight requests did not alternate between both nodes; inspect upstream health and concurrent Gateway traffic' }
    Write-CheckLog ('Node order: '+($order -join ' -> '))
    if ($DirectFlaskUrl) {
        $directUri = $null
        if (-not [Uri]::TryCreate($DirectFlaskUrl,[UriKind]::Absolute,[ref]$directUri) -or $directUri.UserInfo -or $directUri.Query) { throw 'DirectFlaskUrl is invalid or contains credentials/query' }
        $direct = Invoke-RestMethod -TimeoutSec 15 ($DirectFlaskUrl.TrimEnd('/')+'/hello')
        if ($direct.message -ne 'Hello from App Server!') { throw 'Optional direct Flask check failed' }
        Write-CheckLog 'Optional direct Flask check PASS'
    }
    $result.status = 'PASS'
    Write-CheckLog 'PASS: all mandatory TV1 HTTP/content/student/Round Robin checks passed'
} catch {
    $result.error = $_.Exception.Message
    Write-CheckLog ('FAIL: '+$result.error)
    throw
} finally {
    $result.finished_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    $result.http = @($httpRows.ToArray())
    $result.nodes = @($nodeRows.ToArray())
    $httpRows.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'http.csv') -NoTypeInformation -Encoding UTF8
    if ($nodeRows.Count) { $nodeRows.ToArray() | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'nodes.csv') -NoTypeInformation -Encoding UTF8 }
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'result.json'),($result | ConvertTo-Json -Depth 10)+"`n",$utf8)
    Remove-Item -LiteralPath $bodyFile,$headerFile -ErrorAction SilentlyContinue
}
[pscustomobject]@{Status=$result.status;Directory=$OutputDirectory;GitSha=$GitSha;BaseUrl=$BaseUrl;NodeOrder=($result.node_order -join ' -> ')}
