$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repositoryRoot
try {
  git rev-parse --is-inside-work-tree | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Unable to identify the Git worktree.' }
  if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    chmod +x .githooks/pre-commit
    if ($LASTEXITCODE -ne 0) { throw 'Unable to make the pre-commit hook executable.' }
  }
  git config core.hooksPath .githooks
  if ($LASTEXITCODE -ne 0) { throw 'Unable to set the Git hooks path.' }
  Write-Host 'Installed versioned Git hooks from .githooks/.'
  Write-Host 'Verify with: git config --get core.hooksPath'
} finally {
  Pop-Location
}
