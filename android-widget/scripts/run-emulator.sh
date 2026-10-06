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

AVD_NAME="WidgetTest"
MODE="${1:---gui}"

EXTRA_FLAGS=(
    -avd "${AVD_NAME}"
    -no-audio
    -no-boot-anim
    -gpu host
)

if [[ "${MODE}" == "--headless" || "${MODE}" == "-h" ]]; then
    EXTRA_FLAGS+=(-no-window)
    echo "Starting emulator '${AVD_NAME}' in HEADLESS mode (fastest)..."
else
    EXTRA_FLAGS+=(-no-skin)
    echo "Starting emulator '${AVD_NAME}' in GUI mode (minimal window, no skin)..."
fi

exec emulator "${EXTRA_FLAGS[@]}"
