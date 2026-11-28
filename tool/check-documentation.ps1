param(
  [switch]$Staged,
  [string]$BaseRef
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/git-changed-paths.ps1"
$files = @(Get-GitChangedPaths -Staged:$Staged -BaseRef $BaseRef -IncludeDeletions)
if ($files.Count -eq 0) {
  exit 0
}

$documentationPattern = '^(PROJECT_STATUS\.md|README\.md|TESTS\.md|docs/)'
$contractPattern = '^(lib/|assets/|supabase/|test/|patrol_test/|tool/|packages/ponderin_whisper/|\.github/|\.githooks/|\.codex/|\.agents/|android/|ios/|pubspec\.(yaml|lock)$|analysis_options\.yaml$|patrol\.toml$|build_release\.ps1$|run_tests\.ps1$|\.git(ignore|attributes|modules)$|\.metadata$)'
$hasDocumentation = @($files | Where-Object { $_ -match $documentationPattern }).Count -gt 0
$contractFiles = @($files | Where-Object { $_ -match $contractPattern })

if ($contractFiles.Count -gt 0 -and -not $hasDocumentation -and $env:DOCS_EXEMPT -ne '1') {
  Write-Error "Documentation update required for this commit. Changed contract files: $($contractFiles -join ', ')`nUpdate the canonical document (and PROJECT_STATUS.md when delivery status changes), or use DOCS_EXEMPT=1 only for a truly mechanical change with a reason in the commit body."
}

function Get-IndexedEntries {
  $entries = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
  foreach ($entry in @(Invoke-GitPathQuery 'ls-files --stage -z')) {
    if ($entry -match '^(?<mode>[0-7]+) (?<oid>[0-9a-f]{40}|[0-9a-f]{64}) 0\t(?<path>[\s\S]+)$') {
      $entries[$Matches.path] = [pscustomobject]@{ Mode = $Matches.mode; Oid = $Matches.oid }
    }
  }
  return ,$entries
}

function Test-IndexedTarget {
  param([string]$Document, [string]$Target)

  $directory = Join-Path $repositoryRoot (Split-Path -Parent $Document)
  $absolute = [System.IO.Path]::GetFullPath((Join-Path $directory $Target))
  $comparison = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    [System.StringComparison]::OrdinalIgnoreCase
  } else { [System.StringComparison]::Ordinal }
  if ($absolute.Equals($repositoryRoot, $comparison)) { return $index.Count -gt 0 }
  if (-not $absolute.StartsWith($repositoryPrefix, $comparison)) { return $false }
  $relative = $absolute.Substring($repositoryPrefix.Length).Replace('\', '/').TrimEnd('/')
  if ($index.ContainsKey($relative)) { return $true }
  foreach ($path in $index.Keys) {
    if ($path.StartsWith("$relative/", [System.StringComparison]::Ordinal)) { return $true }
    if ($index[$path].Mode -eq '160000' -and
        $relative.StartsWith("$path/", [System.StringComparison]::Ordinal)) {
      # A gitlink's contents belong to its pinned commit, not the parent index.
      if (-not $submodulePaths.ContainsKey($path)) {
        $oid = $index[$path].Oid
        $moduleRoot = Join-Path $repositoryRoot $path
        $tree = Invoke-GitTextQuery "ls-tree -r --name-only -z $oid" -WorkingDirectory $moduleRoot
        $submodulePaths[$path] = @($tree.Split([char[]]@([char]0), [System.StringSplitOptions]::RemoveEmptyEntries))
      }
      $child = $relative.Substring($path.Length + 1)
      foreach ($item in $submodulePaths[$path]) {
        if ($item -ceq $child -or $item.StartsWith("$child/", [System.StringComparison]::Ordinal)) { return $true }
      }
    }
  }
  return $false
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Invoke-GitTextQuery 'rev-parse --show-toplevel').TrimEnd([char[]]"`r`n"))
$repositoryPrefix = $repositoryRoot.TrimEnd([char[]]'\/') + [System.IO.Path]::DirectorySeparatorChar
if ($Staged) {
  $index = Get-IndexedEntries
  $submodulePaths = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
}
$markdownFiles = @($files | Where-Object {
  $_ -match '\.md$' -and $(if ($Staged) { $index.ContainsKey($_) } else {
    Test-Path -LiteralPath (Join-Path $repositoryRoot $_)
  })
})
$brokenLinks = @()
foreach ($file in $markdownFiles) {
  if ($Staged) {
    $oid = $index[$file].Oid
    $text = Invoke-GitTextQuery "cat-file blob $oid"
  } else {
    $text = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot $file)
  }
  $base = Join-Path $repositoryRoot (Split-Path -Parent $file)
  $matches = [regex]::Matches($text, '\[[^\]]*\]\(([^)#]+)(?:#[^)]+)?\)')
  foreach ($match in $matches) {
    $target = $match.Groups[1].Value.Trim('<>')
    if ($target -and $target -notmatch '^(https?:|mailto:|#)') {
      $target = [System.Uri]::UnescapeDataString($target)
      $exists = if ($Staged) { Test-IndexedTarget $file $target } else {
        Test-Path -LiteralPath (Join-Path $base $target)
      }
      if (-not $exists) {
        $brokenLinks += "$file -> $target"
      }
    }
  }
}

if ($brokenLinks.Count -gt 0) {
  Write-Error "Broken local Markdown links:`n$($brokenLinks -join "`n")"
}

Write-Host 'Documentation guard passed.'
