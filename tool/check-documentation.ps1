param(
  [switch]$Staged
)

$ErrorActionPreference = 'Stop'

function Get-TargetFiles {
  if ($Staged) {
    return @(git diff --cached --name-only --diff-filter=ACMR)
  }
  return @(git diff --name-only --diff-filter=ACMR)
}

$files = @(Get-TargetFiles | Where-Object { $_ })
if ($files.Count -eq 0) {
  exit 0
}

$documentationPattern = '^(PROJECT_STATUS\.md|README\.md|TESTS\.md|docs/)'
$contractPattern = '^(lib/|assets/|supabase/|test/|patrol_test/|\.github/workflows/|pubspec\.yaml$|analysis_options\.yaml$|android/|ios/)'
$hasDocumentation = @($files | Where-Object { $_ -match $documentationPattern }).Count -gt 0
$contractFiles = @($files | Where-Object { $_ -match $contractPattern })

if ($contractFiles.Count -gt 0 -and -not $hasDocumentation -and $env:DOCS_EXEMPT -ne '1') {
  Write-Error "Documentation update required for this commit. Changed contract files: $($contractFiles -join ', ')`nUpdate the canonical document (and PROJECT_STATUS.md when delivery status changes), or use DOCS_EXEMPT=1 only for a truly mechanical change with a reason in the commit body."
}

$markdownFiles = @($files | Where-Object { $_ -match '\.md$' -and (Test-Path $_) })
$brokenLinks = @()
foreach ($file in $markdownFiles) {
  $base = Split-Path -Parent (Resolve-Path $file)
  $text = Get-Content -Raw $file
  $matches = [regex]::Matches($text, '\[[^\]]*\]\(([^)#]+)(?:#[^)]+)?\)')
  foreach ($match in $matches) {
    $target = $match.Groups[1].Value.Trim('<>')
    if ($target -and $target -notmatch '^(https?:|mailto:|#)') {
      $resolved = Join-Path $base $target
      if (-not (Test-Path $resolved)) {
        $brokenLinks += "$file -> $target"
      }
    }
  }
}

if ($brokenLinks.Count -gt 0) {
  Write-Error "Broken local Markdown links:`n$($brokenLinks -join "`n")"
}

Write-Host 'Documentation guard passed.'
