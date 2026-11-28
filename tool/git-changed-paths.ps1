function Get-GitChangedPaths {
  param([switch]$Staged, [string]$BaseRef, [switch]$IncludeDeletions)

  $arguments = 'diff --name-only -z --no-relative --diff-filter=ACMR'
  if ($IncludeDeletions) { $arguments += 'D' }
  if ($Staged) {
    $arguments += ' --cached'
  } elseif ($BaseRef) {
    $baseCommit = git merge-base -- $BaseRef HEAD
    if ($LASTEXITCODE -ne 0 -or $baseCommit -cnotmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
      throw "Unable to find a merge base with '$BaseRef'."
    }
    $arguments += " $baseCommit...HEAD"
  }
  Invoke-GitPathQuery $arguments
}

function Get-GitHistoryPaths {
  param([Parameter(Mandatory)][string]$BaseRef)

  $baseCommit = git rev-parse --verify --end-of-options "${BaseRef}^{commit}"
  if ($LASTEXITCODE -ne 0 -or $baseCommit -cnotmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
    throw "Unable to resolve base commit '$BaseRef'."
  }
  # Ordinary commits expose their individual changes. Merge commits also
  # expose changes made against all parents during the merge itself.
  Invoke-GitPathQuery "log --format= --no-show-signature --name-only -z --no-relative --diff-filter=ACMR --no-renames --diff-merges=combined $baseCommit..HEAD --"
}

function Invoke-GitPathQuery {
  param([string]$Arguments)

  $paths = Invoke-GitTextQuery $Arguments
  return $paths.Split([char[]]@([char]0), [System.StringSplitOptions]::RemoveEmptyEntries)
}

function Invoke-GitTextQuery {
  param([string]$Arguments, [string]$WorkingDirectory = (Get-Location).ProviderPath)

  # Read the native byte stream so PowerShell does not split filenames on LF.
  # ProcessStartInfo.Arguments also works on Windows PowerShell 5.1. Only a
  # validated object ID can be appended to the fixed arguments above.
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new('git', $arguments)
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $bytes = [System.IO.MemoryStream]::new()
  try {
    $process.StandardOutput.BaseStream.CopyTo($bytes)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      throw 'Unable to read changed paths from Git.'
    }
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    return $utf8.GetString($bytes.ToArray())
  } finally {
    $bytes.Dispose()
    $process.Dispose()
  }
}
