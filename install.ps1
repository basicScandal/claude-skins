# Author: Jonathan Marien (jondmarien)
# Claude Skins - Windows installer.
# Copies skins, engine, and personalities into $env:USERPROFILE\.claude\skins,
# patches settings.json so Claude Code launches the .ps1 engine, and installs
# the /skin skill. macOS and Linux users should keep using install.sh.

param()

. (Join-Path (Join-Path $PSScriptRoot "engine") "common.ps1")

function Add-WindowsSkinHook {
    param(
        $Config,
        [string]$EventName,
        $Entry,
        [string]$Ps1Fragment,
        [string]$ShFragment
    )
    if (-not $Config.Contains("hooks") -or -not ($Config["hooks"] -is [System.Collections.IDictionary])) {
        $Config["hooks"] = [ordered]@{}
    }
    $hooks = $Config["hooks"]
    $existing = @()
    if ($hooks.Contains($EventName) -and $null -ne $hooks[$EventName]) {
        $existing = @($hooks[$EventName])
    }

    $newText = Get-HookSearchText @($Entry["hooks"])[0]
    # Older installs pointed hooks straight at pwsh/powershell; replace those too.
    $leaf = $Ps1Fragment.Substring($Ps1Fragment.LastIndexOf("/") + 1)
    $replace = @($ShFragment, $Ps1Fragment, ("skins/engine/run-engine.cmd " + $leaf))

    foreach ($current in $existing) {
        if (-not ($current -is [System.Collections.IDictionary]) -or -not $current.Contains("hooks")) {
            continue
        }
        $currentHooks = @()
        if ($null -ne $current["hooks"]) {
            $currentHooks = @($current["hooks"])
        }
        foreach ($hook in $currentHooks) {
            if ((Get-HookSearchText $hook) -ceq $newText) {
                return $false
            }
        }
    }

    $kept = New-Object System.Collections.Generic.List[object]
    foreach ($current in $existing) {
        if (-not ($current -is [System.Collections.IDictionary]) -or -not $current.Contains("hooks")) {
            $kept.Add($current)
            continue
        }
        $currentHooks = @()
        if ($null -ne $current["hooks"]) {
            $currentHooks = @($current["hooks"])
        }
        $surviving = New-Object System.Collections.Generic.List[object]
        foreach ($hook in $currentHooks) {
            if (-not (Test-TextHasFragment (Get-HookSearchText $hook) $replace)) {
                $surviving.Add($hook)
            }
        }
        if ($surviving.Count -gt 0) {
            $current["hooks"] = $surviving.ToArray()
            $kept.Add($current)
        }
    }
    $kept.Add($Entry)
    $hooks[$EventName] = $kept.ToArray()
    return $true
}

function Set-WindowsStatusLine {
    param(
        $Config,
        [string]$Command
    )
    $existing = ""
    if ($Config.Contains("statusLine") -and $Config["statusLine"] -is [System.Collections.IDictionary]) {
        if ($Config["statusLine"].Contains("command") -and $null -ne $Config["statusLine"]["command"]) {
            $existing = [string]$Config["statusLine"]["command"]
        }
    }
    if ($existing -ceq $Command) {
        Write-SkinLine "    statusLine already configured -- skipped"
        return $false
    }
    if (-not [string]::IsNullOrWhiteSpace($existing) -and -not (Test-TextHasFragment $existing (Get-SkinStatusFragments))) {
        # Never replace a status line the user set up themselves.
        Write-SkinLine "    statusLine is a custom command -- left unchanged"
        Write-SkinLine ("    To use the skin status line, set statusLine.command to: " + $Command)
        return $false
    }
    $Config["statusLine"] = [ordered]@{
        type    = "command"
        command = $Command
    }
    return $true
}

function Copy-TreeFiles {
    param(
        [string]$SourceDir,
        [string]$DestinationDir,
        [string[]]$Extensions,
        [string[]]$Names
    )
    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }
    $files = @(Get-ChildItem -LiteralPath $SourceDir -File -ErrorAction SilentlyContinue)
    $count = 0
    foreach ($file in $files) {
        $match = $false
        if ($Extensions -contains $file.Extension) {
            $match = $true
        }
        if ($Names -contains $file.Name) {
            $match = $true
        }
        if ($match) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $DestinationDir $file.Name) -Force
            $count++
        }
    }
    return $count
}

function Invoke-ClaudeSkinsInstall {
    $ErrorActionPreference = "Stop"
    Initialize-SkinEncoding

    $sourceRoot = $PSScriptRoot
    $claudeDir = Get-ClaudeDir
    $dest = Get-SkinsDir
    $engineDest = Get-EngineDir
    $settings = Join-Path $claudeDir "settings.json"
    $skillDir = Join-Path (Join-Path $claudeDir "skills") "skin"

    Write-SkinLine "Installing Claude Skins..."
    if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $engineDest)) {
        New-Item -ItemType Directory -Path $engineDest -Force | Out-Null
    }
    $personalityDest = Join-Path $dest "personalities"
    if (-not (Test-Path -LiteralPath $personalityDest)) {
        New-Item -ItemType Directory -Path $personalityDest -Force | Out-Null
    }

    [void](Copy-TreeFiles -SourceDir (Join-Path $sourceRoot "skins") -DestinationDir $dest -Extensions @(".yaml") -Names @())
    Write-SkinLine "  Copied skin definitions"

    [void](Copy-TreeFiles -SourceDir (Join-Path $sourceRoot "engine") -DestinationDir $engineDest -Extensions @(".ps1", ".sh", ".cmd") -Names @("SKILL.md"))
    Write-SkinLine "  Copied engine scripts"

    [void](Copy-TreeFiles -SourceDir (Join-Path $sourceRoot "personalities") -DestinationDir $personalityDest -Extensions @(".md") -Names @())
    Write-SkinLine "  Copied personality files"

    $config = Join-Path $engineDest "config.yaml"
    if (-not (Test-Path -LiteralPath $config)) {
        Write-Utf8NoBom -Path $config -Text "default_skin: nebula`n"
        Write-SkinLine "  Created default config (skin: nebula)"
    }
    $current = Join-Path $engineDest "current"
    if (-not (Test-Path -LiteralPath $current)) {
        Write-Utf8NoBom -Path $current -Text "default`n"
    }

    if (-not (Test-Path -LiteralPath $skillDir)) {
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $engineDest "SKILL.md") -Destination (Join-Path $skillDir "SKILL.md") -Force
    Write-SkinLine ("  Created " + (Join-Path $skillDir "SKILL.md"))

    Write-SkinLine "  Patching $settings..."
    if (-not (Test-Path -LiteralPath $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $settings)) {
        Write-Utf8NoBom -Path $settings -Text "{}`n"
    }
    # Keep the first backup: a reinstall must not replace the pre-skins settings.
    if (-not (Test-Path -LiteralPath ($settings + ".backup"))) {
        Copy-Item -LiteralPath $settings -Destination ($settings + ".backup") -Force
        Write-SkinLine "  Backed up settings.json to settings.json.backup"
    } else {
        Write-SkinLine "  settings.json.backup already exists -- kept it"
    }

    try {
        $cfg = Read-SettingsObject $settings
    } catch {
        throw "settings.json is not valid JSON. Left it unchanged."
    }

    $changed = $false
    $activateScript = Join-Path $engineDest "activate.ps1"
    $deactivateScript = Join-Path $engineDest "deactivate.ps1"
    $toolScript = Join-Path $engineDest "skin-tool-hook.ps1"
    $statusScript = Join-Path $engineDest "statusline.ps1"

    if (Add-WindowsSkinHook -Config $cfg -EventName "SessionStart" -Entry (New-EngineHookEntry -ScriptPath $activateScript) -Ps1Fragment "skins/engine/activate.ps1" -ShFragment "skins/engine/activate.sh") {
        $changed = $true
        Write-SkinLine "    Added SessionStart hook: activate.ps1"
    } else {
        Write-SkinLine "    SessionStart hook already present -- skipped"
    }

    if (Add-WindowsSkinHook -Config $cfg -EventName "SessionEnd" -Entry (New-EngineHookEntry -ScriptPath $deactivateScript) -Ps1Fragment "skins/engine/deactivate.ps1" -ShFragment "skins/engine/deactivate.sh") {
        $changed = $true
        Write-SkinLine "    Added SessionEnd hook: deactivate.ps1"
    } else {
        Write-SkinLine "    SessionEnd hook already present -- skipped"
    }

    $toolEntry = New-EngineHookEntry -ScriptPath $toolScript -Matcher "Bash|PowerShell|Write|Edit|MultiEdit|Grep|Glob" -Timeout 5
    if (Add-WindowsSkinHook -Config $cfg -EventName "PostToolUse" -Entry $toolEntry -Ps1Fragment "skins/engine/skin-tool-hook.ps1" -ShFragment "skins/engine/skin-tool-hook.sh") {
        $changed = $true
        Write-SkinLine "    Added PostToolUse hook: skin-tool-hook.ps1"
    } else {
        Write-SkinLine "    PostToolUse hook already present -- skipped"
    }

    if (Set-WindowsStatusLine $cfg (Get-StatusLineCommand $statusScript)) {
        $changed = $true
        Write-SkinLine "    Set statusLine: statusline.ps1"
    }

    if ($changed) {
        Write-Utf8NoBom -Path $settings -Text (ConvertTo-SettingsJson $cfg)
        Write-SkinLine "  settings.json updated successfully"
    } else {
        Write-SkinLine "  settings.json unchanged (all hooks already present)"
    }

    Write-SkinLine ""
    Write-SkinLine "Activating default skin (nebula)..."
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $launch = Get-PowerShellLaunch
    & $launch.Path -NoProfile -ExecutionPolicy Bypass -File $activateScript "nebula"
    $ErrorActionPreference = $savedPreference

    Write-SkinLine ""
    Write-SkinLine "Done! Restart Claude Code and run: /skin nebula"
    Write-SkinLine ""
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        Invoke-ClaudeSkinsInstall
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 1
    }
}
