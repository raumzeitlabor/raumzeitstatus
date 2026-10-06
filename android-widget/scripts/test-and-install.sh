#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${ANDROID_HOME:-}" ]]; then
    if [[ -d "${HOME}/Library/Android/sdk" ]]; then
        export ANDROID_HOME="${HOME}/Library/Android/sdk"
    elif [[ -d "${DIR}/.android-sdk" ]]; then
        export ANDROID_HOME="${DIR}/.android-sdk"
    elif [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}" ]]; then
        export ANDROID_HOME="${ANDROID_SDK_ROOT}"
    fi
fi

export ANDROID_AVD_HOME="${DIR}/.android-avd"
export PATH="${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${PATH}"

if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -x "/usr/libexec/java_home" ]]; then
        export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    fi
    if [[ -z "${JAVA_HOME:-}" && -d "/usr/local/opt/openjdk@17" ]]; then
        export JAVA_HOME="/usr/local/opt/openjdk@17"
    fi
fi

export GRADLE_USER_HOME="${DIR}/.gradle-user-home"
export ANDROID_USER_HOME="${DIR}/.android-home"
export GRADLE_OPTS="-Djava.io.tmpdir=${DIR}/.tmp"

cd "${DIR}"

echo "=== 1. Checking connected Android devices ==="
DEVICE=$(adb devices | grep -E "device$" | head -n1 | awk '{print $1}' || true)

if [[ -z "${DEVICE}" ]]; then
    echo "No running emulator found. Launching minimal emulator in background..."
    "${DIR}/scripts/run-emulator.sh" --headless > /dev/null 2>&1 &
    EMU_PID=$!
    echo "Emulator started (PID: ${EMU_PID}). Waiting for boot..."
    
    adb wait-for-device
    while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; do
        sleep 1
    done
    echo "Emulator booted!"
else
    echo "Found connected device: ${DEVICE}"
fi

echo "=== 2. Building debug APK ==="
./gradlew assembleDebug --no-daemon

echo "=== 3. Installing APK ==="
APK_FILE="app/build/outputs/apk/debug/RaumZeitLabor_status-debug.apk"
if ! adb install -r "${APK_FILE}"; then
    echo "Install failed (e.g. signature mismatch). Reinstalling cleanly..."
    adb uninstall org.raumzeitlabor.status || true
    adb install "${APK_FILE}"
fi

echo "=== 4. Triggering widget broadcast ==="
adb shell am broadcast -a org.raumzeitlabor.status.UPDATE -n org.raumzeitlabor.status/.StatusProvider || true

echo "=== 5. Launching popup test ==="
adb shell am start -n org.raumzeitlabor.status/.MenuPopup --ei appWidgetId 1 || true

echo "=== 6. Capturing screenshot to test-screenshot.png ==="
sleep 2
adb exec-out screencap -p > "${DIR}/test-screenshot.png" || true
echo "Screenshot saved to ${DIR}/test-screenshot.png"

echo "=== Turnaround test completed successfully! ==="
