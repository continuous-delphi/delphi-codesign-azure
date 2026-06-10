# Changelog

All notable changes to this project will be documented in this file.

---

## [0.5.14] - 2026-06-09

- Readme cleanup, ready for testing

## [0.1.2] - 2026-06-09

- Add `-Sign` command: signs files using Azure Trusted Signing via `signtool.exe sign`
- SHA256 file digest with RFC 3161 timestamping from `timestamp.acs.microsoft.com`
- Multi-file signing with per-file success/failure tracking
- `.env` file loading for Azure credentials (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET)
- Auto-discovery of `Azure.CodeSigning.Dlib.dll` from default install location
[#2](https://github.com/continuous-delphi/delphi-codesign-azure/issues/2)
- Document `metadata.json` setup in README with field descriptions and Azure portal instructions
[#3](https://github.com/continuous-delphi/delphi-codesign-azure/issues/3)
- Document Azure credential environment variables and `.env` file usage in README
[#4](https://github.com/continuous-delphi/delphi-codesign-azure/issues/4)

---

## [0.1.1] 2026-06-09

- Add `-Verify` command: validates Authenticode signatures using `signtool.exe verify /pa /v`
- Auto-discovery of `signtool.exe` from the Windows SDK (latest x64 version)
- Three output formats: `object` (default, pipeline), `text`, `json`
- JSON success/error envelope matching Continuous-Delphi conventions
- `-Version` command with `object`, `text`, `json` formats
- Pre-commit hook for semver auto-increment via `delphi-incver`
[#1](https://github.com/continuous-delphi/delphi-codesign-azure/issues/1)

<br />
<br />

### `delphi-codesign-azure` - a developer tool from Continuous Delphi

![continuous-delphi logo](https://continuous-delphi.github.io/assets/logos/continuous-delphi-480x270.png)

https://github.com/continuous-delphi