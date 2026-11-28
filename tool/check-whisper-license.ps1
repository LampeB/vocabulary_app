$ErrorActionPreference = 'Stop'

$enginePath = 'packages/ponderin_whisper/src/whisper.cpp'
$legacyPath = 'packages/whisper_flutter_new'
$expectedRevision = '5eaee0cc9024eb9e9a99469199920c8b7f5cb9ec'

if (Test-Path $legacyPath) {
  throw "GPL wrapper must not be present: $legacyPath"
}

if (-not (Test-Path "$enginePath/LICENSE")) {
  throw "Missing pinned whisper.cpp license at $enginePath/LICENSE"
}

$license = Get-Content -Raw "$enginePath/LICENSE"
if ($license -notmatch 'MIT License') {
  throw 'Pinned whisper.cpp engine is not carrying its expected MIT license.'
}

$submodule = (git submodule status -- $enginePath).Trim()
if (-not $submodule -or $submodule -notmatch "^$expectedRevision(?:\s|$)") {
  throw "whisper.cpp must be pinned to $expectedRevision; found '$submodule'."
}

$pubspec = Get-Content -Raw 'pubspec.yaml'
if ($pubspec -match 'whisper_flutter_new') {
  throw 'pubspec.yaml must not depend on the GPL whisper_flutter_new wrapper.'
}
if ($pubspec -notmatch 'ponderin_whisper:\s*\r?\n\s*path: packages/ponderin_whisper') {
  throw 'pubspec.yaml must use the controlled Ponderin Whisper bridge.'
}

Write-Host 'Whisper license boundary passed.'
