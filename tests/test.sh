#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
WORK_DIR="$TEST_DIR/.build"
EXEC_DIR="$TEST_DIR/.exec"
EXEC_FILE="$EXEC_DIR/kcapk-test-exec"
APK_FILE="$WORK_DIR/bin/test.apk"
FINAL_APK="$TEST_DIR/test.apk"

mkdir -p "$EXEC_DIR"

if [ -n "${TEST_EXECUTABLE:-}" ]; then
    cp "$TEST_EXECUTABLE" "$EXEC_FILE"
else
    NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"

    if [ -z "$NDK_DIR" ]; then
        SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
        if [ -n "$SDK_ROOT" ] && [ -d "$SDK_ROOT/ndk" ]; then
            for CANDIDATE in "$SDK_ROOT"/ndk/*; do
                [ -d "$CANDIDATE" ] && NDK_DIR="$CANDIDATE"
            done
        fi
    fi

    [ -n "$NDK_DIR" ] || {
        echo "Error: Android NDK not found. Set ANDROID_NDK_HOME/ANDROID_NDK_ROOT or TEST_EXECUTABLE." >&2
        exit 1
    }

    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64) HOST_TAG="linux-x86_64" ;;
        Darwin-x86_64) HOST_TAG="darwin-x86_64" ;;
        Darwin-arm64) HOST_TAG="darwin-arm64" ;;
        *)
            echo "Error: Unsupported NDK host: $(uname -s)-$(uname -m). Set TEST_EXECUTABLE instead." >&2
            exit 1
            ;;
    esac

    CC="$NDK_DIR/toolchains/llvm/prebuilt/$HOST_TAG/bin/aarch64-linux-android24-clang"
    [ -x "$CC" ] || {
        echo "Error: Android NDK compiler not found: $CC" >&2
        exit 1
    }

    "$CC" "$TEST_DIR/exec.c" -o "$EXEC_FILE"
fi

chmod +x "$EXEC_FILE"

"$ROOT_DIR/build.sh" \
    --display-name "KCAPK Test" \
    --project-name test \
    --package-name com.kaisarcode.kcapk.test \
    --webview-url "$TEST_DIR/index.html" \
    --icon "$ROOT_DIR/icon.svg" \
    --exec "$EXEC_FILE" \
    --output-path "$WORK_DIR"

cp "$APK_FILE" "$FINAL_APK"

if ! unzip -l "$FINAL_APK" | grep -Eq 'lib/[^/]+/libexec_kcapk_test_exec\.so$'; then
    echo "Error: Packaged test executable was not found inside $FINAL_APK." >&2
    exit 1
fi

printf 'Test APK: %s\n' "$FINAL_APK"
printf 'External executable packaged successfully.\n'
