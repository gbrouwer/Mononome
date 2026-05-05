[CmdletBinding()]
param(
    [string]$HostName = "norns.local",
    [string]$User = "we",
    [string]$RemoteCodeDir = "/home/we/dust/code",
    [string]$LocalCodeDir = "",
    [string]$Name = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Quote-Posix {
    param([Parameter(Mandatory = $true)][string]$Value)
    $singleQuote = "'"
    return $singleQuote + $Value.Replace($singleQuote, $singleQuote + '"' + $singleQuote + '"' + $singleQuote) + $singleQuote
}

function Assert-NoNestedGitDirs {
    param([Parameter(Mandatory = $true)][string[]]$Paths)

    $nestedGitDirs = @()
    foreach ($path in $Paths) {
        if ((Test-Path -LiteralPath $path -PathType Container)) {
            $nestedGitDirs += @(Get-ChildItem -LiteralPath $path -Recurse -Force -Directory -Filter ".git" -ErrorAction SilentlyContinue)
        }
    }

    if ($nestedGitDirs.Count -gt 0) {
        $list = ($nestedGitDirs | Select-Object -First 10 | ForEach-Object { $_.FullName }) -join [Environment]::NewLine
        throw "Refusing to push nested .git directories to norns. Remove them first. Found:${list}"
    }
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LocalCodeDir)) {
    $LocalCodeDir = Join-Path $ProjectRoot "code"
}

if (-not (Test-Path -LiteralPath $LocalCodeDir)) {
    throw "Local code directory does not exist: $LocalCodeDir"
}

$ssh = Get-Command ssh -ErrorAction Stop
$scp = Get-Command scp -ErrorAction Stop
$sshOptions = @(
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=10"
)

$remote = "${User}@${HostName}"
$quotedRemoteDir = Quote-Posix $RemoteCodeDir
& $ssh.Source @sshOptions $remote "mkdir -p $quotedRemoteDir"
if ($LASTEXITCODE -ne 0) {
    throw "Remote mkdir failed with exit code $LASTEXITCODE"
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $items = @(Get-ChildItem -Force -LiteralPath $LocalCodeDir | Where-Object { $_.Name -ne ".gitkeep" })
    if ($items.Count -eq 0) {
        Write-Host "No local code to push from $LocalCodeDir."
        exit 0
    }

    $sources = @($items | ForEach-Object { $_.FullName })
    Write-Host "Pushing all local code from $LocalCodeDir -> ${remote}:${RemoteCodeDir}"
} else {
    $source = Join-Path $LocalCodeDir $Name
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Cannot find local script folder/file: $source"
    }

    $sources = @((Resolve-Path -LiteralPath $source).Path)
    Write-Host "Pushing $Name -> ${remote}:${RemoteCodeDir}"
}

Assert-NoNestedGitDirs -Paths $sources

$remoteTarget = "${remote}:${RemoteCodeDir}/"
& $scp.Source @sshOptions -r @sources $remoteTarget
if ($LASTEXITCODE -ne 0) {
    throw "scp push failed with exit code $LASTEXITCODE"
}

Write-Host "Push complete."
