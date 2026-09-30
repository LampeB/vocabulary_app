$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repositoryRoot
try {
  git rev-parse --is-inside-work-tree | Out-Null
  git config core.hooksPath .githooks
  Write-Host 'Installed versioned Git hooks from .githooks/.'
  Write-Host 'Verify with: git config --get core.hooksPath'
} finally {
  Pop-Location
}
