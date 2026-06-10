# delphi-codesign-azure

<!-- Badges -->
[![CI](https://github.com/continuous-delphi/delphi-codesign-azure/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/delphi-codesign-azure/actions/workflows/ci.yml)

A PowerShell utility for Authenticode code signing and verification
using Azure Trusted Signing and `signtool.exe`.

Part of [Continuous-Delphi](https://github.com/continuous-delphi):
Focused on strengthening Delphi's continued success.

---

## Quick Start

```powershell
# Sign an executable
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format text

# Sign multiple files
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe,lib.bpl -EnvFile .env -Format text

# Verify a signed executable
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -Format text

# Version info
pwsh -File source/delphi-codesign-azure.ps1 -Version -Format text
```

---

## Commands

### `-Sign`

Signs one or more files using Azure Trusted Signing via
`signtool.exe sign` with SHA256 digest and RFC 3161 timestamping.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Sign` | switch | yes | Select the sign command |
| `-Files` | string[] | yes | One or more file paths to sign |
| `-SignToolPath` | string | no | Explicit path to `signtool.exe`. Auto-discovered from the Windows SDK if omitted |
| `-DlibPath` | string | no | Path to `Azure.CodeSigning.Dlib.dll`. Defaults to `%LOCALAPPDATA%\Microsoft\MicrosoftTrustedSigningClientTools\` |
| `-MetadataPath` | string | no | Path to `metadata.json`. Defaults to the `source/` directory |
| `-EnvFile` | string | no | `.env` file with Azure credentials (see Prerequisites) |
| `-Format` | string | no | Output format: `object` (default), `text`, `json` |

**Prerequisites:**

- `signtool.exe` from the Windows SDK
- `Azure.CodeSigning.Dlib.dll` -- install via `winget install -e --id Microsoft.Azure.TrustedSigningClientTools`
- `metadata.json` with Azure Trusted Signing endpoint, account name, and certificate profile
- Azure credentials: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` (via environment or `-EnvFile`)

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | All files signed successfully |
| 2 | Partial failure (some files failed) |
| 3 | Fatal error (prerequisites missing, no files signed) |

**Examples:**

```powershell
# Sign a single file
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format text

# Sign multiple files
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe,lib.bpl -EnvFile .env -Format text

# JSON output for CI
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format json

# Pipeline use
$result = & source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env
$result.ok              # $true if all signed
$result.result.signed   # count of signed files
$result.result.failed   # count of failed files
```

### `-Verify`

Verifies the Authenticode signature on a file using `signtool.exe verify /pa /v`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Verify` | switch | yes | Select the verify command |
| `-FilePath` | string | yes | Path to the file to verify |
| `-SignToolPath` | string | no | Explicit path to `signtool.exe`. Auto-discovered from the Windows SDK if omitted |
| `-Format` | string | no | Output format: `object` (default), `text`, `json` |

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Signature is valid |
| 1 | Signature is invalid or file is not signed |
| 3 | Fatal error (file not found, signtool not found) |

**Examples:**

```powershell
# Verify a signed executable (text output)
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -Format text

# JSON output for CI consumption
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -Format json

# Pipeline use (object output, default)
$result = & source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe
$result.ok            # $true if signed
$result.result.signed # $true if signed

# Explicit signtool path
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -SignToolPath "C:\path\to\signtool.exe"
```

**signtool.exe discovery:**

When `-SignToolPath` is not specified, the tool searches
`C:\Program Files (x86)\Windows Kits\10\bin` for the latest x64
version of `signtool.exe`. Install the Windows SDK if it is not found:
https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

### `-Version`

Displays tool name and version.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Version` | switch | yes | Select the version command |
| `-Format` | string | no | Output format: `object` (default), `text`, `json` |

**Examples:**

```powershell
# Text format
pwsh -File source/delphi-codesign-azure.ps1 -Version -Format text
# => delphi-codesign-azure 0.1.0

# JSON format
pwsh -File source/delphi-codesign-azure.ps1 -Version -Format json
# => {"ok":true,"command":"version","tool":{"name":"delphi-codesign-azure","version":"0.1.0"}}
```

---

## Output Formats

The `-Format` parameter controls output across all commands:

| Format | Description |
|--------|-------------|
| `object` | Default. Returns a `PSCustomObject` for pipeline use |
| `text` | Human-readable text to the console |
| `json` | Single-line compressed JSON for CI/scripting |

### JSON Envelope

Success:

```json
{
  "ok": true,
  "command": "verify",
  "tool": { "name": "delphi-codesign-azure", "version": "0.1.0" },
  "result": {
    "filePath": "C:/path/to/file.exe",
    "signed": true,
    "signtoolExitCode": 0,
    "signtoolOutput": ["..."]
  }
}
```

Error:

```json
{
  "ok": false,
  "command": "verify",
  "tool": { "name": "delphi-codesign-azure", "version": "0.1.0" },
  "error": { "code": 3, "message": "File not found: missing.exe" }
}
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
bundles `delphi-codesign-azure` as a pipeline action.

---

<br />

### `delphi-codesign-azure` - a developer tool from Continuous Delphi

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

https://github.com/continuous-delphi
