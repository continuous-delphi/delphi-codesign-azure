#requires -Version 5.1
# -----------------------------------------------------------------------------
# delphi-codesign-azure
#
# Authenticode code signing and verification via Azure Trusted Signing.
#
# Part of Continuous-Delphi: Focused on strengthening Delphi's continued success
# https://github.com/continuous-delphi
#
# Project repository:
# https://github.com/continuous-delphi/delphi-codesign-azure
#
# Also included in the Continuous-Delphi PowerShell CI module:
# https://github.com/continuous-delphi/delphi-powershell-ci
#
# Copyright (c) 2026 Darian Miller
# Licensed under the MIT License.
# https://opensource.org/licenses/MIT
# SPDX-License-Identifier: MIT
# -----------------------------------------------------------------------------

<#
.SYNOPSIS
Authenticode code signing and verification using Azure Trusted Signing.

.DESCRIPTION
Signs and verifies Authenticode signatures on executables and libraries
using signtool.exe and Azure Trusted Signing.

Exit codes:
  0  success
  1  signature invalid or file not signed (verify)
  2  partial failure (some files failed to sign)
  3  fatal error (prerequisites missing, file not found, etc.)

.EXAMPLE
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe

.EXAMPLE
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe,lib.bpl -Format text

.EXAMPLE
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -Format text

.EXAMPLE
pwsh -File source/delphi-codesign-azure.ps1 -Version -Format json
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Version')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
  Justification='Write-Host is intentional: standalone CLI tool streams status to the console host.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'OutputLevel',
  Justification='Consumed by Write-Detail/Write-Summary helper functions.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'PassThru',
  Justification='Template placeholder: consumed by tool-specific logic added during customization.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'OutputFile',
  Justification='Template placeholder: consumed by tool-specific logic added during customization.')]
param(
    [Parameter(ParameterSetName = 'Version', Mandatory)]
    [switch]$Version,

    [Parameter(ParameterSetName = 'Version')]
    [Parameter(ParameterSetName = 'Verify')]
    [Parameter(ParameterSetName = 'Sign')]
    [ValidateSet('object', 'text', 'json')]
    [string]$Format = 'object',

    [Parameter(ParameterSetName = 'Verify', Mandatory)]
    [switch]$Verify,

    [Parameter(ParameterSetName = 'Verify', Mandatory)]
    [string]$FilePath,

    [Parameter(ParameterSetName = 'Verify')]
    [Parameter(ParameterSetName = 'Sign')]
    [string]$SignToolPath,

    [Parameter(ParameterSetName = 'Sign', Mandatory)]
    [switch]$Sign,

    [Parameter(ParameterSetName = 'Sign', Mandatory)]
    [string[]]$Files,

    [Parameter(ParameterSetName = 'Sign')]
    [string]$DlibPath,

    [Parameter(ParameterSetName = 'Sign')]
    [string]$MetadataPath,

    [Parameter(ParameterSetName = 'Sign')]
    [string]$EnvFile,

    [Parameter(ParameterSetName = 'Main')]
    [string]$RootPath,

    [Parameter(ParameterSetName = 'Main')]
    [ValidateSet('detailed', 'summary', 'quiet')]
    [string]$OutputLevel = 'detailed',

    [Parameter(ParameterSetName = 'Main')]
    [switch]$Json,

    [Parameter(ParameterSetName = 'Main')]
    [switch]$PassThru,

    [Parameter(ParameterSetName = 'Main')]
    [switch]$Check,

    [Parameter(ParameterSetName = 'Main')]
    [switch]$ShowConfig,

    [Parameter(ParameterSetName = 'Main')]
    [string]$ConfigFile,

    [Parameter(ParameterSetName = 'Main')]
    [string]$OutputFile

    # -------------------------------------------------------------------------
    # Add tool-specific parameters here.
    # -------------------------------------------------------------------------
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Exit code constants
$ExitSuccess        = 0
$ExitDirty          = 1   # -Check found items needing attention / signature invalid
$ExitPartialFailure = 2   # some items failed
$ExitFatal          = 3   # engine not found, bad root, unhandled error

$script:ToolVersion = '0.1.3'

# =============================================================================
# Version info
# =============================================================================

if ($Version) {
    $info = @{
        ok      = $true
        command = 'version'
        tool    = @{
            name    = 'delphi-codesign-azure'
            version = $script:ToolVersion
        }
    }
    switch ($Format) {
        'json'   { Write-Output ($info | ConvertTo-Json -Depth 5 -Compress) }
        'text'   { Write-Output "delphi-codesign-azure $($script:ToolVersion)" }
        default  { Write-Output ([PSCustomObject]$info) }
    }
    exit $ExitSuccess
}

# =============================================================================
# Output helpers
# =============================================================================

$script:SuppressOutput = $Json.IsPresent

function Write-Detail([string]$Message) {
    if ($script:SuppressOutput) { return }
    if ($OutputLevel -eq 'detailed') {
        Write-Host $Message
    }
}

function Write-Summary([string]$Message) {
    if ($script:SuppressOutput) { return }
    if ($OutputLevel -in 'detailed', 'summary') {
        Write-Host $Message
    }
}

function Write-Section([string]$Message) {
    if ($script:SuppressOutput) { return }
    if ($OutputLevel -eq 'detailed') {
        Write-Host ""
        Write-Host $Message -ForegroundColor Cyan
    }
}

function Write-SummarySection([string]$Message) {
    if ($script:SuppressOutput) { return }
    if ($OutputLevel -in 'detailed', 'summary') {
        Write-Host ""
        Write-Host $Message -ForegroundColor Cyan
    }
}

# =============================================================================
# Utility helpers
# =============================================================================

function Format-Duration([double]$Milliseconds) {
    if ($Milliseconds -lt 1000) { return "$([math]::Round($Milliseconds, 0)) ms" }
    return "$([math]::Round($Milliseconds / 1000, 1)) s"
}

function Resolve-ToolRoot([string]$Path) {
    if ([string]::IsNullOrEmpty($Path)) {
        return (Get-Location).Path
    }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $resolved) {
        Write-Error "Root path does not exist: $Path" -ErrorAction Continue
        exit $ExitFatal
    }
    return $resolved.ProviderPath
}

function Test-SafeRoot([string]$Path) {
    $root = [System.IO.Path]::GetPathRoot($Path)
    if ($Path -eq $root) {
        Write-Error "Refusing to operate on the filesystem root: $Path" -ErrorAction Continue
        return $false
    }
    return $true
}

function Get-RelativePathCompat([string]$From, [string]$To) {
    $fromUri = [Uri]::new("$From/")
    $toUri   = [Uri]::new($To)
    $rel     = $fromUri.MakeRelativeUri($toUri).ToString()
    return [Uri]::UnescapeDataString($rel) -replace '/', [System.IO.Path]::DirectorySeparatorChar
}

# =============================================================================
# Configuration
# =============================================================================

function Get-ConfigValue([object]$Config, [string]$Key) {
    if ($null -eq $Config) { return $null }
    $props = $Config.PSObject.Properties
    if ($null -eq $props) { return $null }
    $match = $props.Match($Key)
    if ($match.Count -gt 0) {
        return $match[0].Value
    }
    return $null
}

function Read-ConfigFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-Warning "Failed to parse config file: $Path -- $_"
        return $null
    }
}

function Merge-ToolConfig([object]$Base, [object]$Layer) {
    if ($null -eq $Layer) { return $Base }
    if ($null -eq $Base)  { return $Layer }

    # Deep-copy base properties into a fresh object
    $merged = [PSCustomObject]@{}
    foreach ($p in $Base.PSObject.Properties) {
        $merged | Add-Member -MemberType NoteProperty -Name $p.Name -Value $p.Value
    }

    foreach ($prop in $Layer.PSObject.Properties) {
        $key   = $prop.Name
        $value = $prop.Value

        if ($value -is [System.Array]) {
            # Arrays: append + deduplicate
            $existing = Get-ConfigValue $merged $key
            if ($null -ne $existing -and $existing -is [System.Array]) {
                $combined = [System.Collections.Generic.List[string]]::new()
                $seen     = [System.Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::OrdinalIgnoreCase)
                foreach ($item in $existing) {
                    if ($seen.Add($item)) { $combined.Add($item) }
                }
                foreach ($item in $value) {
                    if ($seen.Add($item)) { $combined.Add($item) }
                }
                $merged | Add-Member -MemberType NoteProperty -Name $key -Value $combined.ToArray() -Force
            }
            else {
                $merged | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
            }
        }
        else {
            # Scalars: last writer wins
            $merged | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
        }
    }

    return $merged
}

function Resolve-EffectiveConfig([string]$Root, [string]$ExplicitConfigFile) {
    # Start with empty config
    $config = [PSCustomObject]@{}

    # Layer 1: $HOME/delphi-codesign-azure.json
    $homeDir = if ($env:DELPHI_CODESIGN_AZURE_HOME_OVERRIDE) {
        $env:DELPHI_CODESIGN_AZURE_HOME_OVERRIDE
    } else {
        $HOME
    }
    $homeConfig = Read-ConfigFile (Join-Path $homeDir 'delphi-codesign-azure.json')
    $config = Merge-ToolConfig $config $homeConfig

    # Layer 2: upward traversal (if searchParentFolders enabled)
    $searchParents = Get-ConfigValue $config 'searchParentFolders'
    # Check project-level config first to see if traversal is enabled
    $projectConfig = Read-ConfigFile (Join-Path $Root 'delphi-codesign-azure.json')
    $localConfig   = Read-ConfigFile (Join-Path $Root 'delphi-codesign-azure.local.json')
    if ($null -eq $searchParents) {
        $searchParents = Get-ConfigValue $projectConfig 'searchParentFolders'
    }
    if ($null -eq $searchParents) {
        $searchParents = Get-ConfigValue $localConfig 'searchParentFolders'
    }

    if ($searchParents -eq $true) {
        $parentConfigs = [System.Collections.Generic.List[object]]::new()
        $current = [System.IO.Directory]::GetParent($Root)
        while ($null -ne $current) {
            $parentFile = Join-Path $current.FullName 'delphi-codesign-azure.json'
            $parentCfg  = Read-ConfigFile $parentFile
            if ($null -ne $parentCfg) {
                $parentConfigs.Add($parentCfg)
                $stop = Get-ConfigValue $parentCfg 'searchParentFolders'
                if ($stop -eq $false) { break }
            }
            $current = $current.Parent
        }
        # Apply from outermost to innermost (innermost wins)
        $parentConfigs.Reverse()
        foreach ($pc in $parentConfigs) {
            $config = Merge-ToolConfig $config $pc
        }
    }

    # Layer 3: project-level config
    $config = Merge-ToolConfig $config $projectConfig

    # Layer 4: local override config
    $config = Merge-ToolConfig $config $localConfig

    # Layer 5: explicit -ConfigFile
    if (-not [string]::IsNullOrEmpty($ExplicitConfigFile)) {
        $explicitCfg = Read-ConfigFile $ExplicitConfigFile
        if ($null -eq $explicitCfg) {
            Write-Error "Config file not found or invalid: $ExplicitConfigFile" -ErrorAction Continue
            exit $ExitFatal
        }
        $config = Merge-ToolConfig $config $explicitCfg
    }

    return $config
}

# =============================================================================
# Verify command -- signtool discovery and invocation
# =============================================================================

function Find-SignTool([string]$ExplicitPath) {
    if (-not [string]::IsNullOrEmpty($ExplicitPath)) {
        if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
            return $ExplicitPath
        }
        $found = Get-Command $ExplicitPath -ErrorAction SilentlyContinue
        if ($null -ne $found) { return $found.Source }
        return $null
    }
    $sdkRoot = 'C:\Program Files (x86)\Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $sdkRoot)) { return $null }
    $found = Get-ChildItem -Path $sdkRoot -Filter 'signtool.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like '*\x64' } |
        Sort-Object { $_.DirectoryName } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    return $found
}

function Invoke-SignToolVerify([string]$SignToolExe, [string]$TargetFile) {
    $output = cmd.exe /c "`"$SignToolExe`" verify /pa /v `"$TargetFile`"" 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output   = ($output | Out-String).TrimEnd()
    }
}

# =============================================================================
# Sign command -- Azure Trusted Signing
# =============================================================================

function Import-EnvFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $eq = $line.IndexOf('=')
        if ($eq -gt 0) {
            $key = $line.Substring(0, $eq)
            $val = $line.Substring($eq + 1)
            if (-not [Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, $val, 'Process')
            }
        }
    }
}

function Find-Dlib([string]$ExplicitPath) {
    if (-not [string]::IsNullOrEmpty($ExplicitPath)) {
        if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) { return $ExplicitPath }
        return $null
    }
    $default = Join-Path $env:LOCALAPPDATA 'Microsoft\MicrosoftTrustedSigningClientTools\Azure.CodeSigning.Dlib.dll'
    if (Test-Path -LiteralPath $default -PathType Leaf) { return $default }
    return $null
}

function Invoke-SignToolSign([string]$SignToolExe, [string]$DlibDll, [string]$MetadataJson, [string]$TargetFile) {
    $output = cmd.exe /c "`"$SignToolExe`" sign /v /fd SHA256 /tr `"http://timestamp.acs.microsoft.com`" /td SHA256 /dlib `"$DlibDll`" /dmdf `"$MetadataJson`" `"$TargetFile`"" 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output   = ($output | Out-String).TrimEnd()
    }
}

# =============================================================================
# Main execution
# =============================================================================

# Dot-source guard: when the script is dot-sourced (. ./script.ps1), load
# functions into the caller's scope but skip the main execution block.
# This allows Pester tests to unit-test individual functions directly.
if ($MyInvocation.InvocationName -eq '.') { return }

# --- Verify command ---

if ($Verify) {
    try {
        $resolvedFile = $null
        if (-not [string]::IsNullOrEmpty($FilePath)) {
            $resolvedFile = Resolve-Path -LiteralPath $FilePath -ErrorAction SilentlyContinue
        }
        if ($null -eq $resolvedFile) {
            $msg = "File not found: $FilePath"
            switch ($Format) {
                'json' {
                    Write-Output (@{
                        ok = $false; command = 'verify'
                        tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                        error = @{ code = $ExitFatal; message = $msg }
                    } | ConvertTo-Json -Depth 5 -Compress)
                }
                'object' {
                    Write-Output ([PSCustomObject]@{
                        ok = $false; command = 'verify'
                        tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                        error = [PSCustomObject]@{ code = $ExitFatal; message = $msg }
                    })
                }
                default { Write-Error $msg -ErrorAction Continue }
            }
            exit $ExitFatal
        }
        $resolvedFilePath = $resolvedFile.ProviderPath

        $signtool = Find-SignTool $SignToolPath
        if ($null -eq $signtool) {
            $msg = 'signtool.exe not found. Install the Windows SDK or pass -SignToolPath.'
            switch ($Format) {
                'json' {
                    Write-Output (@{
                        ok = $false; command = 'verify'
                        tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                        error = @{ code = $ExitFatal; message = $msg }
                    } | ConvertTo-Json -Depth 5 -Compress)
                }
                'object' {
                    Write-Output ([PSCustomObject]@{
                        ok = $false; command = 'verify'
                        tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                        error = [PSCustomObject]@{ code = $ExitFatal; message = $msg }
                    })
                }
                default { Write-Error $msg -ErrorAction Continue }
            }
            exit $ExitFatal
        }

        $result = Invoke-SignToolVerify -SignToolExe $signtool -TargetFile $resolvedFilePath
        $signed = ($result.ExitCode -eq 0)
        $outputLines = @($result.Output -split '\r?\n')

        switch ($Format) {
            'json' {
                $envelope = @{
                    ok      = $signed
                    command = 'verify'
                    tool    = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    result  = @{
                        filePath         = $resolvedFilePath
                        signed           = $signed
                        signtoolExitCode = $result.ExitCode
                        signtoolOutput   = $outputLines
                    }
                }
                Write-Output ($envelope | ConvertTo-Json -Depth 5 -Compress)
            }
            'object' {
                Write-Output ([PSCustomObject]@{
                    ok      = $signed
                    command = 'verify'
                    tool    = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    result  = [PSCustomObject]@{
                        filePath         = $resolvedFilePath
                        signed           = $signed
                        signtoolExitCode = $result.ExitCode
                        signtoolOutput   = $outputLines
                    }
                })
            }
            default {
                Write-Host $result.Output
            }
        }

        if ($signed) {
            exit $ExitSuccess
        }
        else {
            exit $ExitDirty
        }
    }
    catch {
        $msg = "$_"
        switch ($Format) {
            'json' {
                Write-Output (@{
                    ok = $false; command = 'verify'
                    tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    error = @{ code = $ExitFatal; message = $msg }
                } | ConvertTo-Json -Depth 5 -Compress)
            }
            'object' {
                Write-Output ([PSCustomObject]@{
                    ok = $false; command = 'verify'
                    tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    error = [PSCustomObject]@{ code = $ExitFatal; message = $msg }
                })
            }
            default { Write-Error "Fatal error: $_" -ErrorAction Continue }
        }
        exit $ExitFatal
    }
}

# --- Sign command ---

if ($Sign) {
    try {
        # Load .env file for Azure credentials
        if (-not [string]::IsNullOrEmpty($EnvFile)) {
            Import-EnvFile $EnvFile
        }

        # Find signtool.exe
        $signtool = Find-SignTool $SignToolPath
        if ($null -eq $signtool) {
            $msg = 'signtool.exe not found. Install the Windows SDK or pass -SignToolPath.'
            switch ($Format) {
                'json'   { Write-Output (@{ ok = $false; command = 'sign'; tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = @{ code = $ExitFatal; message = $msg } } | ConvertTo-Json -Depth 5 -Compress) }
                'object' { Write-Output ([PSCustomObject]@{ ok = $false; command = 'sign'; tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = [PSCustomObject]@{ code = $ExitFatal; message = $msg } }) }
                default  { Write-Error $msg -ErrorAction Continue }
            }
            exit $ExitFatal
        }

        # Find Azure.CodeSigning.Dlib.dll
        $dlib = Find-Dlib $DlibPath
        if ($null -eq $dlib) {
            $msg = "Azure.CodeSigning.Dlib.dll not found. Install via: winget install -e --id Microsoft.Azure.TrustedSigningClientTools"
            if (-not [string]::IsNullOrEmpty($DlibPath)) { $msg = "Azure.CodeSigning.Dlib.dll not found at: $DlibPath" }
            switch ($Format) {
                'json'   { Write-Output (@{ ok = $false; command = 'sign'; tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = @{ code = $ExitFatal; message = $msg } } | ConvertTo-Json -Depth 5 -Compress) }
                'object' { Write-Output ([PSCustomObject]@{ ok = $false; command = 'sign'; tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = [PSCustomObject]@{ code = $ExitFatal; message = $msg } }) }
                default  { Write-Error $msg -ErrorAction Continue }
            }
            exit $ExitFatal
        }

        # Find metadata.json
        $metadata = $MetadataPath
        if ([string]::IsNullOrEmpty($metadata)) {
            $metadata = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'metadata.json'
        }
        if (-not (Test-Path -LiteralPath $metadata -PathType Leaf)) {
            $msg = "Metadata JSON not found at: $metadata"
            switch ($Format) {
                'json'   { Write-Output (@{ ok = $false; command = 'sign'; tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = @{ code = $ExitFatal; message = $msg } } | ConvertTo-Json -Depth 5 -Compress) }
                'object' { Write-Output ([PSCustomObject]@{ ok = $false; command = 'sign'; tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = [PSCustomObject]@{ code = $ExitFatal; message = $msg } }) }
                default  { Write-Error $msg -ErrorAction Continue }
            }
            exit $ExitFatal
        }

        # Validate Azure credentials
        foreach ($var in @('AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_CLIENT_SECRET')) {
            if (-not [Environment]::GetEnvironmentVariable($var)) {
                $msg = "Environment variable $var is not set. Pass -EnvFile or set it in the environment."
                switch ($Format) {
                    'json'   { Write-Output (@{ ok = $false; command = 'sign'; tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = @{ code = $ExitFatal; message = $msg } } | ConvertTo-Json -Depth 5 -Compress) }
                    'object' { Write-Output ([PSCustomObject]@{ ok = $false; command = 'sign'; tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = [PSCustomObject]@{ code = $ExitFatal; message = $msg } }) }
                    default  { Write-Error $msg -ErrorAction Continue }
                }
                exit $ExitFatal
            }
        }

        # Sign each file
        $signed = 0
        $failed = 0
        $items = [System.Collections.Generic.List[object]]::new()

        foreach ($file in $Files) {
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                if ($Format -eq 'text') { Write-Host "  SKIP  $file (not found)" -ForegroundColor Yellow }
                $items.Add(@{ file = $file; success = $false; message = 'File not found' })
                $failed++
                continue
            }

            $resolvedFile = (Resolve-Path -LiteralPath $file).ProviderPath
            if ($Format -eq 'text') { Write-Host "  SIGN  $resolvedFile" -ForegroundColor Cyan }

            $result = Invoke-SignToolSign -SignToolExe $signtool -DlibDll $dlib -MetadataJson $metadata -TargetFile $resolvedFile

            if ($result.ExitCode -ne 0) {
                if ($Format -eq 'text') {
                    Write-Host $result.Output -ForegroundColor Red
                    Write-Host "  FAIL  $resolvedFile (exit code $($result.ExitCode))" -ForegroundColor Red
                }
                $items.Add(@{ file = $resolvedFile; success = $false; exitCode = $result.ExitCode; message = $result.Output })
                $failed++
            }
            else {
                if ($Format -eq 'text') { Write-Host "  OK    $resolvedFile" -ForegroundColor Green }
                $items.Add(@{ file = $resolvedFile; success = $true; exitCode = 0 })
                $signed++
            }
        }

        # Output results
        $allOk = ($failed -eq 0)
        $total = $Files.Count

        switch ($Format) {
            'json' {
                $envelope = @{
                    ok      = $allOk
                    command = 'sign'
                    tool    = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    result  = @{
                        signed = $signed
                        failed = $failed
                        total  = $total
                        items  = @($items)
                    }
                }
                Write-Output ($envelope | ConvertTo-Json -Depth 5 -Compress)
            }
            'object' {
                Write-Output ([PSCustomObject]@{
                    ok      = $allOk
                    command = 'sign'
                    tool    = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }
                    result  = [PSCustomObject]@{
                        signed = $signed
                        failed = $failed
                        total  = $total
                        items  = @($items | ForEach-Object { [PSCustomObject]$_ })
                    }
                })
            }
            default {
                Write-Host ''
                Write-Host "Signed: $signed  Failed: $failed  Total: $total"
            }
        }

        if ($allOk) { exit $ExitSuccess }
        elseif ($signed -gt 0) { exit $ExitPartialFailure }
        else { exit $ExitFatal }
    }
    catch {
        $msg = "$_"
        switch ($Format) {
            'json'   { Write-Output (@{ ok = $false; command = 'sign'; tool = @{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = @{ code = $ExitFatal; message = $msg } } | ConvertTo-Json -Depth 5 -Compress) }
            'object' { Write-Output ([PSCustomObject]@{ ok = $false; command = 'sign'; tool = [PSCustomObject]@{ name = 'delphi-codesign-azure'; version = $script:ToolVersion }; error = [PSCustomObject]@{ code = $ExitFatal; message = $msg } }) }
            default  { Write-Error "Fatal error: $_" -ErrorAction Continue }
        }
        exit $ExitFatal
    }
}

# --- Main parameter set (future commands) ---

try {

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # Resolve root path
    $root = Resolve-ToolRoot $RootPath
    if (-not (Test-SafeRoot $root)) {
        exit $ExitFatal
    }

    # Resolve configuration
    $effectiveConfig = Resolve-EffectiveConfig -Root $root -ExplicitConfigFile $ConfigFile

    # Apply CLI overrides to effective config (CLI wins over config files)
    # Example:
    # if ($PSBoundParameters.ContainsKey('OutputLevel')) {
    #     $effectiveConfig | Add-Member -MemberType NoteProperty -Name 'outputLevel' -Value $OutputLevel -Force
    # }

    # -ShowConfig: display merged config and exit
    if ($ShowConfig) {
        if ($Json) {
            Write-Output ($effectiveConfig | ConvertTo-Json -Depth 5)
        }
        else {
            Write-Host "Effective configuration for: $root"
            Write-Host ($effectiveConfig | ConvertTo-Json -Depth 5)
        }
        exit $ExitSuccess
    }

    # -Check and -WhatIf are mutually exclusive
    if ($Check -and $WhatIfPreference) {
        Write-Error '-Check and -WhatIf cannot be used together.' -ErrorAction Continue
        exit $ExitFatal
    }

    # =========================================================================
    # Tool-specific logic goes here.
    #
    # See CUSTOMIZATION.md for patterns:
    #   - File scanning
    #   - Engine discovery and dispatch
    #   - Check mode implementation
    #   - Result collection and reporting
    # =========================================================================

    # Placeholder: report success
    $sw.Stop()

    Write-Summary "Completed in $(Format-Duration $sw.Elapsed.TotalMilliseconds)"
    exit $ExitSuccess

}
catch {
    Write-Error "Fatal error: $_" -ErrorAction Continue
    exit $ExitFatal
}
