# Author: Jonathan Marien (jondmarien)
# Claude Skins - deactivate and restore the terminal.
# Called by the SessionEnd hook or /skin reset.

. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "parse-yaml.ps1")

function Invoke-DeactivateSkin {
    Initialize-SkinEncoding
    $engineDir = Get-EngineDir
    $current = ""
    if (Test-Path -LiteralPath (Join-Path $engineDir "current")) {
        $current = Read-CurrentSkinName $engineDir
    }

    if (-not [string]::IsNullOrWhiteSpace($current) -and $current -cne "default") {
        $skinFile = Join-Path (Get-SkinsDir) ($current + ".yaml")
        if (Test-Path -LiteralPath $skinFile) {
            $goodbye = Get-YamlValue $skinFile "branding.goodbye"
            if (-not [string]::IsNullOrEmpty($goodbye)) {
                $esc = [string][char]27
                Write-SkinLine ($esc + "[2m" + (Expand-AnsiEscapes $goodbye) + $esc + "[0m")
            }
        }
    }

    $restore = Get-SkinTempFile "claude-skin-restore"
    if (Test-Path -LiteralPath $restore) {
        $esc = [string][char]27
        $bel = [string][char]7
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append($esc).Append("]110").Append($bel)
        [void]$sb.Append($esc).Append("]111").Append($bel)
        [void]$sb.Append($esc).Append("]112").Append($bel)
        for ($i = 0; $i -le 7; $i++) {
            [void]$sb.Append($esc).Append("]104;").Append($i).Append($bel)
        }
        [void]$sb.Append($esc).Append("]0;").Append($bel)
        $wrote = Write-TerminalRaw $sb.ToString()
        if ($wrote) {
            Remove-Item -LiteralPath $restore -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-SkinPersonalities
    if (Test-Path -LiteralPath $engineDir) {
        Write-CurrentSkinName $engineDir "default"
    }
    return 0
}

if ($MyInvocation.InvocationName -ne ".") {
    $code = Invoke-DeactivateSkin
    exit $code
}
