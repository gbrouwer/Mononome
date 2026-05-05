[CmdletBinding()]
param(
    [string]$HostName = "norns.local",
    [string]$User = "we",
    [string]$KeyPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    $KeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
}

$publicKeyPath = "$KeyPath.pub"
$sshDir = Split-Path -Parent $KeyPath

if (-not (Test-Path -LiteralPath $publicKeyPath)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    Write-Host "Creating SSH key: $KeyPath"
    & ssh-keygen -t ed25519 -f $KeyPath -N ""
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-keygen failed with exit code $LASTEXITCODE"
    }
}

$ssh = Get-Command ssh -ErrorAction Stop
$remote = "${User}@${HostName}"
$remoteCommand = "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

Write-Host "Installing $publicKeyPath on $remote"
Write-Host "Enter the norns password if prompted."
Get-Content -Raw -LiteralPath $publicKeyPath | & $ssh.Source $remote $remoteCommand
if ($LASTEXITCODE -ne 0) {
    throw "SSH key install failed with exit code $LASTEXITCODE"
}

Write-Host "SSH key installed. Test with: ssh $remote `"hostname && ls /home/we/dust/code`""
