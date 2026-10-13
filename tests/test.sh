#!/bin/sh
# test.sh
# Summary: Integration test script for kcapk APK builder.
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/lgpl-3.0.html

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kcapk-test.XXXXXX")
BUILD_LOG="$WORK_DIR/build.log"
APK_FILE="$WORK_DIR/bin/test.apk"
FINAL_APK="$TEST_DIR/test.apk"
EXEC_ARM64="$TEST_DIR/fixtures/arm64-v8a/kcapk-test-exec"
EXEC_X86_64="$TEST_DIR/fixtures/x86_64/kcapk-test-exec"
GENERATED_JAVA="$WORK_DIR/src/main/java/com/kaisarcode/kcapk/test"
GENERATED_BRIDGE_JS="$WORK_DIR/res/raw/native_bridge.js"

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
    --permission notifications \
    --permission exactAlarm \
    --permission camera \
    --permission camera \
    --permission locationCoarse \
    --permission android.permission.RECORD_AUDIO \
    --share-target '*/*' \
    --exec "$EXEC_ARM64" \
    --exec "$EXEC_X86_64" \
    --output-path "$WORK_DIR" >"$BUILD_LOG" 2>&1; then
    sed '/^INSTALL: adb install /d' "$BUILD_LOG"
else
    cat "$BUILD_LOG" >&2
    exit 1
fi

[ -f "$GENERATED_BRIDGE_JS" ] || {
    echo "Error: NativeBridge JavaScript resource was not generated." >&2
    exit 1
}
grep -q 'new Promise' "$GENERATED_BRIDGE_JS" || {
    echo "Error: NativeBridge async Promise layer was not generated." >&2
    exit 1
}
grep -q '__complete' "$GENERATED_BRIDGE_JS" || {
    echo "Error: NativeBridge async completion handler was not generated." >&2
    exit 1
}
grep -q 'AndroidBridge.exec(requestId, generation' "$GENERATED_BRIDGE_JS" || {
    echo "Error: NativeBridge.exec was not generated as an async request." >&2
    exit 1
}
grep -q 'AndroidBridge.permissionRequest(requestId, generation' "$GENERATED_BRIDGE_JS" || {
    echo "Error: permission request was not generated as an async request." >&2
    exit 1
}
grep -q 'intentConsumeShare' "$GENERATED_BRIDGE_JS" || {
    echo "Error: incoming share API was not generated." >&2
    exit 1
}
for NAMESPACE in haptics intents systemUI clipboard screen; do
    grep -q "$NAMESPACE:" "$GENERATED_BRIDGE_JS" || {
        echo "Error: NativeBridge.Android.$NAMESPACE namespace was not generated." >&2
        exit 1
    }
done
for CLASS in AsyncBridge ExecBridge HapticBridge IntentBridge SystemUIBridge ClipboardBridge ScreenBridge; do
    [ -f "$GENERATED_JAVA/$CLASS.java" ] || {
        echo "Error: $CLASS.java was not generated." >&2
        exit 1
    }
done

grep -q 'onRequestPermissionsResult' "$GENERATED_JAVA/MainActivity.java" || {
    echo "Error: permission result forwarding was not generated." >&2
    exit 1
}
grep -q 'onActivityResult' "$GENERATED_JAVA/MainActivity.java" || {
    echo "Error: activity result forwarding was not generated." >&2
    exit 1
}
grep -q 'onNewIntent' "$GENERATED_JAVA/MainActivity.java" || {
    echo "Error: incoming intent handling was not generated." >&2
    exit 1
}
grep -q 'PERMISSION_NOT_DECLARED' "$GENERATED_JAVA/PermissionBridge.java" || {
    echo "Error: undeclared permission handling was not generated." >&2
    exit 1
}
grep -q 'OpenableColumns.DISPLAY_NAME' "$GENERATED_JAVA/IntentBridge.java" || {
    echo "Error: incoming share metadata handling was not generated." >&2
    exit 1
}
grep -q 'native_bridge' "$GENERATED_JAVA/TrustedWebViewClient.java" || {
    echo "Error: NativeBridge resource loading was not generated." >&2
    exit 1
}

grep -q 'android.permission.ACCESS_NETWORK_STATE' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: network state permission was not generated." >&2
    exit 1
}
grep -q 'android.permission.VIBRATE' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: vibration permission was not generated." >&2
    exit 1
}
for PERMISSION in \
    android.permission.POST_NOTIFICATIONS \
    android.permission.SCHEDULE_EXACT_ALARM \
    android.permission.CAMERA \
    android.permission.ACCESS_COARSE_LOCATION \
    android.permission.RECORD_AUDIO; do
    grep -q "$PERMISSION" "$WORK_DIR/AndroidManifest.xml" || {
        echo "Error: requested permission was not generated: $PERMISSION" >&2
        exit 1
    }
done
[ "$(grep -c 'android.permission.CAMERA' "$WORK_DIR/AndroidManifest.xml")" -eq 1 ] || {
    echo "Error: duplicate permission declarations were generated." >&2
    exit 1
}
grep -q 'android.intent.action.SEND' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: ACTION_SEND share target was not generated." >&2
    exit 1
}
grep -q 'android.intent.action.SEND_MULTIPLE' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: ACTION_SEND_MULTIPLE share target was not generated." >&2
    exit 1
}
grep -Fq 'android:mimeType="*/*"' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: wildcard share target MIME type was not generated." >&2
    exit 1
}
if grep -q '@PERMISSIONS@\|@SHARE_TARGETS@' "$WORK_DIR/AndroidManifest.xml"; then
    echo "Error: manifest template marker was not rendered." >&2
    exit 1
fi
grep -q 'AlarmReceiver' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: alarm receiver was not generated." >&2
    exit 1
}

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
