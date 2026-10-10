# Author: Jonathan Marien (jondmarien)
# Claude Skins - themed status line.
# Claude Code runs this with session JSON on stdin and prints the line it writes.
# https://code.claude.com/docs/en/statusline

. (Join-Path $PSScriptRoot "common.ps1")

function ConvertTo-AnsiFg {
    param([string]$Hex)
    $esc = [string][char]27
    $clean = ""
    if (-not [string]::IsNullOrWhiteSpace($Hex)) {
        $clean = $Hex.Trim().TrimStart("#")
    }
    if ($clean.Length -ne 6 -or $clean -notmatch '^[0-9A-Fa-f]{6}$') {
        return ($esc + "[38;2;255;191;0m")
    }
    $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    return ($esc + "[38;2;" + $r + ";" + $g + ";" + $b + "m")
}

function ConvertTo-CountText {
    param($Value)
    if ($null -eq $Value) {
        return "0"
    }
    $text = [string]$Value
    $number = 0.0
    $parsed = [double]::TryParse($text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)
    if (-not $parsed) {
        return $text
    }
    if ($number -eq [math]::Floor($number)) {
        return ([int64]$number).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    return $number.ToString("G", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-DirectoryLeaf {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq "~") {
        return "~"
    }
    $trimmed = $Path.TrimEnd("\", "/")
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $Path
    }
    $leaf = Split-Path -Leaf $trimmed
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        return $trimmed
    }
    return $leaf
}

function Get-StatusGitInfo {
    param([string]$Directory)
    $cache = Get-SkinTempFile "claude-statusline-git-cache"
    if ((Get-FileAgeSeconds $cache) -gt 5) {
        $branch = ""
        $dirty = $false
        if ((Get-Command git -ErrorAction SilentlyContinue) -and -not [string]::IsNullOrWhiteSpace($Directory) -and (Test-Path -LiteralPath $Directory)) {
            try {
                $branchText = & git -C $Directory branch --show-current 2>$null
                if ($branchText -is [System.Array]) {
                    $branch = [string]$branchText[0]
                } elseif ($null -ne $branchText) {
                    $branch = [string]$branchText
                }
                $branch = $branch.Trim()
                $porcelain = & git -C $Directory status --porcelain 2>$null | Select-Object -First 1
                if (-not [string]::IsNullOrWhiteSpace([string]$porcelain)) {
                    $dirty = $true
                }
            } catch {
                $branch = ""
                $dirty = $false
            }
        }
        $info = $branch
        if ($dirty) {
            $info = $branch + "*"
        }
        Write-Utf8NoBom -Path $cache -Text ($info + "`n")
        return $info
    }
    return (Read-Utf8Text $cache).TrimEnd("`r", "`n")
}

function Get-StatusSkinTheme {
    param([string]$SkinName)
    $theme = @{
        Accent   = "FFBF00"
        Dim      = "666666"
        BarFill  = "FFBF00"
        BarEmpty = "333333"
        Icon     = ">"
    }
    if ($SkinName -ceq "default") {
        return $theme
    }
    $skinFile = Join-Path (Get-SkinsDir) ($SkinName + ".yaml")
    if (-not (Test-Path -LiteralPath $skinFile)) {
        return $theme
    }
    $cache = Get-SkinTempFile ("claude-skin-colors-" + $SkinName)
    if ((Get-FileAgeSeconds $cache) -gt 60) {
        . (Join-Path $PSScriptRoot "parse-yaml.ps1")
        $accent = (Get-YamlValue $skinFile "statusline.accent") -replace "#", ""
        $dim = (Get-YamlValue $skinFile "statusline.dim") -replace "#", ""
        $fill = (Get-YamlValue $skinFile "statusline.bar_fill") -replace "#", ""
        $empty = (Get-YamlValue $skinFile "statusline.bar_empty") -replace "#", ""
        $icon = Get-YamlValue $skinFile "statusline.icon"
        $payload = $accent + "`n" + $dim + "`n" + $fill + "`n" + $empty + "`n" + $icon + "`n"
        Write-Utf8NoBom -Path $cache -Text $payload
    }
    if (Test-Path -LiteralPath $cache) {
        $lines = Read-Utf8Lines $cache
        if ($lines.Length -ge 1 -and -not [string]::IsNullOrWhiteSpace($lines[0])) { $theme.Accent = $lines[0].Trim() }
        if ($lines.Length -ge 2 -and -not [string]::IsNullOrWhiteSpace($lines[1])) { $theme.Dim = $lines[1].Trim() }
        if ($lines.Length -ge 3 -and -not [string]::IsNullOrWhiteSpace($lines[2])) { $theme.BarFill = $lines[2].Trim() }
        if ($lines.Length -ge 4 -and -not [string]::IsNullOrWhiteSpace($lines[3])) { $theme.BarEmpty = $lines[3].Trim() }
        if ($lines.Length -ge 5 -and $lines[4].Length -gt 0) { $theme.Icon = $lines[4] }
    }
    return $theme
}

function Write-SkinStatusLine {
    Initialize-SkinEncoding
    $payload = $null
    try {
        $payload = ConvertFrom-StdinJson
    } catch {
        $payload = $null
    }

    $model = "..."
    $dirPath = "~"
    # Bash uses "~" for the displayed folder and "." for git when current_dir is absent.
    $gitDir = "."
    $pct = 0
    $costNum = 0.0
    $added = "0"
    $removed = "0"
    if ($null -ne $payload) {
        $modelValue = Get-NoteProperty $payload @("model", "display_name") "..."
        if (-not [string]::IsNullOrWhiteSpace([string]$modelValue)) {
            $model = [string]$modelValue
        }
        $dirValue = Get-NoteProperty $payload @("workspace", "current_dir") $null
        if (-not [string]::IsNullOrWhiteSpace([string]$dirValue)) {
            $dirPath = [string]$dirValue
            $gitDir = $dirPath
        }
        $pctRaw = Get-NoteProperty $payload @("context_window", "used_percentage") 0
        $pctNumber = 0.0
        if ([double]::TryParse([string]$pctRaw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$pctNumber)) {
            if ($pctNumber -lt 0) { $pctNumber = 0 }
            $pct = [int][math]::Floor($pctNumber)
        }
        $costRaw = Get-NoteProperty $payload @("cost", "total_cost_usd") 0
        $parsedCost = 0.0
        if ([double]::TryParse([string]$costRaw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsedCost)) {
            $costNum = $parsedCost
        }
        $added = ConvertTo-CountText (Get-NoteProperty $payload @("cost", "total_lines_added") 0)
        $removed = ConvertTo-CountText (Get-NoteProperty $payload @("cost", "total_lines_removed") 0)
    }

    $dirName = Get-DirectoryLeaf $dirPath
    $gitInfo = Get-StatusGitInfo $gitDir
    $skinName = Read-CurrentSkinName (Get-EngineDir)
    $theme = Get-StatusSkinTheme $skinName

    $esc = [string][char]27
    $reset = $esc + "[0m"
    $cAccent = ConvertTo-AnsiFg $theme.Accent
    $cDim = ConvertTo-AnsiFg $theme.Dim
    $cFill = ConvertTo-AnsiFg $theme.BarFill
    $cEmpty = ConvertTo-AnsiFg $theme.BarEmpty

    $filled = [int][math]::Floor($pct / 10)
    if ($filled -lt 0) { $filled = 0 }
    $empty = 10 - $filled
    $bar = New-Object System.Text.StringBuilder
    $fillChar = [string][char]0x2593
    $emptyChar = [string][char]0x2591
    for ($i = 0; $i -lt $filled; $i++) {
        [void]$bar.Append($cFill).Append($fillChar)
    }
    for ($i = 0; $i -lt $empty; $i++) {
        [void]$bar.Append($cEmpty).Append($emptyChar)
    }

    if ($pct -ge 90) {
        $pctColor = $esc + "[31m"
    } elseif ($pct -ge 70) {
        $pctColor = $esc + "[33m"
    } else {
        $pctColor = $esc + "[32m"
    }
    $ctx = $bar.ToString() + " " + $pctColor + $pct + "%" + $reset
    $costFmt = "$" + $costNum.ToString("0.00", [Globalization.CultureInfo]::InvariantCulture)

    $gitPart = ""
    if (-not [string]::IsNullOrEmpty($gitInfo)) {
        $branchMark = [string][char]0x2387
        $gitPart = " " + $cDim + $branchMark + $reset + " " + $gitInfo + " " + $cDim + "|" + $reset
    }

    $linesPart = ""
    if ($added -cne "0" -or $removed -cne "0") {
        $linesPart = " " + $cDim + "|" + $reset + " " + $esc + "[32m+" + $added + $esc + "[0m " + $esc + "[31m-" + $removed + $esc + "[0m"
    }

    $skinLabel = ""
    if ($skinName -cne "default") {
        $skinLabel = $cAccent + $theme.Icon + $reset + " "
    }

    $line = $skinLabel + $cAccent + $model + $reset + " " + $cDim + "|" + $reset + " " + $dirName + " " + $cDim + "|" + $reset + $gitPart + " " + $ctx + " " + $cDim + "|" + $reset + " " + $costFmt + $linesPart
    Write-SkinLine $line
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        Write-SkinStatusLine
    } catch {
        Write-SkinLine "..."
    }
    exit 0
}
