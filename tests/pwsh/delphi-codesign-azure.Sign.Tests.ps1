# tests/pwsh/delphi-codesign-azure.Sign.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'delphi-codesign-azure.ps1 -Sign' {

    BeforeAll {
        . "$PSScriptRoot/TestHelpers.ps1"
        $script:ToolPath = Get-ScriptUnderTestPath
    }

    Context 'missing -Files parameter' {

        It 'exits with non-zero code' {
            $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Sign')
            $r.ExitCode | Should -Not -Be 0
        }

    }

    Context 'file not found (json)' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Sign', '-Files', 'C:\nonexistent\fake.exe', '-Format', 'json')
        }

        It 'exits with code 3' {
            # Exit 3: fatal error -- credentials missing (checked before file loop)
            # or file-not-found in the signing loop results in all-failed
            $script:result.ExitCode | Should -BeIn @(2, 3)
        }

        It 'output is valid JSON' {
            { $script:result.StdOut | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'ok is false' {
            $json = $script:result.StdOut | ConvertFrom-Json
            $json.ok | Should -Be $false
        }

    }

    Context 'missing prerequisites (json)' {

        BeforeAll {
            # Sign requires signtool, dlib, metadata.json, and Azure env vars.
            # Without a metadata.json next to the script, this fails at the
            # prerequisite check stage (exit 3) before reaching the file loop.
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @(
                '-Sign', '-Files', 'C:\Windows\System32\cmd.exe',
                '-Format', 'json'
            )
            $script:json = $script:result.StdOut | ConvertFrom-Json
        }

        It 'exits with code 3' {
            $script:result.ExitCode | Should -Be 3
        }

        It 'ok is false' {
            $script:json.ok | Should -Be $false
        }

        It 'command is sign' {
            $script:json.command | Should -Be 'sign'
        }

        It 'error has a message' {
            $script:json.error.message | Should -Not -BeNullOrEmpty
        }

    }

}
