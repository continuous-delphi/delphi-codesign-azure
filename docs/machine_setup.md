# Code Signing Machine Setup

Checklist for setting up Azure Trusted Signing on a new machine.
The Azure account, identity validation, certificate profile, and app
registration are configured elsewhere, this covers local tooling only.

## Prerequisites

- Windows 10/11
- Internet access to `https://eus.codesigning.azure.net/`
- Access to the `.env` credential values (see step 3)

## 1. Install Windows SDK (for signtool.exe)

signtool.exe ships with the Windows SDK. It may already be present if
RAD Studio is installed.

Verify:

```bash
dir "C:\Program Files (x86)\Windows Kits\10\bin" /s /b | findstr x64\\signtool.exe
```

If not found, install the Windows SDK from:
https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

Only the "Windows SDK Signing Tools for Desktop Apps" feature is required.

Expected path (version may differ):

`C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe`

The tool auto-discovers signtool.exe from the Windows SDK. If discovery
fails, pass `-SignToolPath` explicitly.

## 2. Install Azure Trusted Signing Client Tools

```powershell
winget install -e --id Microsoft.Azure.TrustedSigningClientTools --source winget
```

Note: `--source winget` is required on machines where the Microsoft
Store source (`msstore`) has a stale TLS certificate (common on fresh
VMs). It forces winget to use the community repo directly

This installs `Azure.CodeSigning.Dlib.dll` to:

`%LOCALAPPDATA%\Microsoft\MicrosoftTrustedSigningClientTools\Azure.CodeSigning.Dlib.dll`

Verify the file exists after install.

## 3. Create the .env file

Create a `.env` file (gitignored -- must never be committed). Use
[docs/.env.example](/.env.example) as a template, or create it with
these contents:

    # Azure Trusted Signing credentials
    # Do not commit this file
    # AZURE_TENANT_ID -- Entra ID tenant ID
    # AZURE_CLIENT_ID -- Application (client) ID of the app registration
    # AZURE_CLIENT_SECRET -- The client secret value

    AZURE_TENANT_ID=<value>
    AZURE_CLIENT_ID=<value>
    AZURE_CLIENT_SECRET=<value>

Obtain the values from Azure Portal:
- Tenant ID: Entra ID > Overview > Tenant ID
- Client ID: Entra ID > App registrations > <yourSignerApp> > Application (client) ID
- Client Secret: Entra ID > App registrations > <yourSignerApp> > Certificates & secrets

If the client secret has expired, create a new one in the portal.

Pass the file to the tool via `-EnvFile`:

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format text
```

## 4. Test signing

Sign and verify:

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -Sign -Files app.exe -EnvFile .env -Format text
pwsh -File source/delphi-codesign-azure.ps1 -Verify -FilePath app.exe -Format text
```

Expected output from verify: certificate chain is present, timestamp
is present, 0 errors.

## Azure account reference

These should be configured manually:

| Resource | Value |
|----------|-------|
| Subscription |  |
| Subscription ID | |
| Resource group |  |
| Signing account | |
| Account URI | |
| Certificate profile | |
| App registration |  |
| Identity validation ID |  |

## Troubleshooting

**403 Forbidden**: Most common cause is a mismatch in `metadata.json`.
Verify the endpoint region, account name, and certificate profile name
all match the Azure portal exactly.

**signtool not found**: The tool auto-discovers signtool.exe from the
Windows SDK. Pass `-SignToolPath` to override if discovery fails.

**Dlib not found**: Reinstall via `winget install -e --id Microsoft.Azure.TrustedSigningClientTools`.

**Client secret expired**: Create a new secret in Azure Portal under
the app registration and update `.env`.
