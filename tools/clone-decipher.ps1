[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ToDisplayName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $tokens = $Value -split '[-_ ]+'
    $displayTokens = foreach ($token in $tokens) {
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }

        $first = $token.Substring(0, 1).ToUpperInvariant()
        if ($token.Length -eq 1) {
            $first
        } else {
            $first + $token.Substring(1)
        }
    }

    return ($displayTokens -join " ")
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CodeRoot = Join-Path $ProjectRoot "code"
$SourceDir = Join-Path $CodeRoot "decipher"
$TargetDir = Join-Path $CodeRoot $Name
$DisplayName = Convert-ToDisplayName $Name

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Cannot find source instrument: $SourceDir"
}

if (Test-Path -LiteralPath $TargetDir) {
    throw "Target instrument already exists: $TargetDir"
}

Copy-Item -LiteralPath $SourceDir -Destination $TargetDir -Recurse -Force

$oldMain = Join-Path $TargetDir "decipher.lua"
$newMain = Join-Path $TargetDir "$Name.lua"
if (Test-Path -LiteralPath $oldMain) {
    Move-Item -LiteralPath $oldMain -Destination $newMain
}

$oldLib = Join-Path $TargetDir "lib\decipher"
$newLib = Join-Path $TargetDir "lib\$Name"
if (Test-Path -LiteralPath $oldLib) {
    Move-Item -LiteralPath $oldLib -Destination $newLib
}

$textExtensions = @(
    ".lua",
    ".sc",
    ".scd",
    ".md",
    ".txt",
    ".json",
    ".yml",
    ".yaml",
    ".html",
    ".css",
    ".js",
    ".svg",
    ".pset"
)

$textFiles = Get-ChildItem -LiteralPath $TargetDir -Recurse -Force -File |
    Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }

foreach ($file in $textFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    $updated = $content.
        Replace("DECIPHER", $Name.ToUpperInvariant()).
        Replace("Decipher", $DisplayName).
        Replace("decipher", $Name)

    if ($updated -ne $content) {
        Set-Content -LiteralPath $file.FullName -Value $updated -NoNewline
    }
}

Write-Host "Cloned decipher into $Name."
Write-Host "Created: $TargetDir"
