# Guide Complet - Lancer les Tests Appium

## 🚀 MÉTHODE RAPIDE (Recommandée)

### Option 1 : Double-clic
Double-clique sur **`LANCER-TESTS.bat`** dans le dossier `appium-tests`

### Option 2 : PowerShell
```powershell
cd E:\Projects\Quiz\appium-tests
.\run-all.ps1
```

**C'est tout !** Le script va automatiquement :
1. ✅ Vérifier que l'émulateur est lancé
2. ✅ Construire l'APK si nécessaire
3. ✅ Démarrer Appium
4. ✅ Lancer les tests
5. ✅ Ouvrir le screenshot en cas d'échec

---

## 📋 Prérequis

Avant de lancer le script :
- ✅ **Émulateur Android lancé** (via Android Studio)
- ✅ Android Studio installé
- ✅ Node.js v22+ installé
- ✅ Flutter installé

---

## 📖 MÉTHODE MANUELLE (Si le script ne fonctionne pas)

### ÉTAPE 1 : Préparer l'Application Flutter

### 1.1 Ouvrir un terminal dans le dossier de l'app

```powershell
cd E:\Projects\Quiz\vocabulary_app
```

### 1.2 Nettoyer et récupérer les dépendances

```powershell
flutter clean
flutter pub get
```

### 1.3 Construire l'APK de test

**IMPORTANT** : On utilise `--target lib/main_appium.dart` pour activer Flutter Driver !

```powershell
flutter build apk --debug --target lib/main_appium.dart
```

L'APK sera créé ici :
```
E:\Projects\Quiz\vocabulary_app\build\app\outputs\flutter-apk\app-debug.apk
```

---

## ÉTAPE 2 : Démarrer l'Émulateur Android

### 2.1 Lancer l'émulateur

Tu peux le faire via Android Studio ou en ligne de commande :

```powershell
# Lister les émulateurs disponibles
emulator -list-avds

# Lancer un émulateur (remplace le nom par celui de ton émulateur)
emulator -avd Pixel_4_API_30
```

### 2.2 Vérifier que l'émulateur est connecté

```powershell
adb devices
```

Tu dois voir quelque chose comme :
```
List of devices attached
emulator-5554   device
```

---

## ÉTAPE 3 : Configurer les Variables d'Environnement

Ouvre PowerShell et exécute ces commandes (à faire à chaque nouvelle session PowerShell) :

```powershell
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

---

## ÉTAPE 4 : Démarrer Appium Server

### 4.1 Ouvrir un NOUVEAU terminal PowerShell

### 4.2 Configurer les variables d'environnement (même chose)

```powershell
$env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

### 4.3 Aller dans le dossier des tests

```powershell
cd E:\Projects\Quiz\appium-tests
```

### 4.4 Lancer Appium

```powershell
appium
```

**Attendre ce message** :
```
[Appium] Welcome to Appium v3.x.x
[Appium] Appium REST http interface listener started on http://0.0.0.0:4723
```

**⚠️ GARDE CE TERMINAL OUVERT !** Appium doit rester en cours d'exécution.

---

## ÉTAPE 5 : Lancer les Tests

### 5.1 Ouvrir un TROISIÈME terminal PowerShell

### 5.2 Aller dans le dossier des tests

```powershell
cd E:\Projects\Quiz\appium-tests
```

### 5.3 Installer les dépendances (si pas déjà fait)

```powershell
npm install
```

### 5.4 Lancer le test smoke

```powershell
npm run test:smoke
```

---

## Résumé Visuel - 3 Terminaux

```
┌─────────────────────────────────────────────────────────────────┐
│ TERMINAL 1 - Émulateur (optionnel si déjà lancé via Android Studio)
│ > emulator -avd Pixel_4_API_30
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ TERMINAL 2 - Appium Server (doit rester ouvert)
│ > $env:ANDROID_HOME = "C:\Users\thoma\AppData\Local\Android\sdk"
│ > $env:ANDROID_SDK_ROOT = "C:\Users\thoma\AppData\Local\Android\sdk"
│ > $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
│ > cd E:\Projects\Quiz\appium-tests
│ > appium
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ TERMINAL 3 - Tests
│ > cd E:\Projects\Quiz\appium-tests
│ > npm run test:smoke
└─────────────────────────────────────────────────────────────────┘
```

---

## Checklist Rapide

Avant de lancer `npm run test:smoke`, vérifie :

- [ ] Émulateur Android lancé et visible (`adb devices` montre un appareil)
- [ ] APK construit avec `flutter build apk --debug --target lib/main_appium.dart`
- [ ] Variables d'environnement configurées dans le terminal Appium
- [ ] Appium lancé et affiche "listener started on http://0.0.0.0:4723"
- [ ] Tu es dans le bon dossier : `E:\Projects\Quiz\appium-tests`

---

## Dépannage

### "Unable to connect to http://localhost:4723"
→ Appium n'est pas lancé. Lance-le avec `appium` dans un autre terminal.

### "Neither ANDROID_HOME nor ANDROID_SDK_ROOT"
→ Les variables d'environnement ne sont pas configurées. Exécute les commandes `$env:...` dans le terminal Appium.

### "Could not find a driver for automationName 'Flutter'"
→ Le driver Flutter n'est pas installé. Exécute :
```powershell
appium driver install --source=npm appium-flutter-driver
```

### "Application does not exist"
→ L'APK n'est pas construit ou le chemin est incorrect. Vérifie que le fichier existe :
```powershell
dir E:\Projects\Quiz\vocabulary_app\build\app\outputs\flutter-apk\app-debug.apk
```

### Timeout de 5 minutes sur "Cannot connect to Dart Observatory"
→ L'APK n'a pas été construit avec le bon target. Reconstruis-le :
```powershell
cd E:\Projects\Quiz\vocabulary_app
flutter clean
flutter build apk --debug --target lib/main_appium.dart
```

---

## Commandes Utiles

| Action | Commande |
|--------|----------|
| Vérifier émulateur | `adb devices` |
| Construire APK | `flutter build apk --debug --target lib/main_appium.dart` |
| Lancer Appium | `appium` |
| Lancer test smoke | `npm run test:smoke` |
| Lancer tous les tests | `npm test` |
| Voir drivers Appium | `appium driver list --installed` |
