#!/bin/sh
# test.sh
# Summary: Integration test script for kcapk APK builder.
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/gpl-3.0.html

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kcapk-test.XXXXXX")
BUILD_LOG="$WORK_DIR/build.log"
APK_FILE="$WORK_DIR/bin/test.apk"
FINAL_APK="$TEST_DIR/test.apk"
EXEC_ARM64="$TEST_DIR/fixtures/arm64-v8a/kcapk-test-exec"
EXEC_X86_64="$TEST_DIR/fixtures/x86_64/kcapk-test-exec"

# Removes the temporary working directory.
# @return None.
cleanup () {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT HUP INT TERM

[ -f "$EXEC_ARM64" ] || { echo "Missing test fixture: $EXEC_ARM64" >&2; exit 1; }
[ -f "$EXEC_X86_64" ] || { echo "Missing test fixture: $EXEC_X86_64" >&2; exit 1; }

if "$ROOT_DIR/build.sh" \
    --display-name "KCAPK Test" \
    --project-name test \
    --package-name com.kaisarcode.kcapk.test \
    --webview-url "$TEST_DIR/index.html" \
    --icon "$ROOT_DIR/icon.svg" \
    --exec "$EXEC_ARM64" \
    --exec "$EXEC_X86_64" \
    --output-path "$WORK_DIR" >"$BUILD_LOG" 2>&1; then
    sed '/^INSTALL: adb install /d' "$BUILD_LOG"
else
    cat "$BUILD_LOG" >&2
    exit 1
fi

unzip -l "$APK_FILE" | grep -q 'lib/arm64-v8a/libexec_kcapk_test_exec.so' || {
    echo "Error: arm64-v8a executable was not packaged in the APK." >&2
    exit 1
}
unzip -l "$APK_FILE" | grep -q 'lib/x86_64/libexec_kcapk_test_exec.so' || {
    echo "Error: x86_64 executable was not packaged in the APK." >&2
    exit 1
}

cp "$APK_FILE" "$FINAL_APK"
printf 'Test APK: %s\n' "$FINAL_APK"
printf 'INSTALL: adb install -r -t %s\n' "$FINAL_APK"
