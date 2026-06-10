# Customization Guide

This template provides the skeleton for a new `delphi-*` PowerShell tool
in the Continuous-Delphi ecosystem. After cloning, replace `TOOLNAME`
throughout and then add tool-specific logic.

---

## Quick Start

1. Copy or clone this template into a new repo directory
2. Global find-and-replace `TOOLNAME` with your tool name (e.g. `format`,
   `lint`, `metrics`)
3. Rename `source/delphi-TOOLNAME.ps1` to match
4. Rename `tests/pwsh/delphi-TOOLNAME.Version.Tests.ps1` to match
5. Update `tests/pwsh/Invoke-ScriptAnalyzer.Tests.ps1` script path
6. Update `tools/open-repo.bat` with the actual GitHub URL
7. Update `.github/RELEASE_TEMPLATE.md` description
8. Update `README.md` with tool-specific content
9. Update `CHANGELOG.md` with tool-specific content
10. Delete this file (`CUSTOMIZATION.md`) -- it is a setup guide, not a
    project artifact

### Environment Variable Rename

The config system uses `$env:DELPHI_TOOLNAME_HOME_OVERRIDE` for test
isolation. Rename this to match your tool:

- In `source/delphi-TOOLNAME.ps1`: the `Resolve-EffectiveConfig` function
- In tests: set the renamed variable to redirect `$HOME` lookups

---

## What the Template Provides

These features are fully implemented and ready to use:

- **Version API** -- `-Version` / `-Version -Format json` with the
  standard `{ ok, command, tool: { name, version } }` envelope
- **Output helpers** -- `Write-Detail`, `Write-Summary`, `Write-Section`,
  `Write-SummarySection` with `-OutputLevel` and `-Json` suppression
- **Config hierarchy** -- `Resolve-EffectiveConfig` with `$HOME`,
  project, local, explicit, and upward traversal layers
- **Config merge** -- `Merge-ToolConfig` with scalar-override and
  array-append semantics
- **Root path resolution** -- `Resolve-ToolRoot`, `Test-SafeRoot`
- **ShowConfig mode** -- `-ShowConfig` / `-ShowConfig -Json`
- **Check/WhatIf mutual exclusion** -- validated in the main block
- **Exit code constants** -- `$ExitSuccess`, `$ExitDirty`,
  `$ExitPartialFailure`, `$ExitFatal`
- **Dot-source guard** -- `if ($MyInvocation.InvocationName -eq '.') { return }`
  allows Pester tests to dot-source the script and unit-test internal
  functions without executing the main block
- **PSScriptAnalyzer compliance** -- `SuppressMessageAttribute` for
  intentional `Write-Host` usage
- **Test infrastructure** -- Pester config, runner, ScriptAnalyzer test,
  Version API test, smoke test, `TestHelpers.ps1` with
  `Invoke-ToolProcess` for subprocess testing
- **CI/CD** -- GitHub Actions for testing and tag-triggered releases
- **Release tooling** -- `tag-release.ps1` with 9 precondition checks

---

## Common Add-On Patterns

The following patterns are NOT in the template because they are
tool-specific. Each section describes where to find the reference
implementation in a sibling repo.

### Pluggable Engine Abstraction

**When:** Your tool wraps multiple external executables (e.g. different
formatters, coverage engines, build tools).

**Reference:** `C:\code\delphi-coverage\source\delphi-coverage.ps1`

**Pattern:**

1. Add a `[ValidateSet('engine1', 'engine2')] [string]$Engine` parameter
   with a default
2. Add a separate `[string]$EnginePath` parameter for explicit binary path
3. Create one `Find-<EngineName>` function per engine with three-step
   resolution: explicit path > bare filename via `Get-Command` >
   auto-discovery via `Get-Command '<default>.exe'`
4. Dispatch with a `switch ($Engine)` block
5. Use inline conditionals for engine-specific argument differences
6. Validate engine availability before dispatch (exit code 3 if not found)

**Key functions to study:**
- `Find-DelphiCodeCoverage` (line ~168)
- `Find-RadCodeCoverage` (line ~196)
- `Invoke-DelphiCodeCoverageEngine` (line ~223)

### File Scanning with Exclusions

**When:** Your tool processes files in a directory tree and needs to
respect exclusion patterns.

**Reference:** `C:\code\delphi-clean\source\delphi-clean.ps1`

**Pattern:**

1. Define built-in excluded directories (`.git`, `.vs`, `.claude`)
2. Merge with user-supplied `-ExcludeDirectoryPattern`
3. Recursively scan with `Get-ChildItem -Recurse`
4. Filter each path through `Test-PathUnderExcludedDirectory` (checks
   each path segment against exclusion patterns with `-like`)
5. Match files against include patterns (built-in + user-supplied)

**Key functions to study:**
- `Get-FilesToDelete` (line ~874)
- `Get-DirectoriesToDelete` (line ~914)
- `Test-PathUnderExcludedDirectory` (line ~517)

### Check Mode (Audit Without Changes)

**When:** Your tool should support CI validation that fails the build if
files are not in the expected state.

**Reference:** `C:\code\delphi-clean\source\delphi-clean.ps1`

**Pattern:**

1. Add `[switch]$Check` parameter
2. Validate mutual exclusion with `-WhatIf` (already in template)
3. Scan for items that need attention
4. Report findings at the configured `-OutputLevel`
5. Exit with code 1 if items found, 0 if clean
6. JSON output uses `"Mode": "Check (no changes)"` and `"Check": true`

### Structured JSON Result Output

**When:** Your tool will be bundled into `delphi-powershell-ci` and needs
to pass structured results back to the CI wrapper.

**Reference:** `C:\code\delphi-coverage\source\delphi-coverage.ps1`

**Pattern:**

1. Add `[string]$OutputFile` parameter (already in template)
2. Build a result hashtable with tool-specific fields
3. Write to the output file: `$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputFile`
4. The CI wrapper creates a temp file, passes it via `-OutputFile`,
   reads back the JSON, and parses into its step result object

### CI Module Integration (delphi-powershell-ci)

**When:** Your tool should be available as a pipeline action in the
Continuous-Delphi CI module.

**Reference:** `C:\code\delphi-powershell-ci\source\Public\Invoke-DelphiCoverage.ps1`

**Files to modify in delphi-powershell-ci:**

| File | What to add |
|------|-------------|
| `source/Private/Resolve-DelphiCiConfig.ps1` | Built-in defaults, validation function, validation switch case |
| `schemas/delphi-ci.schema.json` | Config definition in `$defs`, references in `defaults` and `pipelineAction` |
| `source/Public/Invoke-DelphiCi.ps1` | CLI params, override collection, dispatch switch case |
| `source/Public/Invoke-Delphi<Tool>.ps1` | New wrapper function |
| `source/bundled-tools/delphi-<tool>.ps1` | Copy of standalone script |
| `source/Private/Get-BundledToolInfo.ps1` | Tool registration |
| `source/Delphi.PowerShell.CI.psd1` | Export the wrapper function |
| `tests/pwsh/Invoke-Delphi<Tool>.Tests.ps1` | Wrapper tests |
| `tests/pwsh/Invoke-DelphiCi.Tests.ps1` | Integration tests |
| `docs/Invoke-Delphi<Tool>.md` | Command reference |
| `examples/delphi-ci.json` | Pipeline example |

**CI wrapper naming convention:** All parameters use the action name as
prefix: `-<Tool>Engine`, `-<Tool>EnginePath`, `-<Tool>RootPath`, etc.

### Recycle Bin / Trash Support

**When:** Your tool deletes files and should support sending them to the
platform trash instead of permanent deletion.

**Reference:** `C:\code\delphi-clean\source\delphi-clean.ps1`

**Key functions to study:**
- `Get-PlatformKind` (line ~387)
- `Send-ToRecycleBin` (line ~413)
- `Send-ToMacTrash` (line ~336)
- `Send-ToLinuxTrash` (line ~352)

### Multi-Format Output (object / text / json)

**When:** Your tool needs to return structured objects to the PowerShell
pipeline (for tool composition) while also supporting human-readable text
and machine-readable JSON output.

**Reference:** `C:\code\delphi-inspect\source\delphi-inspect.ps1`

**Pattern:**

The template provides a `-Json` switch for simple JSON output. When your
tool needs full pipeline integration, replace `-Json` with a three-way
`-Format` parameter:

1. Replace the `-Json` switch with:
   ```powershell
   [ValidateSet('object', 'text', 'json')]
   [string]$Format = 'object'
   ```
2. **object** (default): Emit `PSCustomObject` via `Write-Output` for
   pipeline consumers. Suppress all `Write-Host` output.
3. **text**: Human-readable formatted output via `Write-Host`.
4. **json**: Single compressed JSON line via `Write-Output` using a
   standard envelope: `{ ok, command, tool, result }`.
5. Suppress `Write-Host` in both `object` and `json` modes:
   ```powershell
   $script:SuppressOutput = $Format -in 'object', 'json'
   ```

**Key functions to study:**
- `Write-VersionInfo` (line ~594 in delphi-inspect.ps1) -- three-format dispatch
- `Write-ResolveOutput` (line ~671) -- builds result object, formats per mode
- `Write-JsonOutput` (line ~578) -- wraps result in success envelope

### Structured Error Envelope (JSON)

**When:** Your tool uses `-Json` or `-Format json` and needs to report
errors in a machine-parseable format instead of unstructured stderr text.

**Reference:** `C:\code\delphi-inspect\source\delphi-inspect.ps1`

**Pattern:**

1. Define a `Write-JsonError` function:
   ```powershell
   function Write-JsonError([string]$Command, [int]$Code, [string]$Message) {
       $envelope = @{
           ok      = $false
           command = $Command
           tool    = @{ name = 'delphi-TOOLNAME'; version = $script:ToolVersion }
           error   = @{ code = $Code; message = $Message }
       }
       Write-Output ($envelope | ConvertTo-Json -Depth 5 -Compress)
   }
   ```
2. Call it from error paths instead of `Write-Error` when JSON output is
   active
3. Exit with the appropriate exit code after emitting the error envelope
4. Consumers check `ok` first, then branch on `error.code`

**Key functions to study:**
- `Write-JsonError` (line ~585 in delphi-inspect.ps1)
- `Write-JsonOutput` (line ~578) -- the success counterpart

### Pipeline Input (Tool Composition)

**When:** Your tool should accept piped output from another tool
(e.g. `delphi-inspect -Locate D12 | delphi-msbuild -ProjectFile app.dproj`).

**Reference:** `C:\code\delphi-msbuild\source\delphi-msbuild.ps1`

**Pattern:**

1. Add a `[Parameter(ValueFromPipeline=$true)] [psobject]$InputObject`
   parameter to accept piped objects
2. Create a resolution function that prefers an explicit CLI parameter
   over the piped property (CLI wins):
   ```powershell
   function Resolve-RootDir {
     param([string]$ExplicitRootDir, [psobject]$Installation)
     if (-not [string]::IsNullOrWhiteSpace($ExplicitRootDir)) {
       return $ExplicitRootDir
     }
     if ($null -ne $Installation) {
       $prop = $Installation.PSObject.Properties['rootDir']
       if ($null -ne $prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
         return [string]$prop.Value
       }
     }
     return $null
   }
   ```
3. Access piped properties via `.PSObject.Properties[<name>]` rather
   than dot-access to avoid strict-mode errors on missing members
4. Document which properties your tool reads from the piped object

**Key functions to study:**
- `Resolve-RootDir` (line ~147 in delphi-msbuild.ps1)

### Process Invocation with Timeout

**When:** Your tool invokes external processes that might hang.

**Reference:** `C:\code\delphi-coverage\source\delphi-coverage.ps1`

**Pattern:**
```powershell
$proc = Start-Process -FilePath $binary `
    -ArgumentList $argsString `
    -WorkingDirectory $workDir `
    -NoNewWindow -PassThru -Wait:$false
$exited = $proc.WaitForExit($TimeoutSeconds * 1000)
if (-not $exited) {
    try { $proc.Kill() } catch { Write-Verbose "Process already exited: $_" }
    return @{ Success = $false; ExitCode = -1; Message = "Timed out after ${TimeoutSeconds}s" }
}
return @{ Success = ($proc.ExitCode -eq 0); ExitCode = $proc.ExitCode }
```

---

## Testing Patterns

### Subprocess Testing with Invoke-ToolProcess

The template includes `tests/pwsh/TestHelpers.ps1` with an
`Invoke-ToolProcess` helper that runs the script as a child process and
captures exit code, stdout, and stderr separately. All sibling repos use
this pattern for integration and version tests.

**Why subprocess testing matters:** Running the script via `& $path` in
the same PowerShell session shares state, masks exit codes, and cannot
catch fatal errors that terminate the host. Subprocess invocation tests
the script exactly as end users run it.

**Usage:**

```powershell
BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:ToolPath = Get-ScriptUnderTestPath
}

It 'exits with code 0 on success' {
    $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version')
    $r.ExitCode | Should -Be 0
}

It 'returns valid JSON' {
    $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version', '-Format', 'json')
    $json = $r.StdOut | ConvertFrom-Json
    $json.ok | Should -Be $true
}

It 'reports error on stderr' {
    $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-RootPath', 'C:\nonexistent')
    $r.ExitCode | Should -Be 3
    $r.StdErr | Should -Not -BeNullOrEmpty
}
```

**Result object:**

| Property | Type | Description |
|----------|------|-------------|
| `ExitCode` | int | Process exit code |
| `StdOut` | string[] | Non-empty stdout lines |
| `StdErr` | string[] | Non-empty stderr lines |

The `-Shell` parameter selects the host executable (default: `pwsh`).
Use `-Shell powershell` with `-ExecutionPolicy Bypass` to test Windows
PowerShell 5.1 compatibility.

### Feature-Area Test Files

Split tests by feature area, one file per concern:

| File | Scope |
|------|-------|
| `delphi-<tool>.Version.Tests.ps1` | Version API (provided in template) |
| `delphi-<tool>.Config.Tests.ps1` | Config hierarchy, merge, ShowConfig |
| `delphi-<tool>.Integration.Tests.ps1` | End-to-end behavior, Check, WhatIf, Json |
| `delphi-<tool>.Engine.Tests.ps1` | Engine discovery, dispatch, arg building |
| `Invoke-ScriptAnalyzer.Tests.ps1` | Code quality (provided in template) |

### Test Workspace Isolation

```powershell
BeforeAll {
    $script:WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "delphi-tool-test-$([guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:WorkDir -ItemType Directory -Force | Out-Null
    # Redirect HOME to prevent real user config from affecting tests
    $env:DELPHI_TOOLNAME_HOME_OVERRIDE = Join-Path $script:WorkDir 'fakehome'
    New-Item -Path $env:DELPHI_TOOLNAME_HOME_OVERRIDE -ItemType Directory -Force | Out-Null
}

AfterAll {
    Remove-Item -Path $script:WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    $env:DELPHI_TOOLNAME_HOME_OVERRIDE = $null
}
```

### Test Fixtures

Place reusable JSON config files in `tests/pwsh/fixtures/`. Reference
`C:\code\delphi-clean\tests\pwsh\fixtures\` for examples of user-level,
project-level, and monorepo configs.
