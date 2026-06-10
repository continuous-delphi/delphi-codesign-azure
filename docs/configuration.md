# Configuration

`delphi-codesign-azure` loads configuration from multiple sources with
increasing priority. Higher-priority sources override lower ones.

## Configuration File Hierarchy

```
$HOME/delphi-codesign-azure.json              lowest priority (user-level defaults)
<ancestors>/delphi-codesign-azure.json        traversed parents (if searchParentFolders)
<RootPath>/delphi-codesign-azure.json         project-level (committed to repo)
<RootPath>/delphi-codesign-azure.local.json   local overrides (gitignored)
-ConfigFile <path>                       explicit CI override
CLI parameters                           highest priority
```

## JSON Format

All keys are optional. Unrecognized keys are ignored.

```json
{
  "outputLevel": "detailed",
  "searchParentFolders": false
}
```

<!-- Add tool-specific config keys here -->

## Merge Rules

| Type | Behavior |
|------|----------|
| Scalar (string, number, bool) | Last writer wins -- highest-priority source overrides |
| Array | Append + deduplicate by first occurrence across all sources |

## Upward Traversal (Monorepo Support)

When `searchParentFolders` is `true` in a project-level or local config,
the tool walks parent directories collecting `delphi-codesign-azure.json` files.
Traversal stops when:

1. The filesystem root is reached, or
2. A config file with `"searchParentFolders": false` is found (stop marker)

The file nearest to `-RootPath` has highest priority among traversed files.

## `-ShowConfig`

Use `-ShowConfig` to inspect the effective merged configuration:

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -ShowConfig
pwsh -File source/delphi-codesign-azure.ps1 -ShowConfig -Json
```

## `-ConfigFile`

Inject an explicit config file (useful in CI pipelines):

```powershell
pwsh -File source/delphi-codesign-azure.ps1 -ConfigFile ci/delphi-codesign-azure-ci.json
```

This file is loaded at the highest priority below CLI parameters.
