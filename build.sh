#!/bin/sh
# build.sh
# Summary: Generic Android WebView APK/AAB builder.
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/gpl-3.0.html

DISPLAY_NAME="${DISPLAY_NAME:-My App}"
PROJECT_NAME="${PROJECT_NAME:-myapp}"
PACKAGE_NAME="${PACKAGE_NAME:-com.kaisarcode.myapp}"
WEBVIEW_URL="${WEBVIEW_URL:-https://google.com/}"
ICON_SOURCE_FILE="${ICON_SOURCE_FILE:-./icon.svg}"
TRUSTED_ORIGINS="${TRUSTED_ORIGINS:-
}"
IS_FULLSCREEN="false"
KCLIBS="${KCLIBS:-}"
KCLIB_DIR="${KCLIB_DIR:-}"
VERSION_CODE=1
VERSION_NAME="1.0"
TARGET_SDK="34"
MIN_SDK="24"

BUILD_TOOLS_VERSION="34.0.0"
PLATFORM_VERSION="android-$TARGET_SDK"

CMDLINE_TOOLS_VERSION="11076708"
DEFAULT_CMDLINE_PREFIX="commandlinetools"

if [ -z "$CMDLINE_TOOLS_URL" ]; then
    case "$(uname -s)" in
        Darwin)
            CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/${DEFAULT_CMDLINE_PREFIX}-mac-${CMDLINE_TOOLS_VERSION}_latest.zip"
            ;;
        *)
            CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/${DEFAULT_CMDLINE_PREFIX}-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
            ;;
    esac
fi

SDK_ZIP="${SDK_ZIP:-${DEFAULT_CMDLINE_PREFIX}.zip}"

BASE_DIR="./$PROJECT_NAME"
PACKAGE_SUBPATH="$(echo "$PACKAGE_NAME" | tr . /)"
SRC_DIR="$BASE_DIR/src/main/java/$PACKAGE_SUBPATH"
RES_DIR="$BASE_DIR/res"
LAYOUT_DIR="$RES_DIR/layout"
VALUES_DIR="$RES_DIR/values"
ASSETS_DIR="$BASE_DIR/assets"

MIPMAP_MDPI_DIR="$RES_DIR/mipmap-mdpi"
MIPMAP_HDPI_DIR="$RES_DIR/mipmap-hdpi"
MIPMAP_XHDPI_DIR="$RES_DIR/mipmap-xhdpi"
MIPMAP_XXHDPI_DIR="$RES_DIR/mipmap-xxhdpi"
MIPMAP_XXXHDPI_DIR="$RES_DIR/mipmap-xxxhdpi"

OUTPUT_DIR="$BASE_DIR/bin"
TEMP_ROOT_DIR="$BASE_DIR/temp"
TEMP_CLASSES_DIR="$TEMP_ROOT_DIR/classes"
FLAT_RES_DIR="$TEMP_ROOT_DIR/resources"
TEMP_BUILD_DATA_DIR="$TEMP_ROOT_DIR/build_data"
AAB_TEMP_DIR="$TEMP_ROOT_DIR/aab_work"

R_PACKAGE_DIR="$TEMP_CLASSES_DIR/$PACKAGE_SUBPATH"
TEMP_JAR_FILE="$TEMP_BUILD_DATA_DIR/classes.jar"
DEX_FILE="$TEMP_BUILD_DATA_DIR/classes.dex"

if [ -n "$ANDROID_SDK_ROOT" ]; then
    SDK_BASE="$ANDROID_SDK_ROOT"
elif [ -n "$ANDROID_HOME" ]; then
    SDK_BASE="$ANDROID_HOME"
else
    SDK_BASE="$HOME/android-sdk"
fi

ANDROID_SDK_ROOT="$SDK_BASE"
if [ -z "$ANDROID_HOME" ]; then
    ANDROID_HOME="$ANDROID_SDK_ROOT"
fi

CMDLINE_TOOLS_DIR="$ANDROID_SDK_ROOT/cmdline-tools/latest"
BUILD_TOOLS_DIR="$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS_VERSION"
PLATFORM_DIR="$ANDROID_SDK_ROOT/platforms/$PLATFORM_VERSION"
SDKMANAGER="$CMDLINE_TOOLS_DIR/bin/sdkmanager"
AAPT2="$BUILD_TOOLS_DIR/aapt2"
DX="$BUILD_TOOLS_DIR/d8"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
ANDROID_JAR="$PLATFORM_DIR/android.jar"
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

MANIFEST_FILE="$BASE_DIR/AndroidManifest.xml"
MAIN_ACTIVITY_FILE="$SRC_DIR/MainActivity.java"
JS_INTERFACE_FILE="$SRC_DIR/JSBridge.java"
WEBVIEW_CLIENT_FILE="$SRC_DIR/TrustedWebViewClient.java"

UNSIGNED_APK_TEMP="$TEMP_ROOT_DIR/unsigned.apk"
ALIGNED_APK_TEMP="$TEMP_ROOT_DIR/aligned.apk"
DEBUG_APK_FILE="$OUTPUT_DIR/$PROJECT_NAME.apk"

BUNDLETOOL_VERSION="1.18.2"
BUNDLETOOL_JAR="$BASE_DIR/bundletool-all-$BUNDLETOOL_VERSION.jar"
BUNDLETOOL_URL="https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
AAB_UNSIGNED_FILE="$TEMP_ROOT_DIR/unsigned.aab"
AAB_SIGNED_FILE="$OUTPUT_DIR/$PROJECT_NAME.aab"
BASE_MODULE_ZIP="$AAB_TEMP_DIR/base.zip"
FINAL_MODULE_DIR="$AAB_TEMP_DIR/final_module"
SIGNING_REQUIRED="false"

CLEAN_ALL=false
RELEASE_MODE=false

for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN_ALL=true
            echo "Argument --clean detected. Forcing KeyStore and temporary files deletion."
            ;;
        --release)
            RELEASE_MODE=true
            echo "Argument --release detected. Preparing for DUAL AAB/APK build."
            ;;
    esac
done

if $CLEAN_ALL; then
    if [ -f "$DEBUG_KEYSTORE" ]; then
        rm -f "$DEBUG_KEYSTORE"
        echo "Old debug KeyStore deleted: $DEBUG_KEYSTORE"
    else
        echo "Debug KeyStore not found. Skipping deletion."
    fi
fi

# Downloads and configures the Android SDK if missing.
# @return None.
setup_sdk () {
    export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
    export PATH="$PATH:$CMDLINE_TOOLS_DIR/bin"

    if [ ! -f "$SDKMANAGER" ]; then
        wget -t 5 --show-progress "$CMDLINE_TOOLS_URL" -O "$SDK_ZIP" || { echo "Error: Failed to download SDK." ; exit 1; }
        mkdir -p "$CMDLINE_TOOLS_DIR"
        unzip -q -o "$SDK_ZIP" -d "$CMDLINE_TOOLS_DIR/temp" || { echo "Error: Extraction failed." ; exit 1; }
        mv "$CMDLINE_TOOLS_DIR/temp/cmdline-tools/"* "$CMDLINE_TOOLS_DIR/"
        rm -rf "$CMDLINE_TOOLS_DIR/temp"
        rm "$SDK_ZIP"
    fi

    if [ ! -f "$AAPT2" ] || [ ! -f "$ANDROID_JAR" ]; then
        yes | "$SDKMANAGER" "platforms;$PLATFORM_VERSION" "build-tools;$BUILD_TOOLS_VERSION" --sdk_root="$ANDROID_SDK_ROOT" || { echo "Error: Failed to install SDK." ; exit 1; }
    fi
}

# Downloads bundletool if missing or version mismatch.
# @return None.
download_bundletool () {
    EXPECTED_JAR="$BASE_DIR/bundletool-all-$BUNDLETOOL_VERSION.jar"

    if [ -f "$EXPECTED_JAR" ]; then
        echo "BUNDLETOOL ($BUNDLETOOL_VERSION) found. Skipping download."
        BUNDLETOOL_JAR="$EXPECTED_JAR"
        return
    fi

    EXISTING_JAR=$(find "$BASE_DIR" -maxdepth 1 -name "bundletool-all-*.jar" -print -quit)
    if [ -n "$EXISTING_JAR" ]; then
        echo "Found existing BundleTool JAR ($EXISTING_JAR), but expected version $BUNDLETOOL_VERSION. Deleting and re-downloading."
        rm -f "$EXISTING_JAR"
    fi

    echo "BUNDLETOOL Not Found or Version Mismatch. Downloading $BUNDLETOOL_VERSION..."
    echo "URL: $BUNDLETOOL_URL"
    wget -q --show-progress "$BUNDLETOOL_URL" -O "$EXPECTED_JAR" || { echo "Error: Failed to download bundletool. Check URL or internet connection." ; exit 1; }

    BUNDLETOOL_JAR="$EXPECTED_JAR"
    echo "BUNDLETOOL downloaded successfully."
}

# Checks and sets up release signing credentials.
# @return None.
setup_release_signing () {
    if [ -n "$RELEASE_KEYSTORE" ] && [ -n "$RELEASE_KEY_ALIAS" ] && \
        [ -n "$RELEASE_STORE_PASS" ] && [ -n "$RELEASE_KEY_PASS" ]; then

        if [ ! -f "$RELEASE_KEYSTORE" ]; then
            echo "FATAL ERROR: Release KeyStore file not found at: $RELEASE_KEYSTORE"
            exit 1
        fi

        echo "Release KeyStore credentials found in environment."
        SIGNING_REQUIRED="true"
    else
        echo "Release KeyStore credentials NOT found in environment. AAB will be generated unsigned."
    fi
}

# Extracts scheme://host[:port] from a remote URL.
# @param $1 Remote URL.
# @return Prints the origin or fails.
extract_origin () {
    INPUT_URL="$1"

    case "$INPUT_URL" in
        http://*|https://*)
            SCHEME="${INPUT_URL%%://*}"
            REMAINDER="${INPUT_URL#*://}"
            HOST_AND_PORT="${REMAINDER%%/*}"

            if [ -z "$HOST_AND_PORT" ]; then
                return 1
            fi

            printf '%s://%s\n' "$SCHEME" "$HOST_AND_PORT"
            ;;
        *)
            return 1
            ;;
    esac
}

# Builds the Android App Bundle.
# @return None.
build_aab () {

    setup_release_signing

    ABS_BASE_MODULE_ZIP="$(pwd)/$BASE_MODULE_ZIP"

    if [ ! -f "$DEX_FILE" ]; then
        echo "FATAL ERROR: classes.dex (compiled code) not found. Ensure the common build steps ran successfully."
        exit 1
    fi

    mkdir -p "$FINAL_MODULE_DIR"

    echo "Linking resources and manifest into temporary module zip."
    "$AAPT2" link \
        --proto-format \
        -o "$FINAL_MODULE_DIR/base_temp.zip" \
        -I "$ANDROID_JAR" \
        --manifest "$MANIFEST_FILE" \
        -R "$FLAT_RES_DIR/res.zip" \
        -A "$ASSETS_DIR" \
        --min-sdk-version "$MIN_SDK" \
        --target-sdk-version "$TARGET_SDK" \
        --version-code "$VERSION_CODE" \
        --version-name "$VERSION_NAME" \
        --auto-add-overlay || { echo "Error: AAPT2 Protobuf Link failed."; exit 1; }

    unzip -q "$FINAL_MODULE_DIR/base_temp.zip" -d "$FINAL_MODULE_DIR"
    rm "$FINAL_MODULE_DIR/base_temp.zip"

    mkdir -p "$FINAL_MODULE_DIR/manifest"
    mv "$FINAL_MODULE_DIR/AndroidManifest.xml" "$FINAL_MODULE_DIR/manifest/AndroidManifest.xml"

    mkdir -p "$FINAL_MODULE_DIR/dex"
    cp "$DEX_FILE" "$FINAL_MODULE_DIR/dex/classes.dex"

    if [ -d "$FINAL_MODULE_DIR/assets" ]; then
        (cd "$FINAL_MODULE_DIR" && zip -r -q "$ABS_BASE_MODULE_ZIP" manifest res dex resources.pb assets) || { echo "Error: ZIP tool failed to re-package module."; exit 1; }
    else
        (cd "$FINAL_MODULE_DIR" && zip -r -q "$ABS_BASE_MODULE_ZIP" manifest res dex resources.pb) || { echo "Error: ZIP tool failed to re-package module."; exit 1; }
    fi

    java -jar "$BUNDLETOOL_JAR" build-bundle \
        --modules="$BASE_MODULE_ZIP" \
        --output="$AAB_UNSIGNED_FILE" || { echo "Error: bundletool failed to generate AAB."; exit 1; }

    if [ "$SIGNING_REQUIRED" = "true" ]; then
        echo "Signing the AAB using jarsigner..."

        jarsigner -verbose \
            -sigalg SHA256withRSA \
            -digestalg SHA-256 \
            -keystore "$RELEASE_KEYSTORE" \
            -storepass "$RELEASE_STORE_PASS" \
            -keypass "$RELEASE_KEY_PASS" \
            "$AAB_UNSIGNED_FILE" "$RELEASE_KEY_ALIAS" || { echo "Error: jarsigner failed to sign the AAB." ; exit 1; }

        mv "$AAB_UNSIGNED_FILE" "$AAB_SIGNED_FILE"
    else
        mv "$AAB_UNSIGNED_FILE" "$AAB_SIGNED_FILE"
        echo "Skipping signing. Final AAB is generated without a signature (ready for Google Play App Signing)."
    fi

    echo "AAB Output: $AAB_SIGNED_FILE"
    rm -rf "$AAB_TEMP_DIR"
}

# Builds the debug APK.
# @return None.
build_apk () {
    zip -j "$UNSIGNED_APK_TEMP" "$DEX_FILE" || { echo "Error: ZIP tool failed to insert classes.dex." ; exit 1; }

    if [ -n "$KCLIB_DIR" ]; then
        for ABI_DIR in "$KCLIB_DIR"/*/; do
            ABI_NAME=$(basename "$ABI_DIR")
            for SO_FILE in "$ABI_DIR"*.so; do
                if [ -f "$SO_FILE" ]; then
                    SO_NAME=$(basename "$SO_FILE")
                    zip -j "$UNSIGNED_APK_TEMP" "$SO_FILE" -d "lib/$ABI_NAME/$SO_NAME" 2>/dev/null || \
                    (cd "$(dirname "$SO_FILE")" && zip -u "$(realpath "$UNSIGNED_APK_TEMP")" "$SO_NAME" -x "*" 2>/dev/null)
                fi
            done
        done
        if [ -d "$KCLIB_DIR" ]; then
            NATIVE_TEMP="$TEMP_ROOT_DIR/native_libs"
            mkdir -p "$NATIVE_TEMP"
            for ABI_DIR in "$KCLIB_DIR"/*/; do
                ABI_NAME=$(basename "$ABI_DIR")
                NATIVE_ABI_DIR="$NATIVE_TEMP/lib/$ABI_NAME"
                mkdir -p "$NATIVE_ABI_DIR"
                cp "$ABI_DIR"*.so "$NATIVE_ABI_DIR/" 2>/dev/null
            done
            if [ -d "$NATIVE_TEMP/lib" ]; then
                (cd "$NATIVE_TEMP" && zip -r -q "$(realpath "$UNSIGNED_APK_TEMP")" lib/) 2>/dev/null
            fi
            rm -rf "$NATIVE_TEMP"
        fi
    fi

    echo "Generating debug KeyStore if it does not exist..."
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US"
        echo "Debug KeyStore successfully generated."
    else
        echo "Debug KeyStore found. Using existing KeyStore."
    fi

    echo "Aligning and Signing the Debug APK (Output: $DEBUG_APK_FILE)..."

    "$ZIPALIGN" -f 4 "$UNSIGNED_APK_TEMP" "$ALIGNED_APK_TEMP" || { echo "Error: ZIPALIGN failed." ; exit 1; }

    "$APKSIGNER" sign --ks "$DEBUG_KEYSTORE" \
        --ks-key-alias androiddebugkey \
        --ks-pass pass:android \
        --key-pass pass:android \
        --out "$DEBUG_APK_FILE" "$ALIGNED_APK_TEMP" || { echo "Error: APKSIGNER failed."; exit 1; }

    echo "APK Output: $DEBUG_APK_FILE"
}

setup_sdk

mkdir -p "$SRC_DIR" "$LAYOUT_DIR" "$VALUES_DIR" "$OUTPUT_DIR" "$ASSETS_DIR" \
    "$MIPMAP_MDPI_DIR" "$MIPMAP_HDPI_DIR" "$MIPMAP_XHDPI_DIR" \
    "$MIPMAP_XXHDPI_DIR" "$MIPMAP_XXXHDPI_DIR"
rm -rf "$TEMP_ROOT_DIR"
mkdir -p "$TEMP_CLASSES_DIR" "$FLAT_RES_DIR" "$R_PACKAGE_DIR" "$TEMP_BUILD_DATA_DIR" "$AAB_TEMP_DIR"

DENSITY_PAIRS="mdpi:48x48 hdpi:72x72 xhdpi:96x96 xxhdpi:144x144 xxxhdpi:192x192"
ICON_TEMP_FILE="$RES_DIR/temp_icon_file_base"

case "$ICON_SOURCE_FILE" in
    http://*|https://*)
        echo "Starting Icon Generation from REMOTE URL ($ICON_SOURCE_FILE)..."
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$ICON_SOURCE_FILE" -o "$ICON_TEMP_FILE" || { echo "Error: Failed to download icon from $ICON_SOURCE_FILE using curl."; exit 1; }
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$ICON_SOURCE_FILE" -O "$ICON_TEMP_FILE" || { echo "Error: Failed to download icon from $ICON_SOURCE_FILE using wget."; exit 1; }
        else
            echo "Error: Neither curl nor wget is available to download remote icons."
            exit 1
        fi
        ;;
    *)
        echo "Starting Icon Generation from LOCAL FILE ($ICON_SOURCE_FILE)..."
        if [ ! -f "$ICON_SOURCE_FILE" ]; then
            echo "Error: Icon file not found at $ICON_SOURCE_FILE."
            exit 1
        fi
        cp "$ICON_SOURCE_FILE" "$ICON_TEMP_FILE" || { echo "Error: Failed to copy local icon file." ; exit 1; }
        ;;
esac

if command -v convert >/dev/null 2>&1; then
    for PAIR in $DENSITY_PAIRS; do
        DENSITY=$(echo "$PAIR" | cut -d: -f1)
        SIZE=$(echo "$PAIR" | cut -d: -f2)

        MIPMAP_SUBDIR="$RES_DIR/mipmap-$DENSITY"
        ICON_FINAL_PNG="$MIPMAP_SUBDIR/ic_launcher.png"

        convert "$ICON_TEMP_FILE" -resize "$SIZE" "$ICON_FINAL_PNG" || { echo "Error: ImageMagick conversion failed for $DENSITY." ; exit 1; }
    done
else
    echo "Error: 'convert' (ImageMagick) not found. Cannot generate icons."
    rm -f "$ICON_TEMP_FILE"
    exit 1
fi

rm -f "$ICON_TEMP_FILE"

echo "Icon Generation complete."

ORIGINAL_WEBVIEW_URL="$WEBVIEW_URL"
RESOLVED_TRUSTED_ORIGINS="$TRUSTED_ORIGINS"

if [ -d "$ASSETS_DIR" ]; then
    rm -rf "$ASSETS_DIR"
fi
mkdir -p "$ASSETS_DIR"

if [ "${ORIGINAL_WEBVIEW_URL#https}" != "$ORIGINAL_WEBVIEW_URL" ] || \
    [ "${ORIGINAL_WEBVIEW_URL#http}" != "$ORIGINAL_WEBVIEW_URL" ] || \
    [ "${ORIGINAL_WEBVIEW_URL#file:}" != "$ORIGINAL_WEBVIEW_URL" ]; then
    echo "WEBVIEW_URL contains a protocol (http/https/file:). Skipping local asset copy."
else
    ORIGINAL_LOCAL_PATH="$ORIGINAL_WEBVIEW_URL"
    LOCAL_FILE_TO_COPY=""

    case "$ORIGINAL_LOCAL_PATH" in
        \~*)
            LOCAL_FILE_TO_COPY="$HOME${ORIGINAL_LOCAL_PATH#\~}"
            ;;
        *)
            LOCAL_FILE_TO_COPY="$ORIGINAL_LOCAL_PATH"
            ;;
    esac

    if [ ! -f "$LOCAL_FILE_TO_COPY" ]; then
        echo "Error: Local HTML start file not found at $LOCAL_FILE_TO_COPY."
        echo "Please create the file to continue."
        exit 1
    fi

    FILENAME=$(basename "$LOCAL_FILE_TO_COPY")
    SOURCE_DIR=$(dirname "$LOCAL_FILE_TO_COPY")

    echo "Detected local project path: $ORIGINAL_WEBVIEW_URL. Copying entire project from $SOURCE_DIR to assets."

    cp -r "$SOURCE_DIR/." "$ASSETS_DIR/" || { echo "Error: Failed to copy local HTML assets from $SOURCE_DIR." ; exit 1; }

    WEBVIEW_URL="file:///android_asset/$FILENAME"
    echo "Updated WEBVIEW_URL to: $WEBVIEW_URL"
fi

DEFAULT_TRUSTED_ORIGIN=$(extract_origin "$WEBVIEW_URL" 2>/dev/null)
if [ -n "$DEFAULT_TRUSTED_ORIGIN" ]; then
    if [ -z "$RESOLVED_TRUSTED_ORIGINS" ]; then
        RESOLVED_TRUSTED_ORIGINS="$DEFAULT_TRUSTED_ORIGIN"
    else
        RESOLVED_TRUSTED_ORIGINS="$DEFAULT_TRUSTED_ORIGIN $RESOLVED_TRUSTED_ORIGINS"
    fi
fi

JAVA_TRUSTED_ORIGINS=""
for ORIGIN in $RESOLVED_TRUSTED_ORIGINS; do
    if [ -n "$JAVA_TRUSTED_ORIGINS" ]; then
        JAVA_TRUSTED_ORIGINS="$JAVA_TRUSTED_ORIGINS, "
    fi
    JAVA_TRUSTED_ORIGINS="$JAVA_TRUSTED_ORIGINS\"$ORIGIN\""
done

cat << EOF > "$MANIFEST_FILE"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PACKAGE_NAME"
    android:versionCode="$VERSION_CODE"
    android:versionName="$VERSION_NAME">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:resizeableActivity="true"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">
        <meta-data android:name="android.max_aspect" android:value="2.4" />
EOF

if [ -n "$KCLIBS" ]; then
    cat << EOF >> "$MANIFEST_FILE"
        <meta-data android:name="com.kaisarcode.kclib.allowed_kclibs" android:value="$KCLIBS" />
EOF
fi

cat << EOF >> "$MANIFEST_FILE"
        <activity
            android:name="$PACKAGE_NAME.MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize"
            android:configChanges="orientation|screenSize|keyboardHidden|smallestScreenSize|screenLayout">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
    <uses-sdk android:minSdkVersion="$MIN_SDK" android:targetSdkVersion="$TARGET_SDK" />
</manifest>
EOF

cat << EOF > "$VALUES_DIR/strings.xml"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$DISPLAY_NAME</string>
    <string name="js_interface_name">AndroidBridge</string>
</resources>
EOF

cat << EOF > "$LAYOUT_DIR/activity_main.xml"
<?xml version="1.0" encoding="utf-8"?>
<WebView xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/webview"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
EOF

echo "Writing Java Code..."

FULLSCREEN_IMPORTS=""
FULLSCREEN_SETUP=""
if [ "$IS_FULLSCREEN" = "true" ]; then
    FULLSCREEN_IMPORTS="
import android.view.Window;
import android.view.WindowManager;"
    FULLSCREEN_SETUP="
        requestWindowFeature(Window.FEATURE_NO_TITLE);

        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        );
"
fi

cat << EOF > "$SRC_DIR/JSBridge.java"
package $PACKAGE_NAME;

import android.content.Context;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.widget.Toast;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import java.net.URI;

public class JSBridge {
    private static final String LOCAL_ASSET_PREFIX = "file:///android_asset/";
    private final Context context;
    private final WebView webView;
    private final String[] trustedOrigins;

    public JSBridge(Context context, WebView webView, String[] trustedOrigins) {
        this.context = context;
        this.webView = webView;
        this.trustedOrigins = trustedOrigins;
    }

    public static boolean isTrustedUrl(String url, String[] trustedOrigins) {
        if (url == null || url.isEmpty()) {
            return false;
        }

        if (url.startsWith("file://")) {
            return true;
        }

        try {
            URI parsedUrl = URI.create(url);
            String origin = normalizeOrigin(parsedUrl);

            if (origin == null) {
                return false;
            }

            for (String trustedOrigin : trustedOrigins) {
                try {
                    URI trustedUri = URI.create(trustedOrigin);
                    String normalizedTrusted = normalizeOrigin(trustedUri);
                    if (normalizedTrusted != null && origin.equals(normalizedTrusted)) {
                        return true;
                    }
                } catch (IllegalArgumentException ignored) {
                    if (origin.equals(trustedOrigin)) {
                        return true;
                    }
                }
            }
        } catch (IllegalArgumentException ignored) {
            return false;
        }

        return false;
    }

    private static String normalizeOrigin(URI uri) {
        String scheme = uri.getScheme();
        String host = uri.getHost();

        if (scheme == null || host == null) {
            return null;
        }

        scheme = scheme.toLowerCase();
        host = host.toLowerCase();
        if (host.startsWith("www.")) {
            host = host.substring(4);
        }

        int port = uri.getPort();
        if (port == -1) {
            return scheme + "://" + host;
        }

        return scheme + "://" + host + ":" + port;
    }

    private boolean canUseBridge() {
        return isTrustedUrl(webView.getUrl(), trustedOrigins);
    }

    @JavascriptInterface
    public void showToast(String message) {
        if (!canUseBridge()) {
            return;
        }

        Toast.makeText(context, message, Toast.LENGTH_SHORT).show();
    }

    @JavascriptInterface
    public boolean isOnline() {
        if (!canUseBridge()) {
            return false;
        }

        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm != null) {
            NetworkInfo netInfo = cm.getActiveNetworkInfo();
            return netInfo != null && netInfo.isConnected();
        }
        return false;
    }
}
EOF

cat << 'JEOF' > "$SRC_DIR/KclibBridge.java"
package PACKAGE_PLACEHOLDER;

public final class KclibBridge {
    static {
        System.loadLibrary("jni");
    }

    public static native String run(String payloadJson);
}
JEOF
sed -i "s/PACKAGE_PLACEHOLDER/$PACKAGE_NAME/" "$SRC_DIR/KclibBridge.java"

cat << EOF > "$SRC_DIR/TrustedWebViewClient.java"
package $PACKAGE_NAME;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class TrustedWebViewClient extends WebViewClient {
    private final Context context;
    private final String[] trustedOrigins;

    public TrustedWebViewClient(Context context, String[] trustedOrigins) {
        this.context = context;
        this.trustedOrigins = trustedOrigins;
    }

    private boolean openExternally(String url) {
        try {
            context.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            return true;
        } catch (Exception ignored) {
            return true;
        }
    }

    private boolean handleNavigation(String url) {
        if (JSBridge.isTrustedUrl(url, trustedOrigins)) {
            return false;
        }

        return openExternally(url);
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        if (!request.isForMainFrame()) {
            return false;
        }

        return handleNavigation(request.getUrl().toString());
    }
}
EOF

cat << EOF > "$SRC_DIR/MainActivity.java"
package $PACKAGE_NAME;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.content.res.Resources;
$FULLSCREEN_IMPORTS

public class MainActivity extends Activity {
    private WebView webView;
    private static final String WEBVIEW_URL = "$WEBVIEW_URL";
    private static final String JS_INTERFACE_NAME = "AndroidBridge";
    private static final String[] TRUSTED_ORIGINS = { $JAVA_TRUSTED_ORIGINS };

    private static final String NATIVE_BRIDGE_SCRIPT =
        "(function(){if(window.NativeBridge){return;}" +
        "var __kcPending={};var __kcSeq=0;" +
        "function __kcReceive(msg){if(msg&&typeof msg.id==='string'){" +
        "var p=__kcPending[msg.id];if(p){delete __kcPending[msg.id];" +
        "if(msg.ok){p.resolve(msg.result!==undefined?msg.result:{ok:true});}" +
        "else{p.reject(msg.error||{code:'INTERNAL_ERROR',message:'Bridge error'});}}return;}}" +
        "window.__kcReceive=__kcReceive;" +
        "window.NativeBridge={};function __kcSend(method,params){" +
        "return new Promise(function(resolve,reject){" +
        "var id=String(++__kcSeq);__kcPending[id]={resolve:resolve,reject:reject};" +
        "KclibBridge.run(JSON.stringify({id:id,method:method,params:params===undefined?null:params}));});}" +
        "window.NativeBridge.invoke=function(method,params){return __kcSend(method,params);};}());";

    @Override
    public void onCreate(Bundle savedInstanceState) {
$FULLSCREEN_SETUP
        super.onCreate(savedInstanceState);
        Resources res = getResources();

        int layoutResId = res.getIdentifier("activity_main", "layout", getPackageName());
        setContentView(layoutResId);

        int webViewResId = res.getIdentifier("webview", "id", getPackageName());
        webView = (WebView) findViewById(webViewResId);

        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.getSettings().setUseWideViewPort(true);
        webView.getSettings().setLoadWithOverviewMode(true);
        webView.setVerticalScrollBarEnabled(false);
        webView.setWebViewClient(new TrustedWebViewClient(this, TRUSTED_ORIGINS));

        webView.addJavascriptInterface(new JSBridge(this, webView, TRUSTED_ORIGINS), JS_INTERFACE_NAME);
        webView.addJavascriptInterface(new KclibBridge(), "KclibBridge");
        webView.loadUrl(WEBVIEW_URL);
    }

    @Override
    public void onPageFinished(WebView view, String url) {
        super.onPageFinished(view, url);
        if (view != null) {
            view.evaluateJavascript(NATIVE_BRIDGE_SCRIPT, null);
        }
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) { webView.goBack(); } else { super.onBackPressed(); }
    }
}
EOF

echo "Compiling Resources with AAPT2..."
"$AAPT2" compile --dir "$RES_DIR" -o "$FLAT_RES_DIR/res.zip" || { echo "Error: AAPT2 Compile failed."; exit 1; }

echo "Linking Resources, Manifest, and Generating R.java..."
"$AAPT2" link \
    --output-text-symbols "$TEMP_CLASSES_DIR/R.txt" \
    -I "$ANDROID_JAR" \
    --manifest "$MANIFEST_FILE" \
    -R "$FLAT_RES_DIR/res.zip" \
    -A "$ASSETS_DIR" \
    -o "$UNSIGNED_APK_TEMP" \
    --java "$TEMP_CLASSES_DIR" \
    --auto-add-overlay || { echo "Error: AAPT2 Link failed."; exit 1; }

echo "Compiling Source Code..."
KCLIB_BRIDGE_FILE="$SRC_DIR/KclibBridge.java"
javac -g:none --release 11 \
    -classpath "$ANDROID_JAR" \
    -d "$TEMP_CLASSES_DIR" \
    "$R_PACKAGE_DIR/R.java" \
    "$WEBVIEW_CLIENT_FILE" \
    "$MAIN_ACTIVITY_FILE" \
    "$JS_INTERFACE_FILE" \
    "$KCLIB_BRIDGE_FILE" || { echo "Error: JAVAC failed."; exit 1; }

echo "Packaging .class files into temporary JAR..."
CURRENT_DIR=$(pwd)
ABS_TEMP_JAR_FILE="$CURRENT_DIR/$TEMP_JAR_FILE"
(cd "$TEMP_CLASSES_DIR" && jar cf "$ABS_TEMP_JAR_FILE" .) || { echo "Error: JAR creation failed."; exit 1; }

echo "Generating Dalvik/ART bytecode..."
TEMP_DEX_WORK_DIR="$TEMP_BUILD_DATA_DIR/temp_dex_work"
mkdir -p "$TEMP_DEX_WORK_DIR"
"$DX" --output "$TEMP_DEX_WORK_DIR" "$ABS_TEMP_JAR_FILE" --min-api "$MIN_SDK" || { rm -rf "$TEMP_DEX_WORK_DIR"; echo "Error: D8/DX failed." ; exit 1; }
mv "$TEMP_DEX_WORK_DIR/classes.dex" "$DEX_FILE"
rm -rf "$TEMP_DEX_WORK_DIR"

if $RELEASE_MODE; then
    download_bundletool
    build_aab

    build_apk

    rm -f "$RES_DIR/temp_icon_file_base"
    rm -rf "$TEMP_ROOT_DIR"

    echo "DUAL BUILD COMPLETE for $DISPLAY_NAME. Both files are in $OUTPUT_DIR/."
    echo "APK Output: $DEBUG_APK_FILE"
    echo "AAB Output: $AAB_SIGNED_FILE"
    echo "INSTALL: adb install -r -t $DEBUG_APK_FILE"
    echo "UNINSTALL: adb uninstall $PACKAGE_NAME"
else
    echo "Starting Debug APK flow for $DISPLAY_NAME."

    build_apk

    rm -f "$RES_DIR/temp_icon_file_base"
    rm -rf "$TEMP_ROOT_DIR"

    echo "APK Compiled! ($DISPLAY_NAME)"
    echo "APK Output: $DEBUG_APK_FILE"
    echo "INSTALL: adb install -r -t $DEBUG_APK_FILE"
    echo "UNINSTALL: adb uninstall $PACKAGE_NAME"
fi
