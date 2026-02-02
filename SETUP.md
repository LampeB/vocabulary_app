# VocabularyApp - Setup Guide

This guide explains how to set up the VocabularyApp project on a new machine using the automated installer scripts.

---

## Quick Start

### Option 1: Smart Automated Installation (Any Machine)

The script intelligently detects what's already installed and only installs what's missing:

```powershell
# Run the script (admin only required if installations needed)
.\setup-project.ps1
```

**Smart Features:**
- 🔍 Automatically detects existing installations (Flutter, JDK, Android Studio, Appium)
- ✅ Only installs what's missing
- ⚡ If everything is installed, just updates project dependencies (fast!)
- 🔒 Only requires admin privileges if installations are needed
- 📊 Shows installation plan before proceeding
- ✨ Works on any Windows computer

**What it does:**
- ✅ Checks for existing Flutter SDK, JDK, Android Studio, Appium
- ✅ Downloads and installs only missing components
- ✅ Configures PATH environment variables
- ✅ Installs all project dependencies
- ✅ Verifies final installation

**Time:**
- ~2 minutes if everything already installed
- ~30-45 minutes for fresh installation (depending on internet speed)

### Option 2: Install Dependencies Only (Existing Setup)

If you already have Flutter, JDK, and Android Studio installed:

```powershell
# No admin required
.\install-dependencies.ps1
```

This will:
- ✅ Install Flutter packages (flutter pub get)
- ✅ Install Appium test dependencies (npm install)
- ✅ Optionally install Appium globally

**Time:** ~2-5 minutes

---

## Prerequisites

### For Smart Installation (setup-project.ps1)
- ✅ Windows 10/11
- ✅ Administrator privileges (only if installations needed)
- ✅ ~15 GB free disk space (for fresh installations)
- ✅ Stable internet connection
- ⚠️ **Node.js must be installed first** (the script checks for it and will alert you if missing)

**Note:** The script will tell you exactly what needs to be installed and whether admin privileges are required before proceeding.

### For Dependencies Only (install-dependencies.ps1)
- ✅ Flutter SDK installed and in PATH
- ✅ Node.js and npm installed
- ✅ Internet connection

---

## How Smart Detection Works

The installer script now includes intelligent detection that checks for existing installations:

### What It Checks

| Tool | Detection Method |
|------|------------------|
| **Node.js** | Checks `node` command in PATH + version check |
| **Flutter** | Checks PATH and `C:\Development\flutter` directory |
| **Java JDK** | Checks `java` command + common installation paths |
| **Android Studio** | Checks Program Files and AppData directories |
| **Appium** | Checks `appium` command in PATH |

### Smart Behavior

1. **Detection Phase:**
   - Script checks all required tools
   - Shows what's installed ✓ and what's missing ✗
   - Creates installation plan

2. **Admin Check:**
   - Only requests admin if installations are needed
   - If everything installed, runs without admin

3. **Installation Phase:**
   - Only downloads/installs missing components
   - Skips already-installed tools
   - Configures PATH only if needed

4. **Example Scenarios:**

   **Scenario A:** Fresh machine (nothing installed)
   ```
   Checking what's already installed...
   ✗ Flutter needs to be installed
   ✗ Java JDK needs to be installed
   ✗ Android Studio needs to be installed
   ✗ Appium needs to be installed

   INSTALLATION PLAN:
   • Flutter SDK
   • Java JDK 21
   • Android Studio
   • Appium + Flutter Driver
   ```

   **Scenario B:** Partial installation (Flutter already installed)
   ```
   Checking what's already installed...
   ✓ Flutter already installed: Flutter 3.24.5
   ✗ Java JDK needs to be installed
   ✗ Android Studio needs to be installed
   ✗ Appium needs to be installed

   INSTALLATION PLAN:
   • Java JDK 21
   • Android Studio
   • Appium + Flutter Driver
   ```

   **Scenario C:** Everything installed
   ```
   Checking what's already installed...
   ✓ Node.js v22.17.1 and npm 10.9.2 already installed
   ✓ Flutter already installed: Flutter 3.24.5
   ✓ Java JDK already installed: version "21.0.5"
   ✓ Android Studio found at C:\Program Files\Android\Android Studio
   ✓ Appium already installed: v2.11.5

   ✓ ALL REQUIRED TOOLS ALREADY INSTALLED!
   Skipping to project dependencies installation...
   ```

---

## Detailed Instructions

### Full Installation Steps

1. **Ensure Node.js is installed**
   ```powershell
   node --version  # Should show v18+
   npm --version
   ```
   If not installed, download from: https://nodejs.org/

2. **Open PowerShell as Administrator**
   - Right-click PowerShell → "Run as Administrator"

3. **Navigate to project directory**
   ```powershell
   cd C:\path\to\vocabulary_app
   ```

4. **Run the setup script**
   ```powershell
   .\setup-project.ps1
   ```

5. **Follow the prompts**
   - The script will ask for confirmation before starting
   - Installation progress will be displayed
   - Takes 30-45 minutes depending on internet speed

6. **After installation completes:**
   - ⚠️ **RESTART your terminal/PowerShell** (required for PATH changes)
   - Run `flutter doctor` to verify installation
   - Open Android Studio and complete the setup wizard
   - Accept Android licenses: `flutter doctor --android-licenses`

### Quick Dependencies Installation

If Flutter and other tools are already set up:

```powershell
.\install-dependencies.ps1
```

This is much faster (~2-5 minutes) and doesn't require administrator privileges.

---

## What Gets Installed

### System Tools (setup-project.ps1)

| Tool | Version | Install Location |
|------|---------|------------------|
| **Flutter SDK** | 3.24.5 (stable) | `C:\Development\flutter` |
| **Java JDK** | OpenJDK 21 | System default |
| **Android Studio** | 2024.2.1 | System default |
| **Appium** | Latest | Global npm package |
| **Appium Flutter Driver** | Latest | Appium plugin |

### Project Dependencies (Both Scripts)

**Flutter Packages** (from [pubspec.yaml](pubspec.yaml)):
- sqflite, path_provider (database)
- provider (state management)
- audioplayers, flutter_tts, speech_to_text (audio/speech)
- http, uuid, crypto, csv (utilities)
- mockito, flutter_driver (testing)

**Appium Test Packages** (from [appium-tests/package.json](appium-tests/package.json)):
- @cucumber/cucumber (BDD testing)
- appium-flutter-driver, appium-flutter-finder
- webdriverio, chai
- TypeScript, ts-node

---

## Script Options

### setup-project.ps1 Parameters

Skip specific installations if already present:

```powershell
# Skip Flutter installation
.\setup-project.ps1 -SkipFlutter

# Skip JDK installation
.\setup-project.ps1 -SkipJDK

# Skip Android Studio installation
.\setup-project.ps1 -SkipAndroidStudio

# Skip Appium installation
.\setup-project.ps1 -SkipAppium

# Combine multiple skips
.\setup-project.ps1 -SkipFlutter -SkipJDK
```

---

## Troubleshooting

### "Running scripts is disabled on this system"

Run this command in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Command not found" after installation

**Solution:** Restart your terminal/PowerShell window. PATH changes require a new session.

### Flutter doctor shows errors

**Common issues:**

1. **Android licenses not accepted**
   ```powershell
   flutter doctor --android-licenses
   ```

2. **Android SDK not found**
   - Open Android Studio
   - Go to Settings → Appearance & Behavior → System Settings → Android SDK
   - Install Android SDK Platform and Build Tools

3. **cmdline-tools component is missing**
   - Open Android Studio → SDK Manager
   - SDK Tools tab → Check "Android SDK Command-line Tools"
   - Click Apply

### Downloads fail

**Solutions:**
- Check internet connection
- Try running the script again (it will skip already installed components)
- Download manually from URLs in the script and install

### Appium tests fail

**Check:**
1. Appium server is running: `appium`
2. Android emulator/device is connected: `flutter devices`
3. App is built with Appium support: `flutter build apk --debug --target=lib/main_appium.dart`

---

## Manual Installation (Alternative)

If the automated scripts don't work, you can install manually:

### 1. Install Flutter
```powershell
# Download from: https://flutter.dev/docs/get-started/install/windows
# Extract to C:\Development\flutter
# Add to PATH: C:\Development\flutter\bin
```

### 2. Install Java JDK
```powershell
# Download from: https://adoptium.net/
# Run installer
```

### 3. Install Android Studio
```powershell
# Download from: https://developer.android.com/studio
# Run installer
# Complete setup wizard
```

### 4. Install Project Dependencies
```powershell
flutter pub get
cd appium-tests
npm install
npm install -g appium
appium driver install flutter
```

---

## Verification

After installation, verify everything is working:

```powershell
# Check Flutter
flutter doctor -v

# Check versions
flutter --version
dart --version
java -version
node --version
npm --version
appium --version

# Run tests
flutter test

# Run the app
flutter run
```

Expected output of `flutter doctor`:
```
[✓] Flutter (Channel stable, 3.24.5, on Microsoft Windows)
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] Visual Studio - develop Windows apps
[✓] Android Studio
[✓] VS Code
[✓] Connected device
[✓] Network resources
```

---

## Updating Dependencies

To update project dependencies after pulling new code:

```powershell
# Update Flutter packages
flutter pub get
flutter pub upgrade

# Update Appium test packages
cd appium-tests
npm install
npm update
```

---

## Uninstallation

To remove installed components:

### Remove Flutter
```powershell
Remove-Item -Recurse -Force C:\Development\flutter
# Manually remove from PATH via System Environment Variables
```

### Remove JDK
- Control Panel → Programs → Uninstall "Eclipse Temurin JDK"

### Remove Android Studio
- Control Panel → Programs → Uninstall "Android Studio"

### Remove Appium
```powershell
npm uninstall -g appium
```

---

## Project Structure

```
vocabulary_app/
├── setup-project.ps1           # Full installation script (NEW)
├── install-dependencies.ps1    # Dependencies only script (NEW)
├── SETUP.md                    # This file (NEW)
├── pubspec.yaml                # Flutter dependencies
├── lib/                        # Source code
├── test/                       # Unit tests
├── integration_test/           # Integration tests
├── appium-tests/               # E2E tests
│   ├── package.json           # Appium test dependencies
│   └── README.md              # Appium setup guide
├── android/                    # Android platform
├── ios/                        # iOS platform
├── windows/                    # Windows platform
└── ...
```

---

## Next Steps After Setup

1. **Configure ElevenLabs API (Optional)**
   - Edit [lib/config/ApiConfig.dart](lib/config/ApiConfig.dart)
   - Add your API key for text-to-speech features

2. **Read the Documentation**
   - [README.md](README.md) - Project overview
   - [ETAT_DES_LIEUX.md](ETAT_DES_LIEUX.md) - Detailed project analysis
   - [TESTING.md](TESTING.md) - Testing guide
   - [appium-tests/README.md](appium-tests/README.md) - Appium testing guide

3. **Run the App**
   ```powershell
   flutter run              # Run on connected device
   flutter run -d windows   # Run on Windows
   flutter run -d chrome    # Run on web
   ```

4. **Build for Production**
   ```powershell
   flutter build apk        # Android APK
   flutter build windows    # Windows executable
   ```

---

## Support

- **Flutter Issues:** https://flutter.dev/docs/get-started/install/windows
- **Android Studio Issues:** https://developer.android.com/studio/troubleshoot
- **Appium Issues:** https://appium.io/docs/en/latest/

---

## Script Maintenance

### Updating Download URLs

The scripts use specific version URLs. To update to newer versions, edit [setup-project.ps1](setup-project.ps1):

```powershell
# Find latest Flutter: https://docs.flutter.dev/release/archive
$FLUTTER_URL = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_X.X.X-stable.zip"

# Find latest JDK: https://adoptium.net/temurin/releases/
$JDK_URL = "https://github.com/adoptium/temurin21-binaries/releases/download/..."

# Find latest Android Studio: https://developer.android.com/studio
$ANDROID_STUDIO_URL = "https://redirector.gvt1.com/edgedl/android/studio/install/..."
```

---

## License

This setup script is part of the VocabularyApp project.

---

**Happy Coding! 🚀**
