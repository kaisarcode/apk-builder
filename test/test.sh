#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
WORK_DIR="$TEST_DIR/.build"
APK_FILE="$WORK_DIR/bin/test.apk"

"$ROOT_DIR/build.sh" \
    --display-name "KCAPK Test" \
    --project-name test \
    --package-name com.kaisarcode.kcapk.test \
    --webview-url "$TEST_DIR/index.html" \
    --icon "$ROOT_DIR/icon.svg" \
    --output-path "$WORK_DIR"

cp "$APK_FILE" "$TEST_DIR/test.apk"
printf 'Test APK: %s\n' "$TEST_DIR/test.apk"
