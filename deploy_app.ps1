param(
  [ValidateSet("Zuhause","Nachbar","Hotspot")]
  [string]$Profile = "Zuhause",

  [string]$ServerIp = "152.53.255.4",
  [string]$SshHostName = "ssh.bikergram.com",
  [int]$Port = 2222,
  [string]$User = "bikergram",
  [string]$Key = "$env:USERPROFILE\.ssh\netcup_ed25519",

  [int]$KeepReleases = 10,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; exit 1 }
function Ok([string]$msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Info([string]$msg) { Write-Host "[ .. ] $msg" -ForegroundColor Cyan }

$ssh = "$env:WINDIR\System32\OpenSSH\ssh.exe"
$scp = "$env:WINDIR\System32\OpenSSH\scp.exe"

if (-not (Test-Path $ssh)) { Fail "ssh.exe nicht gefunden: $ssh" }
if (-not (Test-Path $scp)) { Fail "scp.exe nicht gefunden: $scp" }
if (-not (Test-Path $Key)) { Fail "SSH Key nicht gefunden: $Key" }

# Plan B: Nachbar/Hotspot -> immer IP nutzen (DNS egal)
$RemoteHost = if ($Profile -eq "Zuhause") { $SshHostName } else { $ServerIp }

Info ("Target = {0}@{1}:{2} (Profile={3})" -f $User, $RemoteHost, $Port, $Profile)

if (-not $SkipBuild) {
  Info "Flutter build web --release"
  flutter build web --release
  Ok "Build fertig"
} else {
  Info "SkipBuild aktiv"
}

$zip = Join-Path (Get-Location) "bikergram_web.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

Info "ZIP erstellen (tar.exe)"
tar.exe -a -c -f $zip -C ".\build\web" .

Info "Upload zip -> /tmp/bikergram_web.zip"
& $scp -P $Port -i $Key -o IdentitiesOnly=yes $zip ("{0}@{1}:/tmp/bikergram_web.zip" -f $User, $RemoteHost)

Info "Deploy auf Server + Cleanup"
$remoteCmd = "/usr/local/bin/deploy_bikergram_app.sh && /usr/local/bin/cleanup_bikergram_releases.sh $KeepReleases"
& $ssh -p $Port -i $Key -o IdentitiesOnly=yes ("{0}@{1}" -f $User, $RemoteHost) ("sudo " + $remoteCmd)

Ok "DONE: https://app.bikergram.com/"
