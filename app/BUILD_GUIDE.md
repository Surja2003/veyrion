# Veyrion — Build & Installation Guide (Transferable APK)

This guide explains how to build the **Veyrion** mobile app as a standalone, transferable APK (**~100–150 MB**) that can be shared via USB, Bluetooth, WhatsApp, or Google Drive and installed on any Android phone (old or new).

---

## Prerequisites

1. **Flutter SDK** (v3.24+ recommended):
   ```bash
   flutter --version
   ```
2. **Android SDK / Studio** with Java 17.

---

## Step 1: Prepare the Flutter Project

Open your terminal in the `app` directory:

```bash
cd app
flutter pub get
```

---

## Step 2: Build the Fat Universal APK (100–150 MB Target)

To build a **single fat APK** containing native binaries for all CPU architectures (`arm64-v8a`, `armeabi-v7a`, `x86_64`), run:

```bash
flutter build apk --release --no-split-per-abi
```

> **Why this size?**
> A universal fat APK includes Flutter engine binaries for all 3 Android architectures plus high-resolution graphics and asset bundles. It typically lands between **100 MB and 150 MB**, making it robust, complete, and fully transferable without requiring an internet connection to download extra architecture split files.

---

## Step 3: Locate your built APK

Once compilation finishes, your APK will be generated at:

```
app/build/app/outputs/flutter-apk/app-release.apk
```

You can rename it to `Veyrion_v1.0.0.apk`:

```bash
cp build/app/outputs/flutter-apk/app-release.apk Veyrion_v1.0.0.apk
```

---

## Step 4: Transfer and Install on Any Phone

### Method A: Direct Transfer (USB / Nearby Share / WhatsApp / Telegram)
1. Copy `Veyrion_v1.0.0.apk` to the target Android phone.
2. Open the **Files** or **File Manager** app on the phone.
3. Tap on `Veyrion_v1.0.0.apk`.
4. If prompted, enable **"Allow installation from unknown sources"**.
5. Tap **Install** and open **Veyrion™**.

### Method B: ADB (Developer Command Line)
If phone is connected via USB with Developer Mode enabled:
```bash
adb install -r app-release.apk
```

---

## Step 5: Connecting to the Inference Backend

1. Open **Veyrion™**.
2. Go to **Settings → Server Settings**.
3. Set the **API Base URL** to your hosted Hugging Face Space URL:
   `https://<your-username>-<your-space-name>.hf.space`
4. Tap **Save & test connection**.
