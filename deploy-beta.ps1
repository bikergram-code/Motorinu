param(
  [string]$ProjectPath = "C:\Users\pinoi\BikergramFL\bikergram",
  [string]$KeyPath     = "$env:USERPROFILE\.ssh\netcup_ed25519",
  [string]$HostName    = "ssh.bikergram.com",
  [string]$UserName    = "bikergram",
  [int]$Port           = 2222
)

Set-Location $ProjectPath

flutter clean
flutter pub get
flutter build web --release

$ts  = Get-Date -Format "yyyyMMdd_HHmmss"
$zip = "$env:TEMP\bikergram_beta_$ts.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path ".\build\web\*" -DestinationPath $zip -Force

# PowerShell-safe target (no "$Host:" parsing issue)
$remote = "$UserName@$HostName"
$remoteZip = "/tmp/bikergram_web.zip"

scp -P $Port -i $KeyPath $zip "${remote}:$remoteZip"
ssh -p $Port -i $KeyPath $remote "sudo /opt/bikergram/bin/bikergram_deploy_web_beta.sh $remoteZip"
