param(
  [string]$AppHost = "app.bikergram.com",
  [string]$AppUrl  = "https://app.bikergram.com",
  [string]$SshHost = "ssh.bikergram.com",
  [int]   $SshPort = 2222,
  [string]$SshUser = "bikergram",
  [string]$Key     = "$env:USERPROFILE\.ssh\netcup_ed25519",
  [switch]$Pause
)

$ErrorActionPreference = "Stop"

$FailCount = 0

function Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "[ .. ] $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:FailCount++ }

function Get-HeaderValue($headers, [string]$name) {
  try {
    $v = $headers[$name]
    if ($null -eq $v) { return "" }
    if ($v -is [System.Array]) { return ($v -join ", ") }
    return [string]$v
  } catch {
    return ""
  }
}

function Head($url) {
  # PS 5.1: -UseBasicParsing ist nötig
  return Invoke-WebRequest -Method Head -Uri $url -UseBasicParsing -TimeoutSec 15
}

function Assert-Status200($resp, [string]$what) {
  if ($resp.StatusCode -eq 200) { Ok "$what HTTP 200" } else { Fail "$what HTTP $($resp.StatusCode)" }
}

function Assert-CacheContains($resp, [string]$needle, [string]$what) {
  $cc = Get-HeaderValue $resp.Headers "Cache-Control"
  if ($cc -match [regex]::Escape($needle)) {
    Ok "$what Cache-Control enthält '$needle'"
  } else {
    Fail "$what Cache-Control enthält NICHT '$needle' (Ist: '$cc')"
  }
}

function Assert-CacheAnyContains($resp, [string[]]$needles, [string]$what) {
  $cc = Get-HeaderValue $resp.Headers "Cache-Control"
  foreach ($n in $needles) {
    if ($cc -match [regex]::Escape($n)) { Ok "$what Cache-Control enthält '$n'"; return }
  }
  Fail "$what Cache-Control enthält NICHT eins von: $($needles -join ', ') (Ist: '$cc')"
}

try {
  Info "== DNS Check (lokal) =="
  $r1 = Resolve-DnsName $AppHost -Type A -ErrorAction Stop | Select-Object -First 1
  Ok "$AppHost -> $($r1.IPAddress) (lokal)"
} catch {
  Fail "$AppHost DNS lokal failed: $($_.Exception.Message)"
}

try {
  Info "== DNS Check (Google 8.8.8.8) =="
  $r2 = Resolve-DnsName $AppHost -Server 8.8.8.8 -Type A -ErrorAction Stop | Select-Object -First 1
  Ok "$AppHost -> $($r2.IPAddress) (8.8.8.8)"
} catch {
  Fail "$AppHost DNS 8.8.8.8 failed: $($_.Exception.Message)"
}

Info "== HTTPS Header Checks =="
try {
  $hIndex = Head "$AppUrl/index.html"
  Assert-Status200 $hIndex "index.html"
  $lm = Get-HeaderValue $hIndex.Headers "Last-Modified"
  if ($lm) { Info ("index.html Last-Modified: {0}" -f $lm) }
  Assert-CacheContains $hIndex "no-store" "index.html"
} catch {
  Fail "index.html HEAD failed: $($_.Exception.Message)"
}

try {
  $hBoot = Head "$AppUrl/flutter_bootstrap.js"
  Assert-Status200 $hBoot "flutter_bootstrap.js"
  Assert-CacheContains $hBoot "no-store" "bootstrap"
} catch {
  Fail "flutter_bootstrap.js HEAD failed: $($_.Exception.Message)"
}

try {
  $hSw = Head "$AppUrl/flutter_service_worker.js"
  Assert-Status200 $hSw "flutter_service_worker.js"
  Assert-CacheContains $hSw "no-store" "service_worker"
} catch {
  Fail "flutter_service_worker.js HEAD failed: $($_.Exception.Message)"
}

# WICHTIG: main.dart.js ist NICHT gehasht -> immutable ist riskant (stale builds).
# Daher akzeptieren wir "no-store" oder wenigstens "no-cache".
try {
  $hMain = Head "$AppUrl/main.dart.js"
  Assert-Status200 $hMain "main.dart.js"
  Assert-CacheAnyContains $hMain @("no-store","no-cache") "main.dart.js"
} catch {
  Fail "main.dart.js HEAD failed: $($_.Exception.Message)"
}

try {
  $hAsset = Head "$AppUrl/assets/AssetManifest.bin.json"
  Assert-Status200 $hAsset "AssetManifest.bin.json"
  Assert-CacheContains $hAsset "immutable" "assets"
} catch {
  Fail "AssetManifest.bin.json HEAD failed: $($_.Exception.Message)"
}

Info "== SSH Check =="
try {
  $ssh = "$env:WINDIR\System32\OpenSSH\ssh.exe"
  $out = & $ssh -p $SshPort -i $Key -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 `
    "$SshUser@$SshHost" "echo SSH_OK" 2>&1

  if ($out -match "SSH_OK") { Ok ("SSH OK ({0}:{1})" -f $SshHost, $SshPort) }
  else { Fail ("SSH FAIL ({0}:{1}) Output: {2}" -f $SshHost, $SshPort, ($out | Out-String)) }
} catch {
  Fail "SSH Check failed: $($_.Exception.Message)"
}

if ($FailCount -eq 0) {
  Write-Host "`nRESULT: PASS" -ForegroundColor Green
  exit 0
} else {
  Write-Host "`nRESULT: FAIL" -ForegroundColor Red
  exit 1
}

if ($Pause) { Read-Host "Press Enter to exit" | Out-Null }
