#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.0' }
<#
.SYNOPSIS
  Smoke test -- quick green-flag check that delphi-codesign-azure.ps1 is present
  and executes without error.

.DESCRIPTION
  This test is intentionally minimal.  A passing run confirms that the test
  runner, Pester configuration, and source script are all wired up correctly.
  It is not a substitute for the feature-area unit tests.
#>

Describe 'delphi-codesign-azure.ps1 smoke test' {

  BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:scriptPath = Get-ScriptUnderTestPath
  }

  It 'source script exists on disk' {
    Test-Path -LiteralPath $script:scriptPath | Should -Be $true
  }

  It 'version command exits cleanly' {
    $r = Invoke-ToolProcess -ScriptPath $script:scriptPath -Arguments @('-Version')
    $r.ExitCode | Should -Be 0
  }

}
