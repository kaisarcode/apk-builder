#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
WORK_DIR="$TEST_DIR/.build"
APK_FILE="$WORK_DIR/bin/test.apk"
EXEC_ARM64="$TEST_DIR/fixtures/arm64-v8a/kcapk-test-exec"
EXEC_X86_64="$TEST_DIR/fixtures/x86_64/kcapk-test-exec"

[ -f "$EXEC_ARM64" ] || { echo "Missing test fixture: $EXEC_ARM64" >&2; exit 1; }
[ -f "$EXEC_X86_64" ] || { echo "Missing test fixture: $EXEC_X86_64" >&2; exit 1; }

"$ROOT_DIR/build.sh" \
    --display-name "KCAPK Test" \
    --project-name test \
    --package-name com.kaisarcode.kcapk.test \
    --webview-url "$TEST_DIR/index.html" \
    --icon "$ROOT_DIR/icon.svg" \
    --exec "$EXEC_ARM64" \
    --exec "$EXEC_X86_64" \
    --output-path "$WORK_DIR"

unzip -l "$APK_FILE" | grep -q 'lib/arm64-v8a/libexec_kcapk_test_exec.so' || {
    echo "Error: arm64-v8a executable was not packaged in the APK." >&2
    exit 1
}
unzip -l "$APK_FILE" | grep -q 'lib/x86_64/libexec_kcapk_test_exec.so' || {
    echo "Error: x86_64 executable was not packaged in the APK." >&2
    exit 1
}

cp "$APK_FILE" "$TEST_DIR/test.apk"
printf 'Test APK: %s\n' "$TEST_DIR/test.apk"
