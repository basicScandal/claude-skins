# Author: Jonathan Marien (jondmarien)
# Claude Skins - activate a skin.
# Usage: pwsh -NoProfile -ExecutionPolicy Bypass -File activate.ps1 <skin-name>
# Called by the SessionStart hook or /skin. No skin name reads engine/config.yaml.

param(
    [Parameter(Position = 0)]
    [string]$SkinName = ""
)

. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "parse-yaml.ps1")

function Invoke-ActivateSkin {
    param([string]$RequestedName)

    Initialize-SkinEncoding
    $skinsDir = Get-SkinsDir
    $engineDir = Get-EngineDir
    $skinName = $RequestedName

    if ([string]::IsNullOrWhiteSpace($skinName)) {
        $config = Join-Path $engineDir "config.yaml"
        if (Test-Path -LiteralPath $config) {
            $skinName = Get-YamlValue $config "default_skin"
        }
        if ([string]::IsNullOrWhiteSpace($skinName)) {
            $skinName = "default"
        }
    }

    if ($skinName -ceq "default") {
        return 0
    }

    if (-not (Test-SkinFileName $skinName)) {
        Write-SkinLine "Skin not found: $skinName"
        Write-AvailableSkins $skinsDir
        return 1
    }

    $skinFile = Join-Path $skinsDir ($skinName + ".yaml")
    $defaultFile = Join-Path $skinsDir "default.yaml"
    if (-not (Test-Path -LiteralPath $skinFile)) {
        Write-SkinLine "Skin not found: $skinName"
        Write-AvailableSkins $skinsDir
        return 1
    }

    Write-Utf8NoBom -Path (Get-SkinTempFile "claude-skin-restore") -Text "reset`n"

    $esc = [string][char]27
    $bel = [string][char]7
    $bg = Get-YamlValueWithDefault $skinFile $defaultFile "terminal.background"
    $fg = Get-YamlValueWithDefault $skinFile $defaultFile "terminal.foreground"
    $cursor = Get-YamlValueWithDefault $skinFile $defaultFile "terminal.cursor"
    $osc = New-Object System.Text.StringBuilder
    if (-not [string]::IsNullOrEmpty($bg)) {
        [void]$osc.Append($esc).Append("]11;").Append($bg).Append($bel)
    }
    if (-not [string]::IsNullOrEmpty($fg)) {
        [void]$osc.Append($esc).Append("]10;").Append($fg).Append($bel)
    }
    if (-not [string]::IsNullOrEmpty($cursor)) {
        [void]$osc.Append($esc).Append("]12;").Append($cursor).Append($bel)
    }

    $palette = @("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")
    for ($i = 0; $i -lt $palette.Length; $i++) {
        $color = Get-YamlValue $skinFile ("terminal.palette." + $palette[$i])
        if (-not [string]::IsNullOrEmpty($color)) {
            [void]$osc.Append($esc).Append("]4;").Append($i).Append(";").Append($color).Append($bel)
        }
    }
    $safeTitle = $skinName.Replace($bel, "").Replace($esc, "")
    $diamond = [string][char]0x25C6
    [void]$osc.Append($esc).Append("]0;Claude ").Append($diamond).Append(" ").Append($safeTitle).Append($bel)
    if ($osc.Length -gt 0) {
        [void](Write-TerminalRaw $osc.ToString())
    }

    Write-CurrentSkinName $engineDir $skinName
    Install-SkinPersonality $skinName

    # Bash captures block scalars with $(...), which strips trailing newlines,
    # then echo adds exactly one. Match that here.
    $banner = (Get-YamlBlockWithDefault $skinFile $defaultFile "branding.banner").TrimEnd("`r", "`n")
    $hero = (Get-YamlBlockWithDefault $skinFile $defaultFile "branding.hero").TrimEnd("`r", "`n")
    $welcome = Get-YamlValueWithDefault $skinFile $defaultFile "branding.welcome"

    Write-SkinLine ""
    if (-not [string]::IsNullOrEmpty($hero)) {
        Write-SkinLine (Expand-AnsiEscapes $hero)
        Write-SkinLine ""
    }
    if (-not [string]::IsNullOrEmpty($banner)) {
        Write-SkinLine (Expand-AnsiEscapes $banner)
        Write-SkinLine ""
    }
    if (-not [string]::IsNullOrEmpty($welcome)) {
        Write-SkinLine ($esc + "[2m" + (Expand-AnsiEscapes $welcome) + $esc + "[0m")
    }
    Write-SkinLine ""
    return 0
}

function Write-AvailableSkins {
    param([string]$SkinsDir)
    Write-SkinLine "Available skins:"
    if (-not (Test-Path -LiteralPath $SkinsDir)) {
        return
    }
    $files = @(Get-ChildItem -LiteralPath $SkinsDir -Filter "*.yaml" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($file in $files) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($name -ceq "default") {
            continue
        }
        Write-SkinLine $name
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $code = Invoke-ActivateSkin $SkinName
    exit $code
}
