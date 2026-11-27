function Get-GitChangedPaths {
  param([switch]$Staged, [string]$BaseRef)

  $arguments = 'diff --name-only -z --no-relative --diff-filter=ACMR'
  if ($Staged) {
    $arguments += ' --cached'
  } elseif ($BaseRef) {
    $baseCommit = git merge-base -- $BaseRef HEAD
    if ($LASTEXITCODE -ne 0 -or $baseCommit -cnotmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
      throw "Unable to find a merge base with '$BaseRef'."
    }
    $arguments += " $baseCommit...HEAD"
  }

  # Read the native byte stream so PowerShell does not split filenames on LF.
  # ProcessStartInfo.Arguments also works on Windows PowerShell 5.1. Only a
  # validated object ID can be appended to the fixed arguments above.
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new('git', $arguments)
  $startInfo.WorkingDirectory = (Get-Location).ProviderPath
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $bytes = [System.IO.MemoryStream]::new()
  try {
    $process.StandardOutput.BaseStream.CopyTo($bytes)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      throw 'Unable to read changed paths from git diff.'
    }
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $paths = $utf8.GetString($bytes.ToArray())
    return $paths.Split([char[]]@([char]0), [System.StringSplitOptions]::RemoveEmptyEntries)
  } finally {
    $bytes.Dispose()
    $process.Dispose()
  }
}
