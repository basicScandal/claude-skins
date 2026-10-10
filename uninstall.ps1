# Author: Jonathan Marien (jondmarien)
# Claude Skins - Windows uninstaller.
# Removes the skins directory, the /skin skill, personality links, and the
# engine hooks from settings.json. Accepts a piped y/N answer. With no
# console and no piped input, the settings backup is not restored.

param()

. (Join-Path (Join-Path $PSScriptRoot "engine") "common.ps1")

function Read-YesNo {
    param([string]$Prompt)
    try {
        if ([Console]::IsInputRedirected) {
            $line = [Console]::In.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) {
                return $false
            }
            return $line.Trim().StartsWith("y", [System.StringComparison]::OrdinalIgnoreCase)
        }
    } catch {
        return $false
    }

    $interactive = $false
    try {
        $interactive = [Console]::WindowHeight -gt 0
    } catch {
        $interactive = $false
    }
    if (-not $interactive) {
        Write-SkinLine ($Prompt + " [y/N] n")
        return $false
    }

    Write-SkinLine $Prompt
    $answer = Read-Host
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $false
    }
    return $answer.Trim().StartsWith("y", [System.StringComparison]::OrdinalIgnoreCase)
}

function Remove-WindowsSkinHooks {
    param($Config)
    $changed = $false
    $fragments = Get-SkinHookFragments
    if ($Config.Contains("hooks") -and $Config["hooks"] -is [System.Collections.IDictionary]) {
        $hooks = $Config["hooks"]
        foreach ($eventName in @($hooks.Keys)) {
            $entries = @()
            if ($null -ne $hooks[$eventName]) {
                $entries = @($hooks[$eventName])
            }
            $newEntries = New-Object System.Collections.Generic.List[object]
            foreach ($entry in $entries) {
                if (-not ($entry -is [System.Collections.IDictionary]) -or -not $entry.Contains("hooks")) {
                    $newEntries.Add($entry)
                    continue
                }
                $entryHooks = @()
                if ($null -ne $entry["hooks"]) {
                    $entryHooks = @($entry["hooks"])
                }
                $kept = New-Object System.Collections.Generic.List[object]
                foreach ($hook in $entryHooks) {
                    if (Test-TextHasFragment (Get-HookSearchText $hook) $fragments) {
                        $changed = $true
                    } else {
                        $kept.Add($hook)
                    }
                }
                if ($kept.Count -gt 0) {
                    $entry["hooks"] = $kept.ToArray()
                    $newEntries.Add($entry)
                } elseif ($entryHooks.Count -gt 0) {
                    $changed = $true
                }
            }
            $hooks[$eventName] = $newEntries.ToArray()
        }
    }

    if ($Config.Contains("statusLine") -and $Config["statusLine"] -is [System.Collections.IDictionary]) {
        $command = ""
        if ($Config["statusLine"].Contains("command") -and $null -ne $Config["statusLine"]["command"]) {
            $command = [string]$Config["statusLine"]["command"]
        }
        if (Test-TextHasFragment $command (Get-SkinStatusFragments)) {
            [void]$Config.Remove("statusLine")
            $changed = $true
            Write-SkinLine "  Removed statusLine configuration"
        }
    }
    return $changed
}

function Invoke-ClaudeSkinsUninstall {
    $ErrorActionPreference = "Stop"
    Initialize-SkinEncoding

    $claudeDir = Get-ClaudeDir
    $settings = Join-Path $claudeDir "settings.json"
    $backup = $settings + ".backup"
    $skipPatch = $false

    Write-SkinLine "Uninstalling Claude Skins..."

    if (Test-Path -LiteralPath $backup) {
        Write-SkinLine ""
        $restore = Read-YesNo "Backup found at settings.json.backup -- restore it?"
        if ($restore) {
            Copy-Item -LiteralPath $backup -Destination $settings -Force
            Write-SkinLine "  Restored settings.json from backup"
            $skipPatch = $true
        }
    }

    if (-not $skipPatch -and (Test-Path -LiteralPath $settings)) {
        try {
            $cfg = Read-SettingsObject $settings
            if (Remove-WindowsSkinHooks $cfg) {
                Write-Utf8NoBom -Path $settings -Text (ConvertTo-SettingsJson $cfg)
                Write-SkinLine "  Removed skin hooks from settings.json"
            } else {
                Write-SkinLine "  No skin hooks found in settings.json -- nothing to remove"
            }
        } catch {
            Write-SkinLine "  settings.json could not be parsed -- left it in place"
        }
    }

    Remove-SkinPersonalities

    $skins = Get-SkinsDir
    if (Test-Path -LiteralPath $skins) {
        Remove-Item -LiteralPath $skins -Recurse -Force
        Write-SkinLine "  Removed $skins"
    } else {
        Write-SkinLine "  $skins not found -- skipped"
    }

    $skill = Join-Path (Join-Path $claudeDir "skills") "skin"
    if (Test-Path -LiteralPath $skill) {
        Remove-Item -LiteralPath $skill -Recurse -Force
        Write-SkinLine "  Removed $skill"
    } else {
        Write-SkinLine "  $skill not found -- skipped"
    }

    if (Test-Path -LiteralPath $backup) {
        Remove-Item -LiteralPath $backup -Force
        Write-SkinLine "  Removed settings.json.backup"
    }

    Write-SkinLine ""
    Write-SkinLine "Claude Skins uninstalled. Restart Claude Code to complete removal."
    Write-SkinLine ""
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        Invoke-ClaudeSkinsUninstall
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 1
    }
}
