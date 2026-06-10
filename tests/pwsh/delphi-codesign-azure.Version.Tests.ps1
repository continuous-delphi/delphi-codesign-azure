# tests/pwsh/delphi-codesign-azure.Version.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'delphi-codesign-azure.ps1 -Version' {

    BeforeAll {
        . "$PSScriptRoot/TestHelpers.ps1"
        $script:ToolPath = Get-ScriptUnderTestPath

        if (-not (Test-Path -LiteralPath $script:ToolPath)) {
            throw "Tool script not found: $script:ToolPath"
        }
    }

    Context 'object format (default)' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version')
        }

        It 'exits with code 0' {
            $script:result.ExitCode | Should -Be 0
        }

    }

    Context 'text format' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version', '-Format', 'text')
        }

        It 'exits with code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'outputs a single line' {
            $script:result.StdOut.Count | Should -Be 1
        }

        It 'output contains the tool name' {
            $script:result.StdOut[0] | Should -BeLike '*delphi-codesign-azure*'
        }

        It 'output contains the version number' {
            $script:result.StdOut[0] | Should -Match '\d+\.\d+\.\d+'
        }

    }

    Context 'json format' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version', '-Format', 'json')
            $script:json = $script:result.StdOut | ConvertFrom-Json
        }

        It 'exits with code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'output is valid JSON' {
            { $script:result.StdOut | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'ok field is true' {
            $script:json.ok | Should -Be $true
        }

        It 'command field is version' {
            $script:json.command | Should -Be 'version'
        }

        It 'tool.name is delphi-codesign-azure' {
            $script:json.tool.name | Should -Be 'delphi-codesign-azure'
        }

        It 'tool.version matches a semver pattern' {
            $script:json.tool.version | Should -Match '^\d+\.\d+\.\d+$'
        }

    }

    Context 'mutual exclusion with main parameters' {

        It 'rejects -RootPath with -Version' {
            $r = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version', '-RootPath', 'C:\Fake')
            $r.ExitCode | Should -Not -Be 0
        }

    }

}
