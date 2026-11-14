[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string]$Ec2Ip = '44.222.205.238',
    [string]$KeyPath = 'D:\download\myminicloud-tv1.pem',
    [string]$LogName = ''
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) { throw 'SSH key is missing.' }
$content = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ScriptPath)).Replace([string][char]13,'')
$payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("set -euo pipefail`n" + $content + "`n"))
$remoteTemplate = 'set -eu; temp_script=$(mktemp /tmp/ec2-stage.XXXXXX); trap ''rm -f -- "$temp_script"'' EXIT; printf ''%s'' ''__PAYLOAD__'' | base64 -d > "$temp_script"; bash "$temp_script" < /dev/null'
$remoteCommand = $remoteTemplate.Replace('__PAYLOAD__',$payload)
if (-not $LogName) { $LogName = [IO.Path]::GetFileNameWithoutExtension($ScriptPath) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log' }
$logPath = Join-Path $PSScriptRoot $LogName
"UTC: $([DateTimeOffset]::UtcNow.ToString('o'))`nTarget: ubuntu@$Ec2Ip`nScript: $ScriptPath" | Set-Content -LiteralPath $logPath -Encoding utf8
& ssh.exe -i $KeyPath -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=30 -o ServerAliveCountMax=4 -o StrictHostKeyChecking=accept-new "ubuntu@$Ec2Ip" $remoteCommand 2>&1 | Tee-Object -FilePath $logPath -Append
$code = $LASTEXITCODE
"ExitCode: $code" | Tee-Object -FilePath $logPath -Append
if ($code -ne 0) { throw "EC2 stage failed with exit $code. See $logPath" }
