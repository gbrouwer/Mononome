[CmdletBinding()]
param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 7123,
    [int]$Note = 60,
    [int]$Velocity = 110,
    [int]$Channel = 1,
    [int]$DurationMs = 500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-OscString {
    param([Parameter(Mandatory = $true)][string]$Value)

    $bytes = [Text.Encoding]::ASCII.GetBytes($Value + [char]0)
    $pad = (4 - ($bytes.Length % 4)) % 4
    if ($pad -eq 0) {
        return $bytes
    }
    return $bytes + (New-Object byte[] $pad)
}

function ConvertTo-OscInt {
    param([Parameter(Mandatory = $true)][int]$Value)

    $bytes = [BitConverter]::GetBytes([int32]$Value)
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }
    return $bytes
}

$payloadParts = @(
    (ConvertTo-OscString "/midi/note"),
    (ConvertTo-OscString ",iiii"),
    (ConvertTo-OscInt $Note),
    (ConvertTo-OscInt $Velocity),
    (ConvertTo-OscInt $Channel),
    (ConvertTo-OscInt $DurationMs)
)

$length = ($payloadParts | ForEach-Object { $_.Length } | Measure-Object -Sum).Sum
$payload = New-Object byte[] $length
$offset = 0
foreach ($part in $payloadParts) {
    [Array]::Copy($part, 0, $payload, $offset, $part.Length)
    $offset += $part.Length
}

$udp = [Net.Sockets.UdpClient]::new()
try {
    [void]$udp.Send($payload, $payload.Length, $HostName, $Port)
    Write-Host "Sent /midi/note $Note $Velocity $Channel $DurationMs to ${HostName}:$Port"
} finally {
    $udp.Close()
}
