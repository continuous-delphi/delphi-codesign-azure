# tests/pwsh/delphi-TOOLNAME.Version.Tests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'delphi-TOOLNAME.ps1 -Version' {

    BeforeAll {
        . "$PSScriptRoot/TestHelpers.ps1"
        $script:ToolPath = Get-ScriptUnderTestPath

        if (-not (Test-Path -LiteralPath $script:ToolPath)) {
            throw "Tool script not found: $script:ToolPath"
        }
    }

    Context 'text format (default)' {

        BeforeAll {
            $script:result = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version')
        }

        It 'exits with code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'outputs a single line' {
            $script:result.StdOut.Count | Should -Be 1
        }

        It 'output contains the tool name' {
            $script:result.StdOut[0] | Should -BeLike '*delphi-TOOLNAME*'
        }

        It 'output contains the version number' {
            $script:result.StdOut[0] | Should -Match '\d+\.\d+\.\d+'
        }

        It 'produces the same output with -Format text' {
            $explicit = Invoke-ToolProcess -ScriptPath $script:ToolPath -Arguments @('-Version', '-Format', 'text')
            $explicit.StdOut[0] | Should -Be $script:result.StdOut[0]
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

        It 'tool.name is delphi-TOOLNAME' {
            $script:json.tool.name | Should -Be 'delphi-TOOLNAME'
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
