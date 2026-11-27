param(
  [switch]$Staged,
  [string]$BaseRef
)

$ErrorActionPreference = 'Stop'

if (-not $Staged -and -not $BaseRef) {
  throw 'Pass -Staged for a pre-commit check or -BaseRef <commit-or-ref> for a PR check.'
}

function Get-TargetFiles {
  if ($Staged) {
    return @(git diff --cached --name-only --diff-filter=ACMR)
  }

  $baseCommit = (git merge-base $BaseRef HEAD).Trim()
  if (-not $baseCommit) {
    throw "Unable to find a merge base with '$BaseRef'."
  }
  return @(git diff --name-only --diff-filter=ACMR "$baseCommit...HEAD")
}

$files = @(Get-TargetFiles | Where-Object { $_ })
if ($files.Count -eq 0) {
  Write-Host 'PR policy guard passed (no relevant files).'
  exit 0
}

if ($Staged) {
  & "$PSScriptRoot/check-documentation.ps1" -Staged
} else {
  & "$PSScriptRoot/check-documentation.ps1" -BaseRef $BaseRef
}

$forbidden = @(
  $files | Where-Object {
    $_ -match '(^|/)(ci-apk|build|coverage)/' -or
    $_ -match '\.(apk|aab|ipa)$' -or
    $_ -match '(^|/)(\.env\.json|test.*\.env\.json)$' -or
    $_ -match '(^|/)\.e2e/' -or
    $_ -match '^tool/stt_corpus/'
  }
)
if ($forbidden.Count -gt 0) {
  throw "Generated artifacts or private configuration cannot be committed:`n$($forbidden -join "`n")"
}

$dartFiles = @(
  $files | Where-Object {
    $_ -match '\.dart$' -and (Test-Path $_) -and
    ($_ -notmatch '^packages/' -or $_ -match '^packages/ponderin_whisper/lib/')
  }
)
if ($dartFiles.Count -gt 0) {
  # Keep Windows command lines below their limit on large integration PRs.
  for ($offset = 0; $offset -lt $dartFiles.Count; $offset += 50) {
    $batch = @($dartFiles | Select-Object -Skip $offset -First 50)
    & dart format --output=none --set-exit-if-changed @batch
    if ($LASTEXITCODE -ne 0) {
      throw 'Dart formatting is required for every changed first-party Dart file.'
    }
  }
}

Write-Host 'PR policy guard passed.'
