#requires -Version 5.1
# -----------------------------------------------------------------------------
# delphi-TOOLNAME
#
# (One-line description of what this tool does.)
#
# Part of Continuous-Delphi: Focused on strengthening Delphi's continued success
# https://github.com/continuous-delphi
#
# Project repository:
# https://github.com/continuous-delphi/delphi-TOOLNAME
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
(Brief synopsis of what the tool does.)

.DESCRIPTION
(Detailed description.)

Exit codes:
  0  success
  1  check mode found items needing attention
  2  partial failure
  3  fatal error

.EXAMPLE
pwsh -File source/delphi-TOOLNAME.ps1

.EXAMPLE
pwsh -File source/delphi-TOOLNAME.ps1 -Version -Format json
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Main')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
  Justification='Write-Host is intentional: standalone CLI tool streams status to the console host.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'OutputLevel',
  Justification='Consumed by Write-Detail/Write-Summary helper functions.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'PassThru',
  Justification='Template placeholder: consumed by tool-specific logic added during customization.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'OutputFile',
  Justification='Template placeholder: consumed by tool-specific logic added during customization.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ExitDirty',
  Justification='Exit code constant available for tool-specific logic.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ExitPartialFailure',
  Justification='Exit code constant available for tool-specific logic.')]
param(
    [Parameter(ParameterSetName = 'Version', Mandatory)]
    [switch]$Version,

    [Parameter(ParameterSetName = 'Version')]
    [ValidateSet('text', 'json')]
    [string]$Format = 'text',

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
    # Add tool-specific parameters here.  Examples:
    #
    # [Parameter(ParameterSetName = 'Main')]
    # [ValidateSet('engine1', 'engine2')]
    # [string]$Engine = 'engine1',
    #
    # [Parameter(ParameterSetName = 'Main')]
    # [string]$EnginePath,
    #
    # [Parameter(ParameterSetName = 'Main')]
    # [string[]]$IncludeFilePattern = @(),
    #
    # [Parameter(ParameterSetName = 'Main')]
    # [string[]]$ExcludeDirectoryPattern = @(),
    #
    # [Parameter(ParameterSetName = 'Main')]
    # [int]$TimeoutSeconds = 300
    # -------------------------------------------------------------------------
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Exit code constants
$ExitSuccess        = 0
$ExitDirty          = 1   # -Check found items needing attention
$ExitPartialFailure = 2   # some items failed
$ExitFatal          = 3   # engine not found, bad root, unhandled error

$script:ToolVersion = '0.1.0'

# =============================================================================
# Version info
# =============================================================================

if ($Version) {
    $info = @{
        ok      = $true
        command = 'version'
        tool    = @{
            name    = 'delphi-TOOLNAME'
            version = $script:ToolVersion
        }
    }
    if ($Format -eq 'json') {
        Write-Output ($info | ConvertTo-Json -Depth 5 -Compress)
    }
    else {
        Write-Output "delphi-TOOLNAME $($script:ToolVersion)"
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

    # Layer 1: $HOME/delphi-TOOLNAME.json
    $homeDir = if ($env:DELPHI_TOOLNAME_HOME_OVERRIDE) {
        $env:DELPHI_TOOLNAME_HOME_OVERRIDE
    } else {
        $HOME
    }
    $homeConfig = Read-ConfigFile (Join-Path $homeDir 'delphi-TOOLNAME.json')
    $config = Merge-ToolConfig $config $homeConfig

    # Layer 2: upward traversal (if searchParentFolders enabled)
    $searchParents = Get-ConfigValue $config 'searchParentFolders'
    # Check project-level config first to see if traversal is enabled
    $projectConfig = Read-ConfigFile (Join-Path $Root 'delphi-TOOLNAME.json')
    $localConfig   = Read-ConfigFile (Join-Path $Root 'delphi-TOOLNAME.local.json')
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
            $parentFile = Join-Path $current.FullName 'delphi-TOOLNAME.json'
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
# Engine discovery (if needed -- see CUSTOMIZATION.md)
# =============================================================================

# function Find-Engine1 {
#     param([string]$ExplicitPath)
#     if (-not [string]::IsNullOrEmpty($ExplicitPath)) {
#         if (Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
#             return $ExplicitPath
#         }
#         $found = Get-Command $ExplicitPath -ErrorAction SilentlyContinue
#         if ($null -ne $found) { return $found.Source }
#         return $null
#     }
#     $found = Get-Command 'engine1.exe' -ErrorAction SilentlyContinue
#     if ($null -ne $found) { return $found.Source }
#     return $null
# }

# =============================================================================
# Main execution
# =============================================================================

# Dot-source guard: when the script is dot-sourced (. ./script.ps1), load
# functions into the caller's scope but skip the main execution block.
# This allows Pester tests to unit-test individual functions directly.
if ($MyInvocation.InvocationName -eq '.') { return }

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
