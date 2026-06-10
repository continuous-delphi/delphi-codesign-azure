# TestHelpers.ps1
# Shared setup for delphi-TOOLNAME Pester tests.
#
# Dot-source this file inside each Describe-level BeforeAll:
#   BeforeAll {
#     . "$PSScriptRoot/TestHelpers.ps1"
#   }
#
# Provides:
#   Get-ScriptUnderTestPath  - absolute path to delphi-TOOLNAME.ps1
#   Invoke-ToolProcess       - runs a .ps1 as a child process and returns
#                              [pscustomobject]@{ ExitCode; StdOut; StdErr }
#                              Optional -Shell parameter selects the host
#                              executable (default: 'pwsh').

function Get-ScriptUnderTestPath {
  $path = Join-Path $PSScriptRoot '..\..\source\delphi-TOOLNAME.ps1'
  return [System.IO.Path]::GetFullPath($path)
}

function Invoke-ToolProcess {
  param(
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [Parameter()][string[]]$Arguments = @(),
    [Parameter()][string]$Shell = 'pwsh',
    [Parameter()][string]$ExecutionPolicy = ''
  )

  $shellArgs = @('-NoProfile', '-NonInteractive')
  if ($ExecutionPolicy) { $shellArgs += @('-ExecutionPolicy', $ExecutionPolicy) }
  $shellArgs += @('-File', $ScriptPath)

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $Shell
  foreach ($a in $shellArgs + $Arguments) {
    [void]$psi.ArgumentList.Add($a)
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()

  $stdoutTask = $p.StandardOutput.ReadToEndAsync()
  $stderrTask = $p.StandardError.ReadToEndAsync()
  $p.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()

  [pscustomobject]@{
    ExitCode = $p.ExitCode
    StdOut   = @($stdout -split '\r?\n' | Where-Object { $_ -ne '' })
    StdErr   = @($stderr -split '\r?\n' | Where-Object { $_ -ne '' })
  }
}
