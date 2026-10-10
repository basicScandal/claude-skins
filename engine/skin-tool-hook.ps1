# Author: Jonathan Marien (jondmarien)
# Claude Skins - PostToolUse hook.
# Reads Claude Code's tool JSON on stdin and plays the skin's event sound.
# https://code.claude.com/docs/en/hooks

. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "play-sound.ps1")

function Get-CachedEventSound {
    param(
        [string[]]$Lines,
        [string]$EventName
    )
    $seenHeader = $false
    foreach ($line in $Lines) {
        if (-not $seenHeader) {
            $seenHeader = $true
            continue
        }
        $split = $line.IndexOf(":")
        if ($split -lt 0) {
            continue
        }
        $name = $line.Substring(0, $split)
        if ($name -ceq $EventName) {
            $rest = $line.Substring($split + 1)
            $split2 = $rest.IndexOf(":")
            if ($split2 -lt 0) {
                return $rest
            }
            return $rest.Substring(0, $split2)
        }
    }
    return ""
}

function Invoke-SkinToolHook {
    Initialize-SkinEncoding
    $engineDir = Get-EngineDir
    $skinName = ""
    if (Test-Path -LiteralPath (Join-Path $engineDir "current")) {
        $skinName = Read-CurrentSkinName $engineDir
    }
    if ([string]::IsNullOrWhiteSpace($skinName) -or $skinName -ceq "default") {
        return 0
    }

    $skinFile = Join-Path (Get-SkinsDir) ($skinName + ".yaml")
    if (-not (Test-Path -LiteralPath $skinFile)) {
        return 0
    }

    $safeName = $skinName -replace "[^A-Za-z0-9._-]", "_"
    $cache = Get-SkinTempFile ("claude-skin-tools-" + $safeName)
    if ((Get-FileAgeSeconds $cache) -gt 60) {
        . (Join-Path $PSScriptRoot "parse-yaml.ps1")
        $sounds = (Get-YamlValue $skinFile "tools.sounds").Trim()
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append($sounds).Append("`n")
        foreach ($eventName in @("file_written", "command_run", "error", "search")) {
            $sound = Get-YamlEventField $skinFile $eventName "sound"
            $icon = Get-YamlEventField $skinFile $eventName "icon"
            [void]$sb.Append($eventName).Append(":").Append($sound).Append(":").Append($icon).Append("`n")
        }
        Write-Utf8NoBom -Path $cache -Text $sb.ToString()
    }
    if (-not (Test-Path -LiteralPath $cache)) {
        return 0
    }

    $lines = Read-Utf8Lines $cache
    if ($lines.Length -eq 0 -or $lines[0].Trim() -cne "true") {
        return 0
    }

    $payload = $null
    try {
        $payload = ConvertFrom-StdinJson
    } catch {
        return 0
    }
    $toolName = [string](Get-NoteProperty $payload @("tool_name") "")
    if ([string]::IsNullOrWhiteSpace($toolName)) {
        $toolName = [string](Get-NoteProperty $payload @("tool") "")
    }

    $eventName = ""
    if ($toolName -ceq "Write" -or $toolName -ceq "Edit" -or $toolName -ceq "MultiEdit" -or $toolName -ceq "NotebookEdit") {
        $eventName = "file_written"
    } elseif ($toolName -ceq "Bash" -or $toolName -ceq "PowerShell") {
        $eventName = "command_run"
    } elseif ($toolName -ceq "Grep" -or $toolName -ceq "Glob") {
        $eventName = "search"
    } else {
        return 0
    }

    $sound = Get-CachedEventSound $lines $eventName
    if (-not [string]::IsNullOrWhiteSpace($sound)) {
        Invoke-SkinSound $sound
    }
    return 0
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        $code = Invoke-SkinToolHook
        exit $code
    } catch {
        exit 0
    }
}
