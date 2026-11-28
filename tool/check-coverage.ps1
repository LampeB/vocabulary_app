param(
  [double]$Minimum = 47.5,
  [string]$LcovPath = 'coverage/lcov.info'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $LcovPath)) {
  throw "Coverage report not found: $LcovPath"
}

$total = 0
$hit = 0
foreach ($line in Get-Content $LcovPath) {
  if ($line -match '^DA:\d+,(\d+)$') {
    $total++
    if ([int]$Matches[1] -gt 0) {
      $hit++
    }
  }
}

if ($total -eq 0) {
  throw 'Coverage report contains no executable lines.'
}

$percentage = [math]::Round((100 * $hit / $total), 1)
Write-Host "Total line coverage: $percentage% ($hit/$total)"
if ($percentage -lt $Minimum) {
  throw "Line coverage $percentage% fell below the $Minimum% floor."
}
