[CmdletBinding()]
param(
    [int]$ListenPort = 7123,
    [int]$MidiOutIndex = -1,
    [string]$MidiOutName = "",
    [switch]$ListDevices,
    [switch]$ListDevicesJson,
    [switch]$VerbosePackets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$winMmSource = @"
using System;
using System.Runtime.InteropServices;

public static class WinMM {
    [DllImport("winmm.dll")]
    public static extern uint midiOutGetNumDevs();

    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    public static extern uint midiOutGetDevCaps(UIntPtr uDeviceID, out MIDIOUTCAPS lpMidiOutCaps, uint cbMidiOutCaps);

    [DllImport("winmm.dll")]
    public static extern uint midiOutOpen(out IntPtr lphmo, uint uDeviceID, IntPtr dwCallback, IntPtr dwInstance, uint fdwOpen);

    [DllImport("winmm.dll")]
    public static extern uint midiOutShortMsg(IntPtr hmo, uint dwMsg);

    [DllImport("winmm.dll")]
    public static extern uint midiOutClose(IntPtr hmo);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MIDIOUTCAPS {
        public ushort wMid;
        public ushort wPid;
        public uint vDriverVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szPname;
        public ushort wTechnology;
        public ushort wVoices;
        public ushort wNotes;
        public ushort wChannelMask;
        public uint dwSupport;
    }
}
"@

if (-not ("WinMM" -as [type])) {
    Add-Type -TypeDefinition $winMmSource
}

function Get-MidiOutDevices {
    $count = [WinMM]::midiOutGetNumDevs()
    $devices = @()
    for ($i = 0; $i -lt $count; $i++) {
        $caps = New-Object WinMM+MIDIOUTCAPS
        $capsSize = [Runtime.InteropServices.Marshal]::SizeOf([type][WinMM+MIDIOUTCAPS])
        $result = [WinMM]::midiOutGetDevCaps([UIntPtr]::new([uint32]$i), [ref]$caps, [uint32]$capsSize)
        if ($result -eq 0) {
            $devices += [PSCustomObject]@{
                Index = $i
                Name = $caps.szPname
            }
        }
    }
    return $devices
}

function Show-MidiOutDevices {
    $devices = Get-MidiOutDevices
    if ($devices.Count -eq 0) {
        Write-Host "No Windows MIDI output devices found."
        return
    }

    $devices | Format-Table -AutoSize
}

function Read-OscString {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][ref]$Offset
    )

    $start = $Offset.Value
    while ($Offset.Value -lt $Bytes.Length -and $Bytes[$Offset.Value] -ne 0) {
        $Offset.Value++
    }

    $length = $Offset.Value - $start
    $text = [Text.Encoding]::ASCII.GetString($Bytes, $start, $length)
    $paddedLength = [int]([Math]::Ceiling(($length + 1) / 4.0) * 4)
    $Offset.Value = $start + $paddedLength
    return $text
}

function Read-BigEndianInt32 {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][ref]$Offset
    )

    $chunk = New-Object byte[] 4
    [Array]::Copy($Bytes, $Offset.Value, $chunk, 0, 4)
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($chunk)
    }
    $Offset.Value += 4
    return [BitConverter]::ToInt32($chunk, 0)
}

function Read-BigEndianFloat32 {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][ref]$Offset
    )

    $chunk = New-Object byte[] 4
    [Array]::Copy($Bytes, $Offset.Value, $chunk, 0, 4)
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($chunk)
    }
    $Offset.Value += 4
    return [BitConverter]::ToSingle($chunk, 0)
}

function ConvertFrom-OscPacket {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    $offset = 0
    $path = Read-OscString -Bytes $Bytes -Offset ([ref]$offset)
    $typeTags = Read-OscString -Bytes $Bytes -Offset ([ref]$offset)
    if (-not $typeTags.StartsWith(",")) {
        throw "Invalid OSC type tag string: $typeTags"
    }

    $args = @()
    foreach ($tag in $typeTags.Substring(1).ToCharArray()) {
        switch ($tag) {
            "i" { $args += Read-BigEndianInt32 -Bytes $Bytes -Offset ([ref]$offset) }
            "f" { $args += Read-BigEndianFloat32 -Bytes $Bytes -Offset ([ref]$offset) }
            "s" { $args += Read-OscString -Bytes $Bytes -Offset ([ref]$offset) }
            "T" { $args += $true }
            "F" { $args += $false }
            default { throw "Unsupported OSC type tag: $tag" }
        }
    }

    return [PSCustomObject]@{
        Path = $path
        Args = $args
    }
}

function Convert-ToMidiByte {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [int]$Min = 0,
        [int]$Max = 127
    )

    return [Math]::Max($Min, [Math]::Min($Max, [int][Math]::Round([double]$Value)))
}

function Get-NumericOscArgs {
    param([Parameter(Mandatory = $true)][object[]]$Args)

    return @($Args | Where-Object {
        $_ -is [byte] -or
        $_ -is [int16] -or
        $_ -is [int32] -or
        $_ -is [int64] -or
        $_ -is [single] -or
        $_ -is [double]
    })
}

function Send-MidiShortMessage {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Handle,
        [Parameter(Mandatory = $true)][int]$Status,
        [Parameter(Mandatory = $true)][int]$Data1,
        [Parameter(Mandatory = $true)][int]$Data2
    )

    $message = [uint32]($Status -bor ($Data1 -shl 8) -bor ($Data2 -shl 16))
    $result = [WinMM]::midiOutShortMsg($Handle, $message)
    if ($result -ne 0) {
        throw "midiOutShortMsg failed with code $result"
    }
}

function Send-NoteOn {
    param([IntPtr]$Handle, [int]$Channel, [int]$Note, [int]$Velocity)
    $status = 0x90 + ($Channel - 1)
    Send-MidiShortMessage -Handle $Handle -Status $status -Data1 $Note -Data2 $Velocity
}

function Send-NoteOff {
    param([IntPtr]$Handle, [int]$Channel, [int]$Note, [int]$Velocity = 0)
    $status = 0x80 + ($Channel - 1)
    Send-MidiShortMessage -Handle $Handle -Status $status -Data1 $Note -Data2 $Velocity
}

function Send-ControlChange {
    param([IntPtr]$Handle, [int]$Channel, [int]$Cc, [int]$Value)
    $status = 0xB0 + ($Channel - 1)
    Send-MidiShortMessage -Handle $Handle -Status $status -Data1 $Cc -Data2 $Value
}

if ($ListDevices) {
    Show-MidiOutDevices
    exit 0
}

if ($ListDevicesJson) {
    Get-MidiOutDevices | ConvertTo-Json -Compress
    exit 0
}

$devices = @(Get-MidiOutDevices)
if ($devices.Count -eq 0) {
    throw "No Windows MIDI output devices found. Create a virtual port first, for example with loopMIDI."
}

if ($MidiOutIndex -lt 0 -and [string]::IsNullOrWhiteSpace($MidiOutName)) {
    $loopDevice = $devices | Where-Object { $_.Name -like "*loopMIDI*" } | Select-Object -First 1
    if ($loopDevice) {
        $MidiOutIndex = $loopDevice.Index
    } else {
        Write-Host "Choose a MIDI output device:"
        Show-MidiOutDevices
        throw "Pass -MidiOutIndex N or -MidiOutName `"device name`". For Ableton on Windows, this is usually a loopMIDI virtual port."
    }
}

if ($MidiOutIndex -lt 0) {
    $match = $devices | Where-Object { $_.Name -like "*$MidiOutName*" } | Select-Object -First 1
    if (-not $match) {
        Show-MidiOutDevices
        throw "Could not find MIDI output matching: $MidiOutName"
    }
    $MidiOutIndex = $match.Index
}

$selected = $devices | Where-Object { $_.Index -eq $MidiOutIndex } | Select-Object -First 1
if (-not $selected) {
    Show-MidiOutDevices
    throw "Invalid MIDI output index: $MidiOutIndex"
}

$handle = [IntPtr]::Zero
$openResult = [WinMM]::midiOutOpen([ref]$handle, [uint32]$MidiOutIndex, [IntPtr]::Zero, [IntPtr]::Zero, 0)
if ($openResult -ne 0) {
    throw "midiOutOpen failed with code $openResult"
}

$udp = [Net.Sockets.UdpClient]::new($ListenPort)
$udp.Client.ReceiveTimeout = 25
$remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
$pendingNoteOffs = New-Object System.Collections.Generic.List[object]

$localIps = [Net.Dns]::GetHostAddresses($env:COMPUTERNAME) |
    Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } |
    ForEach-Object { $_.IPAddressToString }

Write-Host "OSC -> MIDI bridge listening on UDP port $ListenPort"
Write-Host "MIDI output: [$($selected.Index)] $($selected.Name)"
Write-Host "PC IP candidates for norns target: $($localIps -join ', ')"
Write-Host "Expected OSC:"
Write-Host "  /midi/note     note velocity channel duration_ms"
Write-Host "  /midi/note_on  note velocity channel"
Write-Host "  /midi/note_off note velocity channel"
Write-Host "  /midi/cc       cc value channel"
Write-Host "Press Ctrl+C to stop."

try {
    while ($true) {
        try {
            $bytes = $udp.Receive([ref]$remote)
            $packet = ConvertFrom-OscPacket -Bytes $bytes

            if ($VerbosePackets) {
                Write-Host "$($remote.Address):$($remote.Port) $($packet.Path) $($packet.Args -join ' ')"
            }

            switch ($packet.Path) {
                "/midi/note" {
                    $numericArgs = Get-NumericOscArgs $packet.Args
                    if ($numericArgs.Count -lt 4) { throw "/midi/note needs note velocity channel duration_ms" }
                    $note = Convert-ToMidiByte $numericArgs[0]
                    $velocity = Convert-ToMidiByte $numericArgs[1]
                    $channel = Convert-ToMidiByte $numericArgs[2] -Min 1 -Max 16
                    $durationMs = [Math]::Max(1, [int][Math]::Round([double]$numericArgs[3]))
                    Send-NoteOn -Handle $handle -Channel $channel -Note $note -Velocity $velocity
                    $pendingNoteOffs.Add([PSCustomObject]@{
                        At = [DateTime]::UtcNow.AddMilliseconds($durationMs)
                        Note = $note
                        Channel = $channel
                    }) | Out-Null
                }
                "/midi/note_on" {
                    $numericArgs = Get-NumericOscArgs $packet.Args
                    if ($numericArgs.Count -lt 3) { throw "/midi/note_on needs note velocity channel" }
                    Send-NoteOn `
                        -Handle $handle `
                        -Note (Convert-ToMidiByte $numericArgs[0]) `
                        -Velocity (Convert-ToMidiByte $numericArgs[1]) `
                        -Channel (Convert-ToMidiByte $numericArgs[2] -Min 1 -Max 16)
                }
                "/midi/note_off" {
                    $numericArgs = Get-NumericOscArgs $packet.Args
                    if ($numericArgs.Count -lt 3) { throw "/midi/note_off needs note velocity channel" }
                    Send-NoteOff `
                        -Handle $handle `
                        -Note (Convert-ToMidiByte $numericArgs[0]) `
                        -Velocity (Convert-ToMidiByte $numericArgs[1]) `
                        -Channel (Convert-ToMidiByte $numericArgs[2] -Min 1 -Max 16)
                }
                "/midi/cc" {
                    $numericArgs = Get-NumericOscArgs $packet.Args
                    if ($numericArgs.Count -lt 3) { throw "/midi/cc needs cc value channel" }
                    Send-ControlChange `
                        -Handle $handle `
                        -Cc (Convert-ToMidiByte $numericArgs[0]) `
                        -Value (Convert-ToMidiByte $numericArgs[1]) `
                        -Channel (Convert-ToMidiByte $numericArgs[2] -Min 1 -Max 16)
                }
            }
        } catch [Net.Sockets.SocketException] {
            if ($_.Exception.SocketErrorCode -ne [Net.Sockets.SocketError]::TimedOut) {
                throw
            }
        }

        $now = [DateTime]::UtcNow
        for ($i = $pendingNoteOffs.Count - 1; $i -ge 0; $i--) {
            $item = $pendingNoteOffs[$i]
            if ($item.At -le $now) {
                Send-NoteOff -Handle $handle -Channel $item.Channel -Note $item.Note
                $pendingNoteOffs.RemoveAt($i)
            }
        }
    }
} finally {
    for ($channel = 1; $channel -le 16; $channel++) {
        for ($note = 0; $note -le 127; $note++) {
            Send-NoteOff -Handle $handle -Channel $channel -Note $note
        }
    }
    $udp.Close()
    if ($handle -ne [IntPtr]::Zero) {
        [void][WinMM]::midiOutClose($handle)
    }
}
