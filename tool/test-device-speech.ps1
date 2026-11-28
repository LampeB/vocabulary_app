$ErrorActionPreference = 'Stop'

$project = Split-Path -Parent $PSScriptRoot
$wrapper = Join-Path $project 'android/gradle/wrapper/gradle-wrapper.properties'
$distribution = Select-String -LiteralPath $wrapper -Pattern '^distributionUrl=.*[/\\](gradle-.+)-(bin|all)\.zip\s*$'
if (-not $distribution) {
    throw "Cannot read the pinned Gradle version from $wrapper."
}
$gradleFolder = $distribution.Matches[0].Groups[1].Value
$distributionFolder = $distribution.Matches[0].Groups[2].Value
$gradleHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $HOME '.gradle' }
$cachedDistribution = Join-Path $gradleHome "wrapper/dists/$gradleFolder-$distributionFolder"
$compiler = if (Test-Path -LiteralPath $cachedDistribution -PathType Container) {
    Get-ChildItem -LiteralPath $cachedDistribution -Directory | ForEach-Object {
        $lib = Join-Path $_.FullName "$gradleFolder/lib"
        if (Test-Path -LiteralPath $lib -PathType Container) {
            Get-ChildItem -LiteralPath $lib -Filter 'kotlin-compiler-embeddable-*.jar' -File
        }
    } | Select-Object -First 1
}
if (-not $compiler) {
    throw "No Kotlin compiler found in the pinned Gradle distribution at '$cachedDistribution'. Run the Android build to initialize the Gradle wrapper first."
}
$gradleLib = $compiler.Directory.FullName
$stdlibName = $compiler.Name.Replace('kotlin-compiler-embeddable-', 'kotlin-stdlib-')
$stdlib = Join-Path $gradleLib $stdlibName
if (-not (Test-Path -LiteralPath $stdlib -PathType Leaf)) {
    throw "Kotlin standard library '$stdlib' is missing from the pinned Gradle distribution."
}

$javaName = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'java.exe' } else { 'java' }
$java = if ($env:JAVA_HOME) {
    Join-Path $env:JAVA_HOME "bin/$javaName"
} else {
    (Get-Command $javaName -CommandType Application).Source
}
$production = Join-Path $project 'android/app/src/main/kotlin/com/vocabkr/vocab_kr/DeviceSpeech.kt'
$fixtureDir = Join-Path $PSScriptRoot 'native-tests/device-speech'
$sources = @(Get-ChildItem -LiteralPath $fixtureDir -Filter '*.kt' -File | ForEach-Object FullName)
$probeJar = Join-Path ([IO.Path]::GetTempPath()) "device-speech-$([Guid]::NewGuid()).jar"
$runtimeClasspath = $probeJar + [IO.Path]::PathSeparator + $stdlib

try {
    & $java -cp "$gradleLib/*" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -nowarn -no-stdlib -no-reflect -classpath $stdlib -d $probeJar $production @sources
    if ($LASTEXITCODE -ne 0) { throw "DeviceSpeech JVM compilation failed (exit $LASTEXITCODE)." }
    & $java -cp $runtimeClasspath com.vocabkr.vocab_kr.ProbeKt
    if ($LASTEXITCODE -ne 0) { throw "DeviceSpeech JVM probe failed (exit $LASTEXITCODE)." }
} finally {
    if (Test-Path -LiteralPath $probeJar -PathType Leaf) {
        Remove-Item -LiteralPath $probeJar
    }
}
