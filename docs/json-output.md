# JSON Output

When `-Json` is active, `delphi-TOOLNAME` emits a single JSON object to
standard output. All other text output is suppressed.

## Output Shape

The same structure is returned across all modes (Execute, WhatIf, Check):

```json
{
  "Root": "C:/code/myproject",
  "Mode": "Execute",
  "DurationMs": 250
}
```

<!-- Add tool-specific fields here -->

### Mode Values

| Mode | Description |
|------|-------------|
| `Execute` | Normal run -- changes were made |
| `WhatIf (no changes)` | Preview mode -- no changes made |
| `Check (no changes)` | Audit mode -- no changes made |

## `-OutputFile`

When `-OutputFile <path>` is specified, a structured JSON result file is
written for CI integration. This is the same data as `-Json` output but
written to a file instead of stdout.

The CI module wrapper (`Invoke-DelphiTOOLNAME` in delphi-powershell-ci)
uses this file to parse results back into a PowerShell step result object.

## `-Version -Format json`

```json
{
  "ok": true,
  "command": "version",
  "tool": {
    "name": "delphi-TOOLNAME",
    "version": "0.1.0"
  }
}
```

## `-ShowConfig -Json`

Returns the effective merged configuration as a JSON object. Structure
depends on the tool's supported config keys.
