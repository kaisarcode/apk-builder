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
grep -q 'AndroidBridge.fileOpen' "$GENERATED_BRIDGE_JS" || {
    echo "Error: file picker was not generated as an async request." >&2
    exit 1
}
grep -q 'AndroidBridge.appsList' "$GENERATED_BRIDGE_JS" || {
    echo "Error: launcher app listing was not generated as an async request." >&2
    exit 1
}
grep -q 'AndroidBridge.appsIcon' "$GENERATED_BRIDGE_JS" || {
    echo "Error: launcher app icon API was not generated as an async request." >&2
    exit 1
}
grep -q 'AndroidBridge.resourceDescribe' "$GENERATED_BRIDGE_JS" || {
    echo "Error: Android resource descriptor API was not generated as an async request." >&2
    exit 1
}
grep -q 'AndroidBridge.appsLaunch' "$GENERATED_BRIDGE_JS" || {
    echo "Error: launcher app launch API was not generated." >&2
    exit 1
}
grep -q 'AndroidBridge.appsSetHomeEnabled' "$GENERATED_BRIDGE_JS" || {
    echo "Error: Home candidate API was not generated." >&2
    exit 1
}
grep -q 'intentConsumeShare' "$GENERATED_BRIDGE_JS" || {
    echo "Error: incoming share API was not generated." >&2
    exit 1
}
for NAMESPACE in haptics intents files apps resources systemUI clipboard screen; do
    grep -q "$NAMESPACE:" "$GENERATED_BRIDGE_JS" || {
        echo "Error: NativeBridge.Android.$NAMESPACE namespace was not generated." >&2
        exit 1
    }
done
for CLASS in AsyncBridge ExecBridge HapticBridge IntentBridge FileBridge AppBridge ResourceBridge SystemUIBridge ClipboardBridge ScreenBridge; do
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
grep -q 'Intent.ACTION_OPEN_DOCUMENT' "$GENERATED_JAVA/FileBridge.java" || {
    echo "Error: Android document picker was not generated." >&2
    exit 1
}
grep -q 'OpenableColumns.DISPLAY_NAME' "$GENERATED_JAVA/FileBridge.java" || {
    echo "Error: selected file metadata handling was not generated." >&2
    exit 1
}
grep -q 'OpenableColumns.DISPLAY_NAME' "$GENERATED_JAVA/IntentBridge.java" || {
    echo "Error: incoming share metadata handling was not generated." >&2
    exit 1
}
grep -q 'FLAG_GRANT_READ_URI_PERMISSION' "$GENERATED_JAVA/IntentBridge.java" || {
    echo "Error: shared file URI read grant was not generated." >&2
    exit 1
}
grep -q 'LauncherApps' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: Android LauncherApps integration was not generated." >&2
    exit 1
}
grep -q 'getActivityList' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: launcher app listing implementation was not generated." >&2
    exit 1
}
grep -q 'getActivityInfo' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: launcher activity metadata lookup was not generated." >&2
    exit 1
}
grep -q 'getIconResource' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: launcher icon resource lookup was not generated." >&2
    exit 1
}
if grep -q 'android.resource://' "$GENERATED_JAVA/AppBridge.java"; then
    echo "Error: AppBridge should not expand resource metadata itself." >&2
    exit 1
fi
grep -q 'getResourcesForApplication' "$GENERATED_JAVA/ResourceBridge.java" || {
    echo "Error: generic Android resource lookup was not generated." >&2
    exit 1
}
grep -q 'getResourceName' "$GENERATED_JAVA/ResourceBridge.java" || {
    echo "Error: Android resource names were not generated." >&2
    exit 1
}
grep -q 'android.resource://' "$GENERATED_JAVA/ResourceBridge.java" || {
    echo "Error: generic Android resource URI was not generated." >&2
    exit 1
}
grep -q 'assetPath' "$GENERATED_JAVA/ResourceBridge.java" || {
    echo "Error: Android resource asset path metadata was not generated." >&2
    exit 1
}
grep -q 'startMainActivity' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: launcher app start implementation was not generated." >&2
    exit 1
}
grep -q 'Settings.ACTION_HOME_SETTINGS' "$GENERATED_JAVA/AppBridge.java" || {
    echo "Error: Home settings integration was not generated." >&2
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
grep -q 'android.intent.category.HOME' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: Home launcher activity alias was not generated." >&2
    exit 1
}
grep -q 'android:name="com.kaisarcode.kcapk.test.HomeActivity"' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: Home activity alias name was not generated." >&2
    exit 1
}
grep -q 'android:enabled="false"' "$WORK_DIR/AndroidManifest.xml" || {
    echo "Error: Home activity alias must be disabled by default." >&2
    exit 1
}
if grep -q 'android.permission.QUERY_ALL_PACKAGES' "$WORK_DIR/AndroidManifest.xml"; then
    echo "Error: QUERY_ALL_PACKAGES must not be declared for launcher app listing." >&2
    exit 1
fi
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
