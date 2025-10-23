#!/bin/sh
#
# APK-BUILDER - Generic Android WebView App Builder (Bash/CLI)
# Copyright (C) 2025 [KaisarCode]
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

#====================================================================
# --- GLOBAL CONFIGURATION VARIABLES ---
#====================================================================

DISPLAY_NAME="My App"
PROJECT_NAME="myapp"
PACKAGE_NAME="com.kaisarcode.myapp"
WEBVIEW_URL="https://google.com/"
ICON_SOURCE_FILE="./icon.svg"
IS_FULLSCREEN="false"
VERSION_CODE=1
VERSION_NAME="1.0"
TARGET_SDK="34"
MIN_SDK="24"

BUILD_TOOLS_VERSION="34.0.0"
PLATFORM_VERSION="android-$TARGET_SDK"
SDK_ZIP="commandlinetools.zip"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

BASE_DIR="./$PROJECT_NAME"
PACKAGE_SUBPATH="$(echo $PACKAGE_NAME | tr . /)"
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

# Final output directory for APK/AAB
OUTPUT_DIR="$BASE_DIR/bin"
TEMP_ROOT_DIR="$BASE_DIR/temp"
TEMP_CLASSES_DIR="$TEMP_ROOT_DIR/classes"
FLAT_RES_DIR="$TEMP_ROOT_DIR/resources"
TEMP_BUILD_DATA_DIR="$TEMP_ROOT_DIR/build_data"
AAB_TEMP_DIR="$TEMP_ROOT_DIR/aab_work"

R_PACKAGE_DIR="$TEMP_CLASSES_DIR/$PACKAGE_SUBPATH"
TEMP_JAR_FILE="$TEMP_BUILD_DATA_DIR/classes.jar"
DEX_FILE="$TEMP_BUILD_DATA_DIR/classes.dex"

ANDROID_SDK_ROOT="$HOME/android-sdk"
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

# --- DEBUG APK WORKING VARIABLES ---
# Intermediate files are placed in TEMP_ROOT_DIR
UNSIGNED_APK_TEMP="$TEMP_ROOT_DIR/unsigned.apk"
ALIGNED_APK_TEMP="$TEMP_ROOT_DIR/aligned.apk"
DEBUG_APK_FILE="$OUTPUT_DIR/$PROJECT_NAME.apk"

# --- RELEASE AAB VARIABLES ---
BUNDLETOOL_VERSION="1.18.2"
BUNDLETOOL_JAR="$BASE_DIR/bundletool-all-$BUNDLETOOL_VERSION.jar"
BUNDLETOOL_URL="https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
AAB_UNSIGNED_FILE="$TEMP_ROOT_DIR/unsigned.aab"
AAB_SIGNED_FILE="$OUTPUT_DIR/$PROJECT_NAME.aab"
BASE_MODULE_ZIP="$AAB_TEMP_DIR/base.zip"
FINAL_MODULE_DIR="$AAB_TEMP_DIR/final_module"
SIGNING_REQUIRED="false"

#====================================================================
# --- COMMAND LINE ARGUMENT PARSING ---
#====================================================================

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
        *)
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

echo "Starting the Android compilation and automation script on Ubuntu..."
echo "--------------------------------------------------------------------"

#====================================================================
# --- FUNCTIONS (SDK & RELEASE) ---
#====================================================================

setup_sdk () {
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
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

# Function to download bundletool.jar if not present or if version mismatch
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

    echo "===================================================================="
    echo "BUNDLETOOL Not Found or Version Mismatch. Downloading $BUNDLETOOL_VERSION..."
    echo "URL: $BUNDLETOOL_URL"
    echo "===================================================================="
    wget -q --show-progress "$BUNDLETOOL_URL" -O "$EXPECTED_JAR" || { echo "Error: Failed to download bundletool. Check URL or internet connection." ; exit 1; }

    BUNDLETOOL_JAR="$EXPECTED_JAR"
    echo "BUNDLETOOL downloaded successfully."
}

# Function to check for signing credentials
setup_release_signing () {
    if [ -n "$RELEASE_KEYSTORE" ] && [ -n "$RELEASE_KEY_ALIAS" ] && \
       [ -n "$RELEASE_STORE_PASS" ] && [ -n "$RELEASE_KEY_PASS" ]; then

        if [ ! -f "$RELEASE_KEYSTORE" ]; then
            echo "FATAL ERROR: Release KeyStore file not found at: $RELEASE_KEYSTORE"
            exit 1
        fi

        echo "=> Release KeyStore credentials found in environment."
        SIGNING_REQUIRED="true"
    else
        echo "=> Release KeyStore credentials NOT found in environment. AAB will be generated unsigned."
    fi
}

# Function to perform the multi-step AAB build process
build_aab () {
    echo "===================================================================="
    echo "Starting AAB Generation for $DISPLAY_NAME (v$VERSION_NAME - $VERSION_CODE)"
    echo "--------------------------------------------------------------------"

    # --- SETUP SIGNING ---
    setup_release_signing

    ABS_BASE_MODULE_ZIP="$(pwd)/$BASE_MODULE_ZIP"

    if [ ! -f "$DEX_FILE" ]; then
        echo "FATAL ERROR: classes.dex (compiled code) not found. Ensure the common build steps ran successfully."
        exit 1
    fi

    # --- Setup: Create Working Directories ---
    mkdir -p "$FINAL_MODULE_DIR"

    # --- 1. LINK RESOURCES AND BUILD FINAL MODULE STRUCTURE ---
    echo "1.1. Linking resources and manifest into temporary module zip (Protobuf format)..."

    # Rerunning AAPT2 Link
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

    echo "1.2. Unzipping temporary module zip into final module directory..."
    unzip -q "$FINAL_MODULE_DIR/base_temp.zip" -d "$FINAL_MODULE_DIR"
    rm "$FINAL_MODULE_DIR/base_temp.zip"

    # --- 2. STRUCTURING THE BASE MODULE DIRECTORY ---
    echo "2.1. Structuring the base module directory (Finalizing structure)..."

    # Move Manifest
    mkdir -p "$FINAL_MODULE_DIR/manifest"
    mv "$FINAL_MODULE_DIR/AndroidManifest.xml" "$FINAL_MODULE_DIR/manifest/AndroidManifest.xml"

    # Copy DEX
    mkdir -p "$FINAL_MODULE_DIR/dex"
    cp "$DEX_FILE" "$FINAL_MODULE_DIR/dex/classes.dex"

    # --- 3. CREATE THE FINAL MODULE ZIP ---
    echo "3.1. Re-packaging structured module into base.zip..."

    MODULE_CONTENTS="manifest res dex resources.pb"
    if [ -d "$FINAL_MODULE_DIR/assets" ]; then
        MODULE_CONTENTS="$MODULE_CONTENTS assets"
    fi

    (cd "$FINAL_MODULE_DIR" && zip -r -q "$ABS_BASE_MODULE_ZIP" $MODULE_CONTENTS) || { echo "Error: ZIP tool failed to re-package module."; exit 1; }

    # --- 4. GENERATE THE AAB FILE (UNSIGNED) ---
    echo "4.1. Generating UNsigned .aab file using bundletool..."

    java -jar "$BUNDLETOOL_JAR" build-bundle \
        --modules="$BASE_MODULE_ZIP" \
        --output="$AAB_UNSIGNED_FILE" || { echo "Error: bundletool failed to generate AAB."; exit 1; }

    # --- 5. SIGN THE AAB USING JARSIGNER ---
    if [ "$SIGNING_REQUIRED" = "true" ]; then
        echo "5.1. Signing the AAB using jarsigner..."

        jarsigner -verbose \
            -sigalg SHA256withRSA \
            -digestalg SHA-256 \
            -keystore "$RELEASE_KEYSTORE" \
            -storepass "$RELEASE_STORE_PASS" \
            -keypass "$RELEASE_KEY_PASS" \
            "$AAB_UNSIGNED_FILE" "$RELEASE_KEY_ALIAS" || { echo "Error: jarsigner failed to sign the AAB. Check your passwords/keytool installation." ; exit 1; }

        # Renaming the file (jarsigner signs in place)
        mv "$AAB_UNSIGNED_FILE" "$AAB_SIGNED_FILE" # OVERWRITES FINAL AAB
    else
        # If no key is present, the unsigned file is renamed to the final name.
        mv "$AAB_UNSIGNED_FILE" "$AAB_SIGNED_FILE"
        echo "5.1. Skipping signing. Final AAB is generated without a signature (ready for Google Play App Signing)."
    fi

    echo "AAB Output: $AAB_SIGNED_FILE"

    # Clean up AAB specific temporary working directory
    rm -rf "$AAB_TEMP_DIR"
}

# Function to perform the debug APK build process
build_apk () {
    echo "5.4. Inserting classes.dex into APK..."
    zip -j "$UNSIGNED_APK_TEMP" "$DEX_FILE" || { echo "Error: ZIP tool failed to insert classes.dex." ; exit 1; }

    echo "5.5. Generating debug KeyStore if it does not exist..."
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        keytool -genkey -v -keystore "$DEBUG_KEYSTORE" \
            -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US"
        echo "Debug KeyStore successfully generated."
    else
        echo "Debug KeyStore found. Using existing KeyStore."
    fi

    echo "5.6. Aligning and Signing the Debug APK (Output: $DEBUG_APK_FILE)..."

    "$ZIPALIGN" -f 4 "$UNSIGNED_APK_TEMP" "$ALIGNED_APK_TEMP"
    if [ $? -ne 0 ]; then echo "Error: ZIPALIGN failed." ; exit 1; fi

    "$APKSIGNER" sign --ks "$DEBUG_KEYSTORE" \
        --ks-key-alias androiddebugkey \
        --ks-pass pass:android \
        --key-pass pass:android \
        --out "$DEBUG_APK_FILE" "$ALIGNED_APK_TEMP" || { echo "Error: APKSIGNER failed."; exit 1; }

    echo "APK Output: $DEBUG_APK_FILE"
}

#====================================================================
# --- MAIN EXECUTION START ---
#====================================================================

setup_sdk

# --- SETUP DIRECTORIES AND CLEANUP TEMPORARY FILES ---
mkdir -p "$SRC_DIR" "$LAYOUT_DIR" "$VALUES_DIR" "$OUTPUT_DIR" "$ASSETS_DIR" \
             "$MIPMAP_MDPI_DIR" "$MIPMAP_HDPI_DIR" "$MIPMAP_XHDPI_DIR" \
             "$MIPMAP_XXHDPI_DIR" "$MIPMAP_XXXHDPI_DIR"
rm -rf "$TEMP_ROOT_DIR"
mkdir -p "$TEMP_CLASSES_DIR" "$FLAT_RES_DIR" "$R_PACKAGE_DIR" "$TEMP_BUILD_DATA_DIR" "$AAB_TEMP_DIR"

echo "--------------------------------------------------------------------"
echo "Starting Icon Generation from LOCAL FILE ($ICON_SOURCE_FILE)..."

if [ ! -f "$ICON_SOURCE_FILE" ]; then
    echo "Error: Icon file not found at $ICON_SOURCE_FILE."
    exit 1
fi

DENSITY_PAIRS="mdpi:48x48 hdpi:72x72 xhdpi:96x96 xxhdpi:144x144 xxxhdpi:192x192"

ICON_TEMP_FILE="$RES_DIR/temp_icon_file_base"

cp "$ICON_SOURCE_FILE" "$ICON_TEMP_FILE" || { echo "Error: Failed to copy local icon file." ; exit 1; }

if command -v convert >/dev/null 2>&1
then
    for PAIR in $DENSITY_PAIRS; do
        DENSITY=$(echo "$PAIR" | cut -d: -f1)
        SIZE=$(echo "$PAIR" | cut -d: -f2)

        MIPMAP_SUBDIR="$RES_DIR/mipmap-$DENSITY"
        ICON_FINAL_PNG="$MIPMAP_SUBDIR/ic_launcher.png"

        convert "$ICON_TEMP_FILE" -resize "$SIZE" "$ICON_FINAL_PNG" || { echo "Error: ImageMagick conversion failed for $DENSITY." ; exit 1; }
    done
else
    echo "Error: 'convert' (ImageMagick) not found. Cannot generate icons."
    exit 1
fi

rm "$ICON_TEMP_FILE"

echo "Icon Generation complete."
echo "--------------------------------------------------------------------"

ORIGINAL_WEBVIEW_URL="$WEBVIEW_URL"

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

echo "--------------------------------------------------------------------"
echo "Writing Manifest, Strings, and Layout files..."
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
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">
        <activity
            android:name="$PACKAGE_NAME.MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize">
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
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">
    <WebView
        android:id="@+id/webview"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
</LinearLayout>
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
import android.widget.Toast;

public class JSBridge {
    private final Context context;
    public JSBridge(Context context) { this.context = context; }
    @JavascriptInterface
    public void showToast(String message) { Toast.makeText(context, message, Toast.LENGTH_LONG).show(); }
    @JavascriptInterface
    public String getNativeVersion() { return "Android Native Version (API $TARGET_SDK)"; }
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
        webView.setWebViewClient(new WebViewClient());

        webView.addJavascriptInterface( new JSBridge(this), JS_INTERFACE_NAME );
        webView.loadUrl(WEBVIEW_URL);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) { webView.goBack(); } else { super.onBackPressed(); }
    }
}
EOF

#====================================================================
# --- COMMON COMPILE & DEX STEPS ---
#====================================================================
echo "5.1a. Compiling Resources with AAPT2..."
"$AAPT2" compile --dir "$RES_DIR" -o "$FLAT_RES_DIR/res.zip" || { echo "Error: AAPT2 Compile failed."; exit 1; }

echo "5.1b. Linking Resources, Manifest, and Generating R.java (Output: $UNSIGNED_APK_TEMP)..."
# Output is to the temporary unsigned APK path
"$AAPT2" link \
    --output-text-symbols "$TEMP_CLASSES_DIR/R.txt" \
    -I "$ANDROID_JAR" \
    --manifest "$MANIFEST_FILE" \
    -R "$FLAT_RES_DIR/res.zip" \
    -A "$ASSETS_DIR" \
    -o "$UNSIGNED_APK_TEMP" \
    --java "$TEMP_CLASSES_DIR" \
    --auto-add-overlay || { echo "Error: AAPT2 Link failed."; exit 1; }

echo "5.2. Compiling Source Code..."
javac -source 1.8 -target 1.8 -bootclasspath "$ANDROID_JAR" \
    -classpath "$ANDROID_JAR" \
    -d "$TEMP_CLASSES_DIR" \
    "$R_PACKAGE_DIR/R.java" \
    "$MAIN_ACTIVITY_FILE" \
    "$JS_INTERFACE_FILE" || { echo "Error: JAVAC failed."; exit 1; }

echo "5.2b. Packaging .class files into temporary JAR..."
CURRENT_DIR=$(pwd)
ABS_TEMP_JAR_FILE="$CURRENT_DIR/$TEMP_JAR_FILE"
(cd "$TEMP_CLASSES_DIR" && jar cf "$ABS_TEMP_JAR_FILE" .) || { echo "Error: JAR creation failed."; exit 1; }

echo "5.3. Generating Dalvik/ART bytecode..."
TEMP_DEX_WORK_DIR="$TEMP_BUILD_DATA_DIR/temp_dex_work"
mkdir -p "$TEMP_DEX_WORK_DIR"
"$DX" --output "$TEMP_DEX_WORK_DIR" "$ABS_TEMP_JAR_FILE" --min-api "$MIN_SDK"
if [ $? -ne 0 ]; then rm -rf "$TEMP_DEX_WORK_DIR"; echo "Error: D8/DX failed." ; exit 1; fi
mv "$TEMP_DEX_WORK_DIR/classes.dex" "$DEX_FILE"
rm -rf "$TEMP_DEX_WORK_DIR"

#====================================================================
# --- BUILD MODE BRANCHING ---
#====================================================================

if $RELEASE_MODE; then
    echo "===================================================================="
    echo "Starting DUAL AAB & APK Release Build Flow."
    echo "===================================================================="

    # 1. Build AAB
    download_bundletool
    build_aab

    echo "AAB Successfully Compiled and Signed!"
    echo "--------------------------------------------------------------------"

    # 2. Build APK
    build_apk

    # --- CLEANUP ---
    echo "6. Cleaning up common temporary files ($TEMP_ROOT_DIR)..."
    rm -f "$RES_DIR/temp_icon_file_base"
    rm -rf "$TEMP_ROOT_DIR"

    echo "===================================================================="
    echo "DUAL BUILD COMPLETE for $DISPLAY_NAME. Both files are in $OUTPUT_DIR/."
    echo "APK Output: $DEBUG_APK_FILE"
    echo "AAB Output: $AAB_SIGNED_FILE"
    echo "INSTALL: adb install -r -t $DEBUG_APK_FILE"
    echo "UNINSTALL: adb uninstall $PACKAGE_NAME"
    echo "===================================================================="
else
    # --- DEVELOPMENT FLOW ---
    echo "===================================================================="
    echo "Starting Debug APK flow for $DISPLAY_NAME."
    echo "===================================================================="

    # Build APK
    build_apk

    # --- CLEANUP ---
    echo "6. Cleaning up intermediate files and $TEMP_ROOT_DIR..."
    rm -f "$RES_DIR/temp_icon_file_base"
    rm -rf "$TEMP_ROOT_DIR"

    echo "===================================================================="
    echo "APK Compiled! ($DISPLAY_NAME)"
    echo "APK Output: $DEBUG_APK_FILE"
    echo "INSTALL: adb install -r -t $DEBUG_APK_FILE"
    echo "UNINSTALL: adb uninstall $PACKAGE_NAME"
    echo "===================================================================="
fi
