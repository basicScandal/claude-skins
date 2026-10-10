# Author: Jonathan Marien (jondmarien)
# Claude Skins - /skin command handler.
# Reads a Claude Code prompt JSON object on stdin.
# Exit 2 tells Claude Code not to also send the /skin prompt to the model
# when this script is wired as a UserPromptSubmit hook.

param()

. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "parse-yaml.ps1")

function Invoke-SiblingEngine {
    param(
        [string]$FileName,
        [string[]]$ScriptArguments
    )
    $exe = ""
    try {
        $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    } catch {
        $exe = ""
    }
    if ([string]::IsNullOrWhiteSpace($exe)) {
        $exe = (Get-PowerShellLaunch).Path
    }
    $path = Join-Path $PSScriptRoot $FileName
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $path)
    if ($ScriptArguments -and $ScriptArguments.Length -gt 0) {
        $argList += $ScriptArguments
    }
    # Out-Host so the child banner/errors reach stdout instead of the function return value.
    & $exe @argList | Out-Host
    return $LASTEXITCODE
}

function Set-DefaultSkinConfig {
    param(
        [string]$EngineDir,
        [string]$Name
    )
    $config = Join-Path $EngineDir "config.yaml"
    if (-not (Test-Path -LiteralPath $config)) {
        Write-Utf8NoBom -Path $config -Text ("default_skin: " + $Name + "`n")
        return
    }
    $found = $false
    $sb = New-Object System.Text.StringBuilder
    foreach ($line in (Read-Utf8Lines $config)) {
        if ($line -cmatch "^default_skin:") {
            [void]$sb.Append("default_skin: ").Append($Name).Append("`n")
            $found = $true
        } else {
            [void]$sb.Append($line).Append("`n")
        }
    }
    if (-not $found) {
        [void]$sb.Append("default_skin: ").Append($Name).Append("`n")
    }
    Write-Utf8NoBom -Path $config -Text $sb.ToString()
}

function Invoke-SkinCommand {
    Initialize-SkinEncoding
    $payload = $null
    try {
        $payload = ConvertFrom-StdinJson
    } catch {
        return 0
    }
    $message = [string](Get-NoteProperty $payload @("prompt") "")
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = [string](Get-NoteProperty $payload @("message") "")
    }
    if ($message -cnotmatch "^/skin") {
        return 0
    }

    $skinArgs = $message.Substring(5).Trim()
    $engineDir = Get-EngineDir
    $skinsDir = Get-SkinsDir

    if ([string]::IsNullOrWhiteSpace($skinArgs)) {
        $current = Read-CurrentSkinName $engineDir
        Write-SkinLine "Available skins:"
        if (Test-Path -LiteralPath $skinsDir) {
            $files = @(Get-ChildItem -LiteralPath $skinsDir -Filter "*.yaml" -File -ErrorAction SilentlyContinue | Sort-Object Name)
            $arrow = [string][char]0x2192
            $dash = [string][char]0x2014
            foreach ($file in $files) {
                $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                if ($name -ceq "default") {
                    continue
                }
                $desc = Get-YamlValue $file.FullName "description"
                if ($name -ceq $current) {
                    Write-SkinLine ("  " + $arrow + " " + $name + " " + $dash + " " + $desc)
                } else {
                    Write-SkinLine ("    " + $name + " " + $dash + " " + $desc)
                }
            }
        }
        return 2
    }

    if ($skinArgs -ceq "reset") {
        [void](Invoke-SiblingEngine "deactivate.ps1" @())
        Write-SkinLine "Skin deactivated. Terminal restored."
        return 2
    }

    if ($skinArgs -ceq "default") {
        $current = Read-CurrentSkinName $engineDir
        Set-DefaultSkinConfig $engineDir $current
        Write-SkinLine ("Default skin set to: " + $current)
        return 2
    }

    [void](Invoke-SiblingEngine "activate.ps1" @($skinArgs))
    return 2
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        $code = Invoke-SkinCommand
        exit $code
    } catch {
        exit 0
    }
}
