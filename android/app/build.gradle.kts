plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vocabkr.vocab_kr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vocabkr.vocab_kr"
        minSdk = flutter.minSdkVersion  // Patrol requires >= 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    buildTypes {
        debug {
            // Side-by-side install with the release build (field-testing
            // workflow 2026-07-19): distinct id + label so a bug seen on the
            // release app can be reproduced on the debug app for its logs,
            // without uninstalling either. Note: separate app = separate
            // local data (fresh login); patrol.toml carries the .debug id.
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "VocabKR Dev"
        }
        release {
            manifestPlaceholders["appLabel"] = "VocabKR"
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 keep rules for JNA/Vosk + gson reflection (see the .pro file):
            // without them the shrinker renames fields those libs resolve by
            // name at runtime, crashing hands-free start (2026-07-08).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
