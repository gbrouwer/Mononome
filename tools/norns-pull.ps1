[CmdletBinding()]
param(
    [string]$HostName = "norns.local",
    [string]$User = "we",
    [string]$RemoteCodeDir = "/home/we/dust/code",
    [string]$LocalCodeDir = "",
    [string]$Name = "",
    [switch]$KeepNestedGit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LocalCodeDir)) {
    $LocalCodeDir = Join-Path $ProjectRoot "code"
}

New-Item -ItemType Directory -Force -Path $LocalCodeDir | Out-Null

function Remove-NestedGitDirs {
    param([Parameter(Mandatory = $true)][string]$Root)

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $gitDirs = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Force -Directory -Filter ".git" -ErrorAction SilentlyContinue)

    foreach ($dir in $gitDirs) {
        $fullPath = $dir.FullName
        if (-not $fullPath.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove nested Git metadata outside ${resolvedRoot}: $fullPath"
        }
    }

    foreach ($dir in $gitDirs) {
        Remove-Item -LiteralPath $dir.FullName -Recurse -Force
    }

    if ($gitDirs.Count -gt 0) {
        Write-Host "Removed $($gitDirs.Count) nested .git directories from $resolvedRoot"
    }
}

$scp = Get-Command scp -ErrorAction Stop
$sshOptions = @(
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=10"
)

if ([string]::IsNullOrWhiteSpace($Name)) {
    $remoteSource = "${User}@${HostName}:${RemoteCodeDir}/*"
    Write-Host "Pulling all norns code from ${User}@${HostName}:${RemoteCodeDir} -> $LocalCodeDir"
} else {
    $remoteSource = "${User}@${HostName}:${RemoteCodeDir}/$Name"
    Write-Host "Pulling $Name from ${User}@${HostName}:${RemoteCodeDir} -> $LocalCodeDir"
}

& $scp.Source @sshOptions -r $remoteSource $LocalCodeDir
if ($LASTEXITCODE -ne 0) {
    throw "scp pull failed with exit code $LASTEXITCODE"
}

if (-not $KeepNestedGit) {
    Remove-NestedGitDirs -Root $LocalCodeDir
}

Write-Host "Pull complete."
