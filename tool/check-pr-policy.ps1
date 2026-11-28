param(
  [switch]$Staged,
  [string]$BaseRef
)

$ErrorActionPreference = 'Stop'

if (-not $Staged -and -not $BaseRef) {
  throw 'Pass -Staged for a pre-commit check or -BaseRef <commit-or-ref> for a PR check.'
}

. "$PSScriptRoot/git-changed-paths.ps1"
$files = @(Get-GitChangedPaths -Staged:$Staged -BaseRef $BaseRef -IncludeDeletions)
# Deletions affect the contract, but deleting a private path is allowed and
# deleted Dart files must not be formatted even if a worktree copy remains.
$introducedFiles = @(Get-GitChangedPaths -Staged:$Staged -BaseRef $BaseRef)
$privacyFiles = $introducedFiles
if (-not $Staged) {
  $privacyFiles += @(Get-GitHistoryPaths -BaseRef $BaseRef)
}

$forbidden = @(
  $privacyFiles | Where-Object {
    $_ -match '(^|/)(ci-apk|build|coverage)/' -or
    $_ -match '\.(apk|aab|ipa)$' -or
    $_ -match '(^|/)(\.env\.json|test.*\.env\.json)$' -or
    $_ -match '^supabase/\.env\.deploy$' -or
    $_ -match '(^|/)\.e2e/' -or
    $_ -match '^tool/stt_corpus/'
  } | Sort-Object -Unique
)
if ($forbidden.Count -gt 0) {
  $displayPaths = ConvertTo-Json -InputObject $forbidden -Compress
  throw "Generated artifacts or private configuration cannot be committed: $displayPaths"
}

if ($files.Count -eq 0) {
  Write-Host 'PR policy guard passed (no relevant files).'
  exit 0
}

if ($Staged) {
  & "$PSScriptRoot/check-documentation.ps1" -Staged
} else {
  & "$PSScriptRoot/check-documentation.ps1" -BaseRef $BaseRef
}

$dartFiles = @(
  $introducedFiles | Where-Object {
    $_ -match '\.dart$' -and (Test-Path -LiteralPath $_) -and
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
