# RaumZeitStatus Android Widget

An Android home-screen widget displaying the current open/closed status of the [RaumZeitLabor](https://raumzeitlabor.de) hackerspace.

Modernized to **Android 16 (API Level 36)** with Android Gradle Plugin 9, Java 17+, WorkManager background scheduling, and edge-to-edge system insets support.

---

## Prerequisites

- **Java Development Kit (JDK):** JDK 17 or higher (JDK 17, 21, or 26).
  - macOS (Homebrew): `brew install openjdk@17`
- **Android SDK:**
  - `compileSdk`: 36 (Android 16)
  - `targetSdk`: 36
  - `minSdk`: 24 (Android 7.0+)
  - Build-Tools: `36.0.0`
  - System Image (for testing): `system-images;android-34;google_apis;arm64-v8a` (or higher)

---

## How the Build & SDK Environment Works

When modernizing this project in a modern/sandboxed environment, a few special setups were created to ensure predictable, self-contained builds without polluting global system paths:

### 1. SDK Isolation & Auto-Downloading (`.android-sdk/`)
Modern Android Gradle Plugin (AGP) can automatically download missing SDK platforms and build-tools when building, but writing directly to system SDK folders (like `/Users/<user>/Library/Android/sdk`) can fail due to sandbox or permission restrictions.

- **`local.properties`** points `sdk.dir` to the project-local `.android-sdk/` directory.
- **Symlink Setup:** `.android-sdk/` contains symlinks to any existing base SDK directories (`build-tools`, `platforms`) and copies accepted licenses from `licenses/`.
- **Auto-Installation:** When AGP needs newer SDK components (such as Build-Tools 36.0.0 and Android SDK 36), it installs them directly into `.android-sdk/` without needing root or global write access.
- Both `.android-sdk/` and `local.properties` are ignored in `.gitignore`.

> **Note for standard development:** If you are building outside this setup or using Android Studio, you can simply set `sdk.dir` in `local.properties` to your standard Android SDK path (e.g., `sdk.dir=/Users/<username>/Library/Android/sdk` on MacOS).

### 2. Isolated User Homes & Temp Directory
To prevent permission conflicts with global `~/.android` and `~/.gradle` directories:
- **`GRADLE_USER_HOME` (`.gradle-user-home/`):** Configured in `gradlew` so wrapper distributions and dependency caches are stored cleanly in the project tree.
- **`ANDROID_USER_HOME` (`.android-home/`):** Tells Android SDK tools to store analytics and repository manifests locally instead of failing on `~/.android/cache`.
- **`java.io.tmpdir` (`.tmp/`):** Set in `gradle.properties` (`-Djava.io.tmpdir=.tmp`). Prevents DEX merge and JNI extraction failures when OS `/var/folders/.../T` temp paths are restricted.

---

## Building the App

### Debug Build
```bash
./gradlew assembleDebug
```
- Output: `app/build/outputs/apk/debug/RaumZeitLabor_status-debug.apk`
- Automatically signed with the default Android debug key.

### Release Build (Signed)
```bash
./gradlew assembleRelease
```
- Output: `app/build/outputs/apk/release/RaumZeitLabor_status.apk` (and `RaumZeitLabor_status-release.apk`)
- **Signing:** Android 14+ strictly refuses to install unsigned APKs (`INSTALL_PARSE_FAILED_NO_CERTIFICATES`). A self-contained release keystore (`release.jks`, alias `rzlstatus`) is configured in `app/build.gradle` so release APKs can be sideloaded and tested immediately.
- To use your own production signing key for Google Play, update the `signingConfigs.release` block in `app/build.gradle`.

### Release App Bundle (AAB for Google Play)
```bash
./gradlew bundleRelease
```
- Output: `app/build/outputs/bundle/release/RaumZeitLabor_status-release.aab`

---

## Installing on Physical Devices (e.g. Pixel)

> **Important:** If you previously installed a debug build on your device, Android security will block installing a release build with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` because the certificate signatures differ.

Uninstall the previous signature first:
```bash
adb uninstall org.raumzeitlabor.status
adb install app/build/outputs/apk/release/RaumZeitLabor_status.apk
```

---

## Fast Turnaround Testing (Minimal Emulator)

Cold-booting standard Android emulators with phone skins, audio subsystems, and cameras can be very slow. A lean development emulator profile (`WidgetTest`) and helper scripts are included:

### Minimal AVD Specifications (`.android-avd/WidgetTest.avd`)
- **Display:** 720×1280 (low memory footprint, fast GPU rasterization)
- **CPU:** 4 cores with native Apple Silicon Hypervisor acceleration (`-gpu host`)
- **RAM / Heap:** 2048 MB RAM / 256 MB heap
- **Peripherals:** Audio, cameras, sensors, and GPS disabled to minimize boot time.

### Available Scripts

#### 1. Launch the Emulator
- **GUI Mode (fast minimal window, no device skins, no audio):**
  ```bash
  ./scripts/run-emulator.sh
  ```
- **Headless Mode (fastest, runs in background without a display window):**
  ```bash
  ./scripts/run-emulator.sh --headless
  ```

#### 2. One-Step Build, Deploy & Verify
```bash
./scripts/test-and-install.sh
```
This automated script:
1. Connects to or boots the minimal emulator in the background.
2. Compiles the APK (`./gradlew assembleDebug`).
3. Installs the APK (`adb install -r`).
4. Fires the widget update broadcast (`org.raumzeitlabor.status.UPDATE`).
5. Opens the `MenuPopup` activity to verify the UI against the live API (`https://s.rzl.so/api/full.json`).
6. Saves a verification screenshot to `test-screenshot.png`.

---

## Architecture & Notable Implementation Details

- **Widget RemoteViews:** Traditional `RemoteViews` implementation retained for lightweight footprint, updated with modern 1×1 responsive sizing metadata (`targetCellWidth="1"`, `targetCellHeight="1"`).
- **Background Updates:** Uses Android Jetpack `WorkManager` (`StatusUpdateWorker`) with `NetworkType.CONNECTED` constraints instead of legacy alarms or background services.
- **Widget Click Handling:** Uses direct activity `PendingIntent` (`PendingIntent.FLAG_IMMUTABLE`) to open `MenuPopup`, fully compliant with Android 12+ background activity launch restrictions.
- **Settings Screen (`Configure.java`):**
  - Uses `PreferenceFragmentCompat` with `Theme.AppCompat.DayNight.NoActionBar` and an explicit `Toolbar`.
  - Configured with `fitsSystemWindows="true"` to prevent edge-to-edge UI overlaps on Android 15/16.
  - Automatically sets `setResult(RESULT_OK)` to prevent launcher hosts from unpinning or deleting the widget when backing out of settings.
