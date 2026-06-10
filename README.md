# delphi-TOOLNAME

<!-- Badges -->
[![CI](https://github.com/continuous-delphi/delphi-TOOLNAME/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/delphi-TOOLNAME/actions/workflows/ci.yml)

A PowerShell utility for ... (one-line description).

Part of [Continuous-Delphi](https://github.com/continuous-delphi):
Focused on strengthening Delphi's continued success.

---

## Quick Start

```powershell
# PowerShell 7+
pwsh -File source/delphi-TOOLNAME.ps1

# Windows PowerShell 5.1
powershell.exe -File source\delphi-TOOLNAME.ps1
```

---

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `-RootPath` | string | current directory | Root directory to process |
| `-OutputLevel` | string | `detailed` | Output verbosity: `detailed`, `summary`, `quiet` |
| `-Json` | switch | | Emit JSON output instead of plain text |
| `-Check` | switch | | Audit-only mode (exit 1 if changes needed) |
| `-WhatIf` | switch | | Preview mode (no changes made) (common parameter via `SupportsShouldProcess`) |
| `-Confirm` | switch | | Prompt before state-changing actions (common parameter via `SupportsShouldProcess`) |
| `-ShowConfig` | switch | | Display merged configuration and exit |
| `-ConfigFile` | string | | Explicit JSON configuration file path |
| `-Version` | switch | | Display tool version and exit |
| `-Format` | string | `text` | Output format for `-Version`: `text` or `json` |

<!-- Add tool-specific parameters above this line -->

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Check mode found items needing attention |
| 2 | Partial failure (some items failed) |
| 3 | Fatal error (bad root, unhandled exception) |

---

## Configuration

Configuration files are loaded from multiple locations with increasing
priority. See [docs/configuration.md](docs/configuration.md) for details.

```
$HOME/delphi-TOOLNAME.json              (user-level defaults)
<RootPath>/delphi-TOOLNAME.json         (project-level, committed)
<RootPath>/delphi-TOOLNAME.local.json   (local overrides, gitignored)
-ConfigFile <path>                       (explicit CI override)
CLI parameters                           (highest priority)
```

---

## Examples

```powershell
# Basic usage
pwsh -File source/delphi-TOOLNAME.ps1

# Check mode (CI validation)
pwsh -File source/delphi-TOOLNAME.ps1 -Check -OutputLevel quiet

# JSON output
pwsh -File source/delphi-TOOLNAME.ps1 -Json

# Preview without changes
pwsh -File source/delphi-TOOLNAME.ps1 -WhatIf

# Show merged configuration
pwsh -File source/delphi-TOOLNAME.ps1 -ShowConfig -Json

# Version info
pwsh -File source/delphi-TOOLNAME.ps1 -Version -Format json
```

---

## Running Tests

```powershell
# Requires: PowerShell 7+, Pester 5.7+, PSScriptAnalyzer
Install-Module Pester -MinimumVersion 5.7.0 -Force -Scope CurrentUser
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser

pwsh tests/run-tests.ps1
```

---

## Also Included In

The [Continuous-Delphi PowerShell CI module](https://github.com/continuous-delphi/delphi-powershell-ci)
bundles `delphi-TOOLNAME` as a pipeline action.

---

<br />

### `delphi-TOOLNAME` - a developer tool from Continuous Delphi

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

https://github.com/continuous-delphi
