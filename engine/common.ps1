# Author: Jonathan Marien (jondmarien)
# Shared helpers for the PowerShell engine.
# Dot-source this file; it has no side effects beyond function definitions.
# Targets Windows PowerShell 5.1 and PowerShell 7+.

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Get-ClaudeUserProfile {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }
    return [Environment]::GetFolderPath("UserProfile")
}

function Get-ClaudeDir {
    return (Join-Path (Get-ClaudeUserProfile) ".claude")
}

function Get-SkinsDir {
    return (Join-Path (Get-ClaudeDir) "skins")
}

function Get-EngineDir {
    return (Join-Path (Get-SkinsDir) "engine")
}

function Get-SkinTempFile {
    param([string]$Name)
    $root = [System.IO.Path]::GetTempPath()
    return (Join-Path $root $Name)
}

function Initialize-SkinEncoding {
    try { [Console]::InputEncoding = $script:Utf8NoBom } catch { $null = $_ }
    try { [Console]::OutputEncoding = $script:Utf8NoBom } catch { $null = $_ }
    $global:OutputEncoding = $script:Utf8NoBom
}

function Read-Utf8Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
}

function Read-Utf8Lines {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return ,@()
    }
    $text = Read-Utf8Text $Path
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($text.Length -eq 0) {
        return ,@()
    }
    $lines = $text.Split([char]10)
    if ($lines.Length -gt 0 -and $lines[$lines.Length - 1].Length -eq 0 -and $text.EndsWith("`n")) {
        if ($lines.Length -eq 1) {
            return ,@()
        }
        $trimmed = New-Object string[] ($lines.Length - 1)
        [Array]::Copy($lines, $trimmed, $lines.Length - 1)
        return ,$trimmed
    }
    return ,$lines
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Write-SkinLine {
    param([string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Read-StdinText {
    $stream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stream, $script:Utf8NoBom, $false, 1024, $true)
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
}

function ConvertFrom-StdinJson {
    $raw = Read-StdinText
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return ($raw | ConvertFrom-Json)
}

function Get-NoteProperty {
    param(
        $Object,
        [string[]]$Path,
        $Default = $null
    )
    $current = $Object
    foreach ($name in $Path) {
        if ($null -eq $current) {
            return $Default
        }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($name)) {
                return $Default
            }
            $current = $current[$name]
            continue
        }
        $prop = $current.PSObject.Properties[$name]
        if ($null -eq $prop) {
            return $Default
        }
        $current = $prop.Value
    }
    if ($null -eq $current) {
        return $Default
    }
    return $current
}

function Expand-AnsiEscapes {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) {
        return ""
    }
    $esc = [string][char]27
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $Text.Length) {
        if ($Text[$i] -eq "\" -and ($i + 1) -lt $Text.Length) {
            $rest = $Text.Substring($i)
            if ($rest.StartsWith("\033")) {
                [void]$sb.Append($esc)
                $i += 4
                continue
            }
            if ($rest.StartsWith("\e")) {
                [void]$sb.Append($esc)
                $i += 2
                continue
            }
            if ($rest.StartsWith("\\")) {
                [void]$sb.Append("\")
                $i += 2
                continue
            }
            if ($rest.StartsWith("\n")) {
                [void]$sb.Append("`n")
                $i += 2
                continue
            }
        }
        [void]$sb.Append($Text[$i])
        $i++
    }
    return $sb.ToString()
}

function Write-TerminalRaw {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) {
        return $false
    }
    $bytes = $script:Utf8NoBom.GetBytes($Text)
    $targets = New-Object System.Collections.Generic.List[string]
    if ($env:OS -eq "Windows_NT") {
        $targets.Add("CONOUT$")
    }
    $targets.Add("/dev/tty")
    foreach ($target in $targets) {
        $stream = $null
        try {
            $stream = New-Object System.IO.FileStream(
                $target,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::ReadWrite
            )
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            return $true
        } catch {
            $null = $_
        } finally {
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
    return $false
}

function Get-PowerShellLaunch {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $name = "powershell"
    if ($cmd) {
        $name = "pwsh"
    } else {
        $cmd = Get-Command powershell -ErrorAction SilentlyContinue
    }
    $path = $name
    if ($cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        $path = ($cmd.Source -replace "\\", "/")
    }
    return [pscustomobject]@{
        Name = $name
        Path = $path
    }
}

function Get-StatusLineCommand {
    param([string]$ScriptPath)
    $fwd = ($ScriptPath -replace "\\", "/")
    if ($fwd.IndexOf(" ") -lt 0) {
        # run-engine.cmd picks pwsh, then Windows PowerShell 5.1, at every run.
        # A bare .cmd path runs from both Git Bash and PowerShell.
        $launcher = (Join-Path (Split-Path -Parent $ScriptPath) "run-engine.cmd") -replace "\\", "/"
        return ($launcher + " " + (Split-Path -Leaf $ScriptPath))
    }
    # shortcut: a quoted .cmd path needs "&" in PowerShell but not in bash, so with a
    # space in the path use Windows PowerShell 5.1, which ships with every Windows.
    return ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + $fwd + '"')
}

function New-EngineHookEntry {
    param(
        [string]$ScriptPath,
        [string]$Matcher = "",
        [int]$Timeout = 0
    )
    # Exec form through run-engine.cmd: pwsh, then Windows PowerShell 5.1,
    # resolved when the hook runs rather than at install time.
    $cmdExe = $env:ComSpec
    if ([string]::IsNullOrWhiteSpace($cmdExe)) {
        $cmdExe = "cmd.exe"
    }
    $launcher = Join-Path (Split-Path -Parent $ScriptPath) "run-engine.cmd"
    $hook = [ordered]@{
        type    = "command"
        command = $cmdExe
        args    = [object[]]@(
            "/d",
            "/c",
            $launcher,
            (Split-Path -Leaf $ScriptPath)
        )
    }
    if ($Timeout -gt 0) {
        $hook["timeout"] = [int]$Timeout
    }
    $entry = [ordered]@{}
    if (-not [string]::IsNullOrEmpty($Matcher)) {
        $entry["matcher"] = $Matcher
    }
    $entry["hooks"] = [object[]]@($hook)
    return $entry
}

function Get-SkinHookFragments {
    return @(
        "skins/engine/activate.sh",
        "skins/engine/deactivate.sh",
        "skins/engine/skin-tool-hook.sh",
        "skins/engine/activate.ps1",
        "skins/engine/deactivate.ps1",
        "skins/engine/skin-tool-hook.ps1",
        "skins/engine/run-engine.cmd"
    )
}

function Get-SkinStatusFragments {
    return @(
        "skins/engine/statusline.sh",
        "skins/engine/statusline.ps1",
        "skins/engine/run-engine.cmd"
    )
}

function Get-HookSearchText {
    param($Hook)
    if ($null -eq $Hook) {
        return ""
    }
    $parts = New-Object System.Collections.Generic.List[string]
    if ($Hook -is [System.Collections.IDictionary]) {
        if ($Hook.Contains("command") -and $null -ne $Hook["command"]) {
            $parts.Add([string]$Hook["command"])
        }
        if ($Hook.Contains("args") -and $null -ne $Hook["args"]) {
            foreach ($arg in @($Hook["args"])) {
                if ($null -ne $arg) {
                    $parts.Add([string]$arg)
                }
            }
        }
    } else {
        $commandProp = $Hook.PSObject.Properties["command"]
        if ($commandProp -and $null -ne $commandProp.Value) {
            $parts.Add([string]$commandProp.Value)
        }
        $argsProp = $Hook.PSObject.Properties["args"]
        if ($argsProp -and $null -ne $argsProp.Value) {
            foreach ($arg in @($argsProp.Value)) {
                if ($null -ne $arg) {
                    $parts.Add([string]$arg)
                }
            }
        }
    }
    return (($parts -join " ") -replace "\\", "/")
}

function Test-TextHasFragment {
    param(
        [string]$Text,
        [string[]]$Fragments
    )
    if ([string]::IsNullOrEmpty($Text)) {
        return $false
    }
    $norm = $Text -replace "\\", "/"
    foreach ($frag in $Fragments) {
        if ($norm.IndexOf($frag, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

function ConvertFrom-JsonData {
    param($Value)
    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [string] -or $Value -is [bool] -or $Value -is [ValueType]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($Value.Keys)) {
            $ordered[[string]$key] = ConvertFrom-JsonData $Value[$key]
        }
        return $ordered
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            $list.Add((ConvertFrom-JsonData $item))
        }
        return ,$list.ToArray()
    }
    if ($Value -is [pscustomobject]) {
        $ordered = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) {
            $ordered[$prop.Name] = ConvertFrom-JsonData $prop.Value
        }
        return $ordered
    }
    return $Value
}

function ConvertTo-JsonStringLiteral {
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    if ($null -eq $Text) {
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($code -eq 34) {
            [void]$sb.Append('\"')
        } elseif ($code -eq 92) {
            [void]$sb.Append('\\')
        } elseif ($code -eq 8) {
            [void]$sb.Append('\b')
        } elseif ($code -eq 12) {
            [void]$sb.Append('\f')
        } elseif ($code -eq 10) {
            [void]$sb.Append('\n')
        } elseif ($code -eq 13) {
            [void]$sb.Append('\r')
        } elseif ($code -eq 9) {
            [void]$sb.Append('\t')
        } elseif ($code -lt 32) {
            [void]$sb.Append('\u')
            [void]$sb.Append($code.ToString("x4"))
        } else {
            [void]$sb.Append($ch)
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function ConvertTo-PrettyJson {
    param(
        $Value,
        [int]$Indent = 0
    )
    $pad = "  " * $Indent
    $padIn = "  " * ($Indent + 1)
    if ($null -eq $Value) {
        return "null"
    }
    if ($Value -is [string]) {
        return (ConvertTo-JsonStringLiteral $Value)
    }
    if ($Value -is [bool]) {
        if ($Value) { return "true" }
        return "false"
    }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int] -or $Value -is [int64]) {
        return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value.GetType().FullName -ceq "System.Numerics.BigInteger") {
        return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [datetime]) {
        # PS 7.0-7.4 fallback: no -DateKind, so write the round-trip ISO form.
        return (ConvertTo-JsonStringLiteral $Value.ToString("o", [Globalization.CultureInfo]::InvariantCulture))
    }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return $Value.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) {
            return "{}"
        }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($key in $keys) {
            $child = ConvertTo-PrettyJson $Value[$key] ($Indent + 1)
            $lines.Add($padIn + (ConvertTo-JsonStringLiteral ([string]$key)) + ": " + $child)
        }
        return ("{`n" + ($lines -join ",`n") + "`n" + $pad + "}")
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) {
            return "[]"
        }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($item in $items) {
            $lines.Add($padIn + (ConvertTo-PrettyJson $item ($Indent + 1)))
        }
        return ("[`n" + ($lines -join ",`n") + "`n" + $pad + "]")
    }
    if ($Value -is [pscustomobject]) {
        $ordered = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) {
            $ordered[$prop.Name] = $prop.Value
        }
        return (ConvertTo-PrettyJson $ordered $Indent)
    }
    return (ConvertTo-JsonStringLiteral ([string]$Value))
}

function ConvertTo-SettingsJson {
    param($Value)
    $json = ConvertTo-PrettyJson $Value 0
    if (-not $json.EndsWith("`n")) {
        $json = $json + "`n"
    }
    return $json
}

function Read-SettingsObject {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{}
    }
    $raw = Read-Utf8Text $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{}
    }
    # PS 7 turns ISO-8601 strings into DateTime; keep them as strings on 7.5+.
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) {
        $parsed = $raw | ConvertFrom-Json -DateKind String
    } else {
        $parsed = $raw | ConvertFrom-Json
    }
    $data = ConvertFrom-JsonData $parsed
    if ($data -is [System.Collections.IDictionary]) {
        return $data
    }
    return [ordered]@{}
}

function Read-CurrentSkinName {
    param([string]$EngineDir)
    $path = Join-Path $EngineDir "current"
    if (-not (Test-Path -LiteralPath $path)) {
        return "default"
    }
    $text = (Read-Utf8Text $path).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "default"
    }
    return $text
}

function Write-CurrentSkinName {
    param(
        [string]$EngineDir,
        [string]$Name
    )
    Write-Utf8NoBom -Path (Join-Path $EngineDir "current") -Text ($Name + "`n")
}

function Test-SkinFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }
    return $Name -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

function Remove-SkinPersonalities {
    $outDir = Join-Path (Get-ClaudeDir) "output-styles"
    if (Test-Path -LiteralPath $outDir) {
        $items = @(Get-ChildItem -LiteralPath $outDir -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "skin-*.md" })
        foreach ($item in $items) {
            $isLink = $false
            if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
                $isLink = $true
            }
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                $isLink = $true
            }
            if ($isLink) {
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    $manifest = Join-Path (Get-EngineDir) "personality-manifest.txt"
    if (Test-Path -LiteralPath $manifest) {
        foreach ($line in (Read-Utf8Lines $manifest)) {
            $dest = $line.Trim()
            if (-not [string]::IsNullOrWhiteSpace($dest) -and (Test-Path -LiteralPath $dest)) {
                Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue
    }
}

function Install-SkinPersonality {
    param([string]$SkinName)
    Remove-SkinPersonalities
    $source = Join-Path (Join-Path (Get-SkinsDir) "personalities") ($SkinName + ".md")
    if (-not (Test-Path -LiteralPath $source)) {
        return
    }
    $outDir = Join-Path (Get-ClaudeDir) "output-styles"
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    $dest = Join-Path $outDir ("skin-" + $SkinName + ".md")
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    }
    $linked = $false
    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $source -ErrorAction Stop | Out-Null
        $linked = $true
    } catch {
        $null = $_
    }
    if (-not $linked) {
        Copy-Item -LiteralPath $source -Destination $dest -Force
    }
    Write-Utf8NoBom -Path (Join-Path (Get-EngineDir) "personality-manifest.txt") -Text ($dest + "`n")
}

function Get-FileAgeSeconds {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return 999999
    }
    $item = Get-Item -LiteralPath $Path
    return ((Get-Date).ToUniversalTime() - $item.LastWriteTimeUtc).TotalSeconds
}
