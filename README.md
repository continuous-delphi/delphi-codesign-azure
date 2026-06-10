# delphi-codesign-azure

![delphi-codesign-azure logo](https://continuous-delphi.github.io/assets/logos/delphi-codesign-azure-480x270.png)

[![Delphi](https://img.shields.io/badge/delphi-red)](https://www.embarcadero.com/products/delphi)
[![CI](https://github.com/continuous-delphi/delphi-codesign-azure/actions/workflows/ci.yml/badge.svg)](https://github.com/continuous-delphi/delphi-codesign-azure/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/continuous-delphi/delphi-codesign-azure?display_name=release)](https://github.com/continuous-delphi/delphi-codesign-azure/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/continuous-delphi/delphi-codesign-azure)
[![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)](https://github.com/continuous-delphi)


A PowerShell utility for Authenticode code signing and verification
using [Azure Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/) and `signtool.exe`.

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
- `Azure.CodeSigning.Dlib.dll` -- install via `winget install -e --id 
Microsoft.Azure.TrustedSigningClientTools`
- `metadata.json` with Azure Trusted Signing endpoint, account name, and certificate profile
- Azure credentials: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` (via environment or `-
EnvFile`)

See [docs/machine_setup.md](docs/machine_setup.md) for first-time setup instructions.

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

## metadata.json

The `-Sign` command requires a `metadata.json` file that tells Azure
Trusted Signing which endpoint, account, and certificate profile to use.

```json
{
  "Endpoint": "https://eus.codesigning.azure.net/",
  "CodeSigningAccountName": "yourAccountName",
  "CertificateProfileName": "yourCertificateProfileName"
}
```

See [docs/metadata.json](docs/metadata.json) for an example.

### Fields

| Field | Description |
|-------|-------------|
| `Endpoint` | Azure Trusted Signing regional endpoint URL. Use `eus` (East US), `wus` (West US), `neu` (North Europe), or `weu` (West Europe) |
| `CodeSigningAccountName` | Name of the Trusted Signing account in the Azure portal |
| `CertificateProfileName` | Name of the certificate profile under the signing account |

### Location

By default the tool looks for `metadata.json` in the same directory as
the script (`source/`). Override with `-MetadataPath`:

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -MetadataPath path/to/metadata.json
```

### Obtaining the values

1. **Endpoint**: Azure portal > Trusted Signing account > Overview > Account URI
2. **CodeSigningAccountName**: Azure portal > Trusted Signing account > Overview > Name
3. **CertificateProfileName**: Azure portal > Trusted Signing account > Certificate profiles > Profile name

---

## Azure Credentials

The `-Sign` command requires three Azure environment variables for
authentication with Azure Trusted Signing:

| Variable | Description |
|----------|-------------|
| `AZURE_TENANT_ID` | Entra ID tenant ID |
| `AZURE_CLIENT_ID` | Application (client) ID of the app registration |
| `AZURE_CLIENT_SECRET` | Client secret value (not the secret ID) |

### Setting credentials in the shell

PowerShell:

```powershell
$env:AZURE_TENANT_ID = 'your-tenant-id'
$env:AZURE_CLIENT_ID = 'your-client-id'
$env:AZURE_CLIENT_SECRET = 'your-client-secret'
```

Batch:

```batch
set AZURE_TENANT_ID=your-tenant-id
set AZURE_CLIENT_ID=your-client-id
set AZURE_CLIENT_SECRET=your-client-secret
```

### Using a .env file

For local development, credentials can be stored in a `.env` file and
loaded via the `-EnvFile` parameter:

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format text
```

See [docs/.env.example](docs/.env.example) for the file format.

**Format rules:**

- One `KEY=VALUE` pair per line
- Lines starting with `#` are comments
- Blank lines are ignored
- Existing environment variables are **not** overwritten -- the `.env`
  file only fills in values that are not already set

**Security:** The `.env` file contains secrets and should not be
committed. Add it to `.gitignore`.

### Obtaining credentials from Azure

1. **AZURE_TENANT_ID**: Azure portal > Entra ID > Overview > Tenant ID
2. **AZURE_CLIENT_ID**: Azure portal > Entra ID > App registrations > your app > Application (client) ID
3. **AZURE_CLIENT_SECRET**: Azure portal > Entra ID > App registrations > your app > Certificates & secrets 
> New client secret > copy the **Value** (not the Secret ID)

If the client secret has expired, create a new one in the portal.

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

Requires PowerShell 7+, Pester 5.7+, and PSScriptAnalyzer.

```powershell
./tests/run-tests.ps1
```

---

## Continuous-Delphi

This tool is part of the [Continuous-Delphi](https://github.com/continuous-delphi)
ecosystem, focused on strengthening Delphi's continued success.

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)