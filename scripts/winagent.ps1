param (
  [string]$AZP_URL,
  [string]$AZP_TOKEN,
  [string]$AZP_TOKEN_FILE,
  [string]$AZP_AGENT_NAME,
  [string]$AZP_POOL,
  [string]$AZP_WORK
)

$Env:AZP_URL = $AZP_URL
$Env:AZP_TOKEN = $AZP_TOKEN
$Env:AZP_TOKEN_FILE = $AZP_TOKEN_FILE
$Env:AZP_AGENT_NAME = $AZP_AGENT_NAME
$Env:AZP_POOL = $AZP_POOL
$Env:AZP_WORK = $AZP_WORK

if (-not (Test-Path Env:AZP_URL)) {
  Write-Error "error: missing AZP_URL environment variable"
  exit 1
}

if (-not (Test-Path "\azp")) {
  New-Item "\azp" -ItemType directory | Out-Null
}

if (-not (Test-Path Env:AZP_TOKEN_FILE)) {
  if (-not (Test-Path Env:AZP_TOKEN)) {
    Write-Error "error: missing AZP_TOKEN environment variable"
    exit 1
  }

  Write-Host "Write to TOKEN file."
  $Env:AZP_TOKEN_FILE = "\azp\.token"
  $Env:AZP_TOKEN | Out-File -FilePath $Env:AZP_TOKEN_FILE
}
   
Remove-Item Env:AZP_TOKEN

if ((Test-Path Env:AZP_WORK) -and -not (Test-Path $Env:AZP_WORK)) {
  New-Item $Env:AZP_WORK -ItemType directory | Out-Null
}

if (-not (Test-Path "\azp\agent")) {
  New-Item "\azp\agent" -ItemType directory | Out-Null
}

if (-not (Test-Path "\agent")) {
  New-Item "\agent" -ItemType directory | Out-Null
}

# Let the agent ignore the token env variables
$Env:VSO_AGENT_IGNORE = "AZP_TOKEN,AZP_TOKEN_FILE"

if (-not (Test-Path "\azp\agent\config.cmd")) {

  Set-Location '\agent'
  
  Write-Host "1. Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
  
  $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$(Get-Content ${Env:AZP_TOKEN_FILE})"))
  $package = Invoke-RestMethod -Headers @{Authorization=("Basic $base64AuthInfo")} "$(${Env:AZP_URL})/_apis/distributedtask/packages/agent?platform=win-x64&`$top=1"
  $packageUrl = $package[0].Value.downloadUrl
  
  Write-Host $packageUrl
  
  Write-Host "2. Downloading and installing Azure Pipelines agent..." -ForegroundColor Cyan

  $wc = New-Object System.Net.WebClient
  $wc.DownloadFile($packageUrl, "$(Get-Location)\agent.zip")
  
  Expand-Archive -Path "agent.zip" -DestinationPath "\azp\agent"
}


Write-Host "3. Configuring Azure Pipelines agent..." -ForegroundColor Cyan

Set-Location "\azp\agent"

.\config.cmd --unattended `
  --agent "$(if (Test-Path Env:AZP_AGENT_NAME) { ${Env:AZP_AGENT_NAME} } else { hostname })" `
  --url "$(${Env:AZP_URL})" `
  --auth PAT `
  --token "$(Get-Content ${Env:AZP_TOKEN_FILE})" `
  --pool "$(if (Test-Path Env:AZP_POOL) { ${Env:AZP_POOL} } else { 'Default' })" `
  --work "$(if (Test-Path Env:AZP_WORK) { ${Env:AZP_WORK} } else { '_work' })" `
  --replace --runAsService --windowsLogonAccount  "NT AUTHORITY\NETWORK SERVICE"

# Install Azure CLI
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi

# Install .NET SDK both LTS and STS
Invoke-WebRequest -UseBasicParsing https://dot.net/v1/dotnet-install.ps1 -OutFile .\dotnet-install.ps1; .\dotnet-isntall.ps1 -Channel LTS; .\dotnet-isntall.ps1 -Channel STS; Remove-Item .\dotnet-install.ps1