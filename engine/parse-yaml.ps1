# Author: Jonathan Marien (jondmarien)
# Claude Skins - PowerShell YAML parser.
# Handles the same subset as engine/parse-yaml.sh (see SCHEMA.md):
#   - Top-level scalars
#   - One and two levels of nesting
#   - Block scalars (| | - |+)
#   - Inline maps: { field: "value", icon: "x" }
# No external modules. Windows PowerShell 5.1 and PowerShell 7+.

if (-not (Get-Command Read-Utf8Lines -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "common.ps1")
}

function Get-YamlIndentLength {
    param([string]$Line)
    $indent = 0
    while ($indent -lt $Line.Length -and $Line[$indent] -eq " ") {
        $indent++
    }
    return $indent
}

function Test-YamlBlockIndicator {
    param([string]$Value)
    if ($null -eq $Value) {
        return $false
    }
    $trimmed = $Value.Trim()
    return ($trimmed -ceq "|" -or $trimmed -ceq "|-" -or $trimmed -ceq "|+")
}

function Remove-YamlInlineComment {
    param([string]$Value)
    if ($null -eq $Value) {
        return ""
    }
    $trimmed = $Value.TrimStart()
    if ($trimmed.StartsWith('"') -or $trimmed.StartsWith("'")) {
        return $Value.Trim()
    }
    $hash = $Value.IndexOf("#")
    if ($hash -ge 0) {
        $Value = $Value.Substring(0, $hash)
    }
    return $Value.Trim()
}

function Get-YamlPair {
    param([string]$Stripped)
    if ([string]::IsNullOrEmpty($Stripped)) {
        return $null
    }
    $match = [regex]::Match($Stripped, '^([^:]+):\s*(.*)$')
    if (-not $match.Success) {
        return $null
    }
    return [pscustomobject]@{
        Key   = $match.Groups[1].Value.TrimEnd()
        Value = $match.Groups[2].Value
    }
}

function ConvertFrom-YamlScalar {
    param([string]$Value)
    if ($null -eq $Value) {
        return ""
    }
    $text = $Value.Trim()
    if ($text.Length -ge 2) {
        $open = $text[0]
        $close = $text[$text.Length - 1]
        if (($open -eq '"' -and $close -eq '"') -or ($open -eq "'" -and $close -eq "'")) {
            return $text.Substring(1, $text.Length - 2)
        }
    }
    return $text
}

function Get-YamlValue {
    param(
        [string]$File,
        [string]$DotKey
    )
    if ([string]::IsNullOrWhiteSpace($File) -or -not (Test-Path -LiteralPath $File)) {
        return ""
    }
    if ([string]::IsNullOrWhiteSpace($DotKey)) {
        return ""
    }

    $parts = $DotKey.Split(".")
    $depth = $parts.Length
    $p0 = $parts[0]
    $p1 = ""
    $p2 = ""
    if ($depth -ge 2) { $p1 = $parts[1] }
    if ($depth -ge 3) { $p2 = $parts[2] }

    $inSection = $false
    $inSubsection = $false
    $skipping = $false
    $skipIndent = -1

    foreach ($rawLine in (Read-Utf8Lines $File)) {
        $line = $rawLine.TrimEnd("`r")
        if ([regex]::IsMatch($line, '^\s*#')) {
            continue
        }
        $indent = Get-YamlIndentLength $line
        $stripped = ""
        if ($indent -lt $line.Length) {
            $stripped = $line.Substring($indent)
        }

        if ($skipping) {
            if ($stripped.Length -eq 0 -or $indent -gt $skipIndent) {
                continue
            }
            $skipping = $false
        }

        $pair = Get-YamlPair $stripped
        $isPair = $null -ne $pair
        $key = ""
        $val = ""
        if ($isPair) {
            $key = $pair.Key
            $val = $pair.Value
        }

        if ($depth -eq 1) {
            if ($isPair -and $indent -eq 0 -and $key -ceq $p0) {
                if (Test-YamlBlockIndicator $val) { return "" }
                return (ConvertFrom-YamlScalar (Remove-YamlInlineComment $val))
            }
            continue
        }

        if ($depth -eq 2) {
            if ($indent -eq 0 -and $isPair) {
                $inSection = ($key -ceq $p0)
                continue
            }
            if ($inSection -and $indent -gt 0 -and $isPair -and $key -ceq $p1) {
                if (Test-YamlBlockIndicator $val) { return "" }
                return (ConvertFrom-YamlScalar (Remove-YamlInlineComment $val))
            }
            if ($inSection -and $isPair -and (Test-YamlBlockIndicator $val)) {
                $skipping = $true
                $skipIndent = $indent
            }
            continue
        }

        if ($depth -eq 3) {
            if ($indent -eq 0 -and $isPair) {
                $inSection = ($key -ceq $p0)
                $inSubsection = $false
                continue
            }
            if ($inSection -and $indent -eq 2 -and $isPair) {
                $inSubsection = ($key -ceq $p1)
                if (Test-YamlBlockIndicator $val) {
                    $skipping = $true
                    $skipIndent = $indent
                }
                continue
            }
            if ($inSubsection -and $indent -ge 4 -and $isPair -and $key -ceq $p2) {
                if (Test-YamlBlockIndicator $val) { return "" }
                return (ConvertFrom-YamlScalar (Remove-YamlInlineComment $val))
            }
        }
    }
    return ""
}

function Get-YamlBlock {
    param(
        [string]$File,
        [string]$DotKey
    )
    if ([string]::IsNullOrWhiteSpace($File) -or -not (Test-Path -LiteralPath $File)) {
        return ""
    }

    $parts = $DotKey.Split(".")
    $depth = $parts.Length
    $p0 = $parts[0]
    $p1 = ""
    if ($depth -ge 2) { $p1 = $parts[1] }

    $inSection = $false
    $capturing = $false
    $baseIndent = -1
    $result = ""

    foreach ($rawLine in (Read-Utf8Lines $File)) {
        $line = $rawLine.TrimEnd("`r")
        if ([regex]::IsMatch($line, '^\s*#')) {
            continue
        }
        $indent = Get-YamlIndentLength $line
        $stripped = ""
        if ($indent -lt $line.Length) {
            $stripped = $line.Substring($indent)
        }

        if ($capturing) {
            if ([regex]::IsMatch($line, '^\s*$')) {
                $result = $result + "`n"
                continue
            }
            if ($baseIndent -lt 0) {
                $baseIndent = $indent
            }
            if ($indent -lt $baseIndent) {
                break
            }
            $content = ""
            if ($line.Length -gt $baseIndent) {
                $content = $line.Substring($baseIndent)
            }
            if ($result.Length -gt 0) {
                $result = $result + "`n" + $content
            } else {
                $result = $content
            }
            continue
        }

        $pair = Get-YamlPair $stripped
        $isPair = $null -ne $pair
        $key = ""
        $val = ""
        if ($isPair) {
            $key = $pair.Key
            $val = $pair.Value
        }

        if ($depth -eq 1 -and $indent -eq 0 -and $isPair -and $key -ceq $p0) {
            if (Test-YamlBlockIndicator $val) {
                $capturing = $true
                $baseIndent = -1
                $result = ""
            }
            continue
        }

        if ($depth -eq 2) {
            if ($indent -eq 0 -and $isPair) {
                $inSection = ($key -ceq $p0)
                continue
            }
            if ($inSection -and $indent -gt 0 -and $isPair -and $key -ceq $p1) {
                if (Test-YamlBlockIndicator $val) {
                    $capturing = $true
                    $baseIndent = -1
                    $result = ""
                }
            }
        }
    }
    return $result
}

function Get-YamlInlineField {
    param(
        [string]$Map,
        [string]$Field
    )
    if ([string]::IsNullOrWhiteSpace($Map)) {
        return ""
    }
    $inner = $Map.Trim()
    if ($inner.StartsWith("{")) {
        $inner = $inner.Substring(1)
    }
    if ($inner.EndsWith("}")) {
        $inner = $inner.Substring(0, $inner.Length - 1)
    }
    foreach ($part in $inner.Split(",")) {
        $piece = $part.Trim()
        $pair = Get-YamlPair $piece
        if ($null -ne $pair) {
            $key = $pair.Key
            $val = $pair.Value
            if ($key -ceq $Field) {
                return (ConvertFrom-YamlScalar $val)
            }
        }
    }
    return ""
}

function Get-YamlEventField {
    param(
        [string]$File,
        [string]$EventName,
        [string]$FieldName
    )
    if ([string]::IsNullOrWhiteSpace($File) -or -not (Test-Path -LiteralPath $File)) {
        return ""
    }
    $inTools = $false
    $inEvents = $false
    foreach ($rawLine in (Read-Utf8Lines $File)) {
        $line = $rawLine.TrimEnd("`r")
        if ([regex]::IsMatch($line, '^\s*#')) {
            continue
        }
        $indent = Get-YamlIndentLength $line
        $stripped = ""
        if ($indent -lt $line.Length) {
            $stripped = $line.Substring($indent)
        }
        if ($indent -eq 0) {
            if ([regex]::IsMatch($stripped, '^tools:\s*')) {
                $inTools = $true
                $inEvents = $false
            } else {
                $inTools = $false
                $inEvents = $false
            }
            continue
        }
        if ($inTools -and $indent -eq 2) {
            if ([regex]::IsMatch($stripped, '^events:\s*')) {
                $inEvents = $true
            } else {
                $inEvents = $false
            }
            continue
        }
        $eventPair = Get-YamlPair $stripped
        if ($inEvents -and $indent -ge 4 -and $null -ne $eventPair) {
            $key = $eventPair.Key
            $val = $eventPair.Value
            if ($key -ceq $EventName) {
                return (Get-YamlInlineField $val $FieldName)
            }
        }
    }
    return ""
}

function Get-YamlValueWithDefault {
    param(
        [string]$SkinFile,
        [string]$DefaultFile,
        [string]$DotKey
    )
    $val = Get-YamlValue $SkinFile $DotKey
    if ([string]::IsNullOrEmpty($val) -and (Test-Path -LiteralPath $DefaultFile)) {
        $val = Get-YamlValue $DefaultFile $DotKey
    }
    if ($null -eq $val) { return "" }
    return [string]$val
}

function Get-YamlBlockWithDefault {
    param(
        [string]$SkinFile,
        [string]$DefaultFile,
        [string]$DotKey
    )
    $val = Get-YamlBlock $SkinFile $DotKey
    if ([string]::IsNullOrEmpty($val) -and (Test-Path -LiteralPath $DefaultFile)) {
        $val = Get-YamlBlock $DefaultFile $DotKey
    }
    if ($null -eq $val) { return "" }
    return [string]$val
}

function Get-YamlEventFieldWithDefault {
    param(
        [string]$SkinFile,
        [string]$DefaultFile,
        [string]$EventName,
        [string]$FieldName
    )
    $val = Get-YamlEventField -File $SkinFile -EventName $EventName -FieldName $FieldName
    if ([string]::IsNullOrEmpty($val) -and (Test-Path -LiteralPath $DefaultFile)) {
        $val = Get-YamlEventField -File $DefaultFile -EventName $EventName -FieldName $FieldName
    }
    if ($null -eq $val) { return "" }
    return [string]$val
}
