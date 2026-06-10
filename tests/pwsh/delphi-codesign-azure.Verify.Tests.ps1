# tests/pwsh/delphi-codesign-azure.Verify.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'delphi-codesign-azure.ps1 -Verify' {

    BeforeAll {
        . "$PSScriptRoot/TestHelpers.ps1"
        $script:ToolPath = Get-ScriptUnderTestPath
    }

    Context 'file not found' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Verify', '-FilePath', 'C:\nonexistent\fake.exe', '-Format', 'json')
            $script:json = $script:result.StdOut | ConvertFrom-Json
        }

        It 'exits with code 3' {
            $script:result.ExitCode | Should -Be 3
        }

        It 'ok is false' {
            $script:json.ok | Should -Be $false
        }

        It 'command is verify' {
            $script:json.command | Should -Be 'verify'
        }

        It 'error.code is 3' {
            $script:json.error.code | Should -Be 3
        }

        It 'error.message mentions the file' {
            $script:json.error.message | Should -BeLike '*fake.exe*'
        }

    }

    Context 'text format file not found' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Verify', '-FilePath', 'C:\nonexistent\fake.exe', '-Format', 'text')
        }

        It 'exits with code 3' {
            $script:result.ExitCode | Should -Be 3
        }

        It 'reports error on stderr' {
            $script:result.StdErr | Should -Not -BeNullOrEmpty
        }

    }

    Context 'missing -FilePath parameter' {

        It 'exits with non-zero code' {
            $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Verify')
            $r.ExitCode | Should -Not -Be 0
        }

    }

}
