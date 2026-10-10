# Author: Jonathan Marien (jondmarien)
# play-sound.ps1 - Windows sound layer for claude-skins.
# Usage: . ./play-sound.ps1; Invoke-SkinSound "Tink"
# Never throws. Missing audio support is a silent no-op.
# Set CLAUDE_SKINS_SOUND_DRY_RUN=1 to print the chosen backend instead of playing.

if (-not (Get-Command Write-SkinLine -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "common.ps1")
}

function Get-SkinSoundPlan {
    param([string]$SoundName)
    $plans = @{
        Basso     = @{ Waves = @("Windows Critical Stop.wav", "Windows Foreground.wav", "chord.wav"); System = "Hand"; Freq = 400; Ms = 140 }
        Blow      = @{ Waves = @("Windows Exclamation.wav", "Windows Notify.wav"); System = "Exclamation"; Freq = 520; Ms = 100 }
        Bottle    = @{ Waves = @("Windows Message Nudge.wav", "notify.wav"); System = "Asterisk"; Freq = 660; Ms = 80 }
        Frog      = @{ Waves = @("Windows Balloon.wav", "notify.wav"); System = "Asterisk"; Freq = 700; Ms = 90 }
        Funk      = @{ Waves = @("Windows Hardware Fail.wav", "Windows Exclamation.wav"); System = "Exclamation"; Freq = 300; Ms = 120 }
        Glass     = @{ Waves = @("Windows Ding.wav", "ding.wav"); System = "Asterisk"; Freq = 1040; Ms = 70 }
        Hero      = @{ Waves = @("tada.wav", "Windows Notify.wav"); System = "Asterisk"; Freq = 880; Ms = 90 }
        Morse     = @{ Waves = @("Windows Notify System Generic.wav", "notify.wav"); System = "Beep"; Freq = 740; Ms = 60 }
        Ping      = @{ Waves = @("Windows Notify.wav", "chimes.wav"); System = "Beep"; Freq = 988; Ms = 60 }
        Pop       = @{ Waves = @("Windows Pop-up Blocked.wav", "Windows Balloon.wav"); System = "Asterisk"; Freq = 840; Ms = 50 }
        Purr      = @{ Waves = @("Windows Background.wav", "notify.wav"); System = "Asterisk"; Freq = 620; Ms = 80 }
        Sosumi    = @{ Waves = @("chord.wav", "Windows Critical Stop.wav"); System = "Hand"; Freq = 440; Ms = 150 }
        Submarine = @{ Waves = @("Windows Proximity Notification.wav", "Windows Proximity Connection.wav"); System = "Beep"; Freq = 500; Ms = 100 }
        Tink      = @{ Waves = @("Windows Notify Messaging.wav", "chimes.wav", "ding.wav"); System = "Beep"; Freq = 1200; Ms = 40 }
    }
    $plan = $plans["bell"]
    if (-not [string]::IsNullOrWhiteSpace($SoundName) -and $plans.ContainsKey($SoundName)) {
        $plan = $plans[$SoundName]
    }
    if ($null -eq $plan) {
        $plan = @{ Waves = @("Windows Notify.wav", "notify.wav"); System = "Beep"; Freq = 800; Ms = 80 }
    }
    $preferred = ""
    if ($plan.Waves -and $plan.Waves.Count -gt 0) {
        $preferred = [string]$plan.Waves[0]
    }
    return [pscustomobject]@{
        Waves     = @($plan.Waves)
        Preferred = $preferred
        System    = [string]$plan.System
        Freq      = [int]$plan.Freq
        Ms        = [int]$plan.Ms
    }
}

function Find-WindowsSoundFile {
    param([string[]]$Names)
    if ($env:OS -ne "Windows_NT") {
        return ""
    }
    $root = $env:SystemRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = $env:WINDIR
    }
    if ([string]::IsNullOrWhiteSpace($root)) {
        return ""
    }
    $media = Join-Path $root "Media"
    foreach ($name in $Names) {
        $candidate = Join-Path $media $name
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return ""
}

function Initialize-SoundAssemblies {
    if ($script:SkinSoundAssembliesReady) {
        return
    }
    $script:SkinSoundAssembliesReady = $true
    foreach ($name in @("System.Windows.Extensions", "PresentationCore")) {
        try {
            Add-Type -AssemblyName $name -ErrorAction SilentlyContinue | Out-Null
        } catch {
            $null = $_
        }
    }
}

function Start-DetachedSoundPlayer {
    param([string]$Path)
    try {
        $launch = Get-PowerShellLaunch
        $safe = $Path.Replace("'", "''")
        $command = "try { `$player = New-Object System.Media.SoundPlayer '$safe'; `$player.PlaySync() } catch {}"
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
        $encoded = [Convert]::ToBase64String($bytes)
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = $launch.Path
        $start.Arguments = "-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand $encoded"
        $start.CreateNoWindow = $true
        $start.UseShellExecute = $false
        $start.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $proc = [System.Diagnostics.Process]::Start($start)
        return ($null -ne $proc)
    } catch {
        $null = $_
        return $false
    }
}

function Start-InProcessSoundPlayer {
    param([string]$Path)
    try {
        Initialize-SoundAssemblies
        $player = New-Object System.Media.SoundPlayer $Path
        $player.Play()
        return $true
    } catch {
        $null = $_
        return $false
    }
}

function Start-SystemMediaSound {
    param([string]$Name)
    try {
        Initialize-SoundAssemblies
        if ($Name -ceq "Hand") {
            [System.Media.SystemSounds]::Hand.Play()
            return $true
        }
        if ($Name -ceq "Exclamation") {
            [System.Media.SystemSounds]::Exclamation.Play()
            return $true
        }
        if ($Name -ceq "Asterisk") {
            [System.Media.SystemSounds]::Asterisk.Play()
            return $true
        }
        if ($Name -ceq "Question") {
            [System.Media.SystemSounds]::Question.Play()
            return $true
        }
        [System.Media.SystemSounds]::Beep.Play()
        return $true
    } catch {
        $null = $_
        return $false
    }
}

function Invoke-SkinSound {
    param([string]$SoundName)
    try {
        if ([string]::IsNullOrWhiteSpace($SoundName)) {
            return
        }
        $plan = Get-SkinSoundPlan $SoundName
        if ($env:CLAUDE_SKINS_SOUND_DRY_RUN -eq "1") {
            Write-SkinLine ("preferred=" + $plan.Preferred + "; system=" + $plan.System + "; beep=" + $plan.Freq + ":" + $plan.Ms)
            return
        }
        if ($env:OS -eq "Windows_NT") {
            $wav = Find-WindowsSoundFile $plan.Waves
            if (-not [string]::IsNullOrWhiteSpace($wav)) {
                if (Start-DetachedSoundPlayer $wav) { return }
                if (Start-InProcessSoundPlayer $wav) { return }
            }
            if (Start-SystemMediaSound $plan.System) { return }
        }
        try {
            [Console]::Beep($plan.Freq, $plan.Ms)
        } catch {
            $null = $_
        }
    } catch {
        $null = $_
    }
}
