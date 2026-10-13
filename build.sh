#!/bin/sh
# build.sh
# Summary: Generic Android WebView APK/AAB builder.
# Author:  KaisarCode
# Website: https://kaisarcode.com
# License: https://www.gnu.org/licenses/lgpl-3.0.html

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
KCAPK_SRC_DIR="$SCRIPT_DIR/src"

DISPLAY_NAME="${DISPLAY_NAME:-My App}"
PROJECT_NAME="${PROJECT_NAME:-myapp}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
PACKAGE_NAME="${PACKAGE_NAME:-com.kaisarcode.myapp}"
WEBVIEW_URL="${WEBVIEW_URL:-https://google.com/}"
ICON_SOURCE_FILE="${ICON_SOURCE_FILE:-$KCAPK_SRC_DIR/assets/icon.svg}"
ICON_BACKGROUND="${ICON_BACKGROUND:-#000000}"
BACKGROUND="${BACKGROUND:-#101010}"
TRUSTED_ORIGINS="${TRUSTED_ORIGINS:-}"
IS_FULLSCREEN="${IS_FULLSCREEN:-false}"
VERSION_CODE="${VERSION_CODE:-1}"
VERSION_NAME="${VERSION_NAME:-1.0}"
TARGET_SDK="36"
MIN_SDK="24"
BUILD_TOOLS_VERSION="36.0.0"
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

CLEAN_ALL=false
RELEASE_MODE=false
EXECUTABLES=""
PERMISSIONS=""
SHARE_TARGETS=""
CLI_TRUSTED_ORIGINS_SET=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --display-name)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --display-name requires a value." >&2; exit 1; }
            DISPLAY_NAME="$1"
            shift
            ;;
        --project-name)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --project-name requires a value." >&2; exit 1; }
            PROJECT_NAME="$1"
            shift
            ;;
        --output-path)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --output-path requires a value." >&2; exit 1; }
            OUTPUT_PATH="$1"
            shift
            ;;
        --package-name)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --package-name requires a value." >&2; exit 1; }
            PACKAGE_NAME="$1"
            shift
            ;;
        --webview-url)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --webview-url requires a value." >&2; exit 1; }
            WEBVIEW_URL="$1"
            shift
            ;;
        --icon)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --icon requires a path or URL." >&2; exit 1; }
            ICON_SOURCE_FILE="$1"
            shift
            ;;
        --icon-background)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --icon-background requires a color." >&2; exit 1; }
            ICON_BACKGROUND="$1"
            shift
            ;;
        --background)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --background requires a color." >&2; exit 1; }
            BACKGROUND="$1"
            shift
            ;;
        --trusted-origin)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --trusted-origin requires an origin." >&2; exit 1; }
            if ! $CLI_TRUSTED_ORIGINS_SET; then
                TRUSTED_ORIGINS=""
                CLI_TRUSTED_ORIGINS_SET=true
            fi
            if [ -n "$TRUSTED_ORIGINS" ]; then
                TRUSTED_ORIGINS="$TRUSTED_ORIGINS
$1"
            else
                TRUSTED_ORIGINS="$1"
            fi
            shift
            ;;
        --permission)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --permission requires a value." >&2; exit 1; }
            if [ -n "$PERMISSIONS" ]; then
                PERMISSIONS="$PERMISSIONS
$1"
            else
                PERMISSIONS="$1"
            fi
            shift
            ;;
        --share-target)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --share-target requires a MIME type." >&2; exit 1; }
            if [ -n "$SHARE_TARGETS" ]; then
                SHARE_TARGETS="$SHARE_TARGETS
$1"
            else
                SHARE_TARGETS="$1"
            fi
            shift
            ;;
        --fullscreen)
            IS_FULLSCREEN=true
            shift
            ;;
        --version-code)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --version-code requires a value." >&2; exit 1; }
            VERSION_CODE="$1"
            shift
            ;;
        --version-name)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --version-name requires a value." >&2; exit 1; }
            VERSION_NAME="$1"
            shift
            ;;
        --clean)
            CLEAN_ALL=true
            echo "Argument --clean detected. Forcing KeyStore and temporary files deletion."
            shift
            ;;
        --release)
            RELEASE_MODE=true
            echo "Argument --release detected. Preparing for DUAL AAB/APK build."
            shift
            ;;
        --exec)
            shift
            [ "$#" -gt 0 ] || { echo "Error: --exec requires a path." >&2; exit 1; }
            if [ -n "$EXECUTABLES" ]; then
                EXECUTABLES="$EXECUTABLES
$1"
            else
                EXECUTABLES="$1"
            fi
            shift
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [ -n "$BACKGROUND" ]; then
    if ! printf '%s\n' "$BACKGROUND" | grep -Eq '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$'; then
        printf 'Error: --background must use \043RRGGBB or \043AARRGGBB.\n' >&2
        exit 1
    fi
fi

BASE_DIR="${OUTPUT_PATH:-./build/$PROJECT_NAME}"
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
MIPMAP_ANYDPI_V26_DIR="$RES_DIR/mipmap-anydpi-v26"

OUTPUT_DIR="$BASE_DIR/bin"
TEMP_ROOT_DIR="$BASE_DIR/temp"
TEMP_CLASSES_DIR="$TEMP_ROOT_DIR/classes"
FLAT_RES_DIR="$TEMP_ROOT_DIR/resources"
TEMP_BUILD_DATA_DIR="$TEMP_ROOT_DIR/build_data"
AAB_TEMP_DIR="$TEMP_ROOT_DIR/aab_work"
NATIVE_LIBS_DIR="$TEMP_ROOT_DIR/native_libs"

R_PACKAGE_DIR="$TEMP_CLASSES_DIR/$PACKAGE_SUBPATH"
TEMP_JAR_FILE="$TEMP_BUILD_DATA_DIR/classes.jar"
DEX_FILE="$TEMP_BUILD_DATA_DIR/classes.dex"

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

# Resolves a build-time permission alias to an Android permission name.
# @param $1 Permission alias or android.permission.* name.
# @return Prints the Android permission name or fails.
resolve_permission_name () {
    case "$1" in
        notifications) printf '%s\n' android.permission.POST_NOTIFICATIONS ;;
        exactAlarm|exactAlarms) printf '%s\n' android.permission.SCHEDULE_EXACT_ALARM ;;
        camera) printf '%s\n' android.permission.CAMERA ;;
        microphone) printf '%s\n' android.permission.RECORD_AUDIO ;;
        location|locationFine) printf '%s\n' android.permission.ACCESS_FINE_LOCATION ;;
        locationCoarse) printf '%s\n' android.permission.ACCESS_COARSE_LOCATION ;;
        android.permission.*)
            [ "$1" != "android.permission." ] || return 1
            case "$1" in
                *[!A-Za-z0-9._]*) return 1 ;;
            esac
            printf '%s\n' "$1"
            ;;
        *) return 1 ;;
    esac
}

# Generates optional uses-permission declarations for the manifest template.
# @return None.
prepare_permissions () {
    PERMISSION_DECLARATIONS_FILE="$TEMP_ROOT_DIR/permissions.xml"
    : > "$PERMISSION_DECLARATIONS_FILE"
    SEEN_PERMISSIONS=""

    [ -n "$PERMISSIONS" ] || return

    while IFS= read -r PERMISSION_NAME; do
        [ -n "$PERMISSION_NAME" ] || continue
        RESOLVED_PERMISSION=$(resolve_permission_name "$PERMISSION_NAME") || {
            echo "Error: Unknown permission alias: $PERMISSION_NAME. Use a supported alias or android.permission.*." >&2
            exit 1
        }

        case "$RESOLVED_PERMISSION" in
            android.permission.INTERNET|\
            android.permission.ACCESS_NETWORK_STATE|\
            android.permission.RECEIVE_BOOT_COMPLETED|\
            android.permission.VIBRATE)
                continue
                ;;
        esac

        case " $SEEN_PERMISSIONS " in
            *" $RESOLVED_PERMISSION "*)
                continue
                ;;
        esac
        SEEN_PERMISSIONS="$SEEN_PERMISSIONS $RESOLVED_PERMISSION"
        printf '    <uses-permission android:name="%s" />\n' "$RESOLVED_PERMISSION" >> "$PERMISSION_DECLARATIONS_FILE"
    done <<EOF
$PERMISSIONS
EOF
}

# Generates optional Android share target intent filters for the manifest template.
# @return None.
prepare_share_targets () {
    SHARE_TARGET_DECLARATIONS_FILE="$TEMP_ROOT_DIR/share_targets.xml"
    : > "$SHARE_TARGET_DECLARATIONS_FILE"
    SEEN_SHARE_TARGETS=""

    [ -n "$SHARE_TARGETS" ] || return

    printf '%s\n' '            <intent-filter>' >> "$SHARE_TARGET_DECLARATIONS_FILE"
    printf '%s\n' '                <action android:name="android.intent.action.SEND" />' >> "$SHARE_TARGET_DECLARATIONS_FILE"
    printf '%s\n' '                <action android:name="android.intent.action.SEND_MULTIPLE" />' >> "$SHARE_TARGET_DECLARATIONS_FILE"
    printf '%s\n' '                <category android:name="android.intent.category.DEFAULT" />' >> "$SHARE_TARGET_DECLARATIONS_FILE"

    while IFS= read -r MIME_TYPE; do
        [ -n "$MIME_TYPE" ] || continue
        if ! printf '%s\n' "$MIME_TYPE" | grep -Eq '^[A-Za-z0-9.+*-]+/[A-Za-z0-9.+*-]+$'; then
            echo "Error: Invalid MIME type for --share-target: $MIME_TYPE" >&2
            exit 1
        fi

        case " $SEEN_SHARE_TARGETS " in
            *" $MIME_TYPE "*)
                continue
                ;;
        esac
        SEEN_SHARE_TARGETS="$SEEN_SHARE_TARGETS $MIME_TYPE"
        printf '                <data android:mimeType="%s" />\n' "$MIME_TYPE" >> "$SHARE_TARGET_DECLARATIONS_FILE"
    done <<EOF
$SHARE_TARGETS
EOF

    printf '%s\n' '            </intent-filter>' >> "$SHARE_TARGET_DECLARATIONS_FILE"
}

# Detects the Android ABI of an ELF executable.
# @param $1 Executable path.
# @return Prints the Android ABI name or fails.
detect_exec_abi () {
    EXEC_FILE_INFO=$(file -b "$1" 2>/dev/null) || return 1

    case "$EXEC_FILE_INFO" in
        *aarch64*|*AArch64*) printf '%s\n' arm64-v8a ;;
        *ARM*) printf '%s\n' armeabi-v7a ;;
        *x86-64*|*x86_64*) printf '%s\n' x86_64 ;;
        *80386*) printf '%s\n' x86 ;;
        *) return 1 ;;
    esac
}

# Packages executables requested with --exec and prepares the Java whitelist.
# @return None.
prepare_executables () {
    JAVA_EXECUTABLE_NAMES=""
    EXECUTABLE_NAMES=""
    EXECUTABLE_TARGETS=""

    [ -n "$EXECUTABLES" ] || return
    command -v file >/dev/null 2>&1 || { echo "Error: 'file' is required when using --exec." >&2; exit 1; }

    while IFS= read -r EXEC_PATH; do
        [ -n "$EXEC_PATH" ] || continue
        [ -f "$EXEC_PATH" ] || { echo "Error: Executable not found: $EXEC_PATH" >&2; exit 1; }

        EXEC_NAME=$(basename "$EXEC_PATH")
        case "$EXEC_NAME" in
            ''|*[!A-Za-z0-9._-]*)
                echo "Error: Invalid executable name: $EXEC_NAME" >&2
                exit 1
                ;;
        esac

        EXEC_ABI=$(detect_exec_abi "$EXEC_PATH") || {
            echo "Error: Unsupported executable architecture: $EXEC_PATH" >&2
            exit 1
        }

        EXEC_TARGET="$EXEC_NAME@$EXEC_ABI"
        case " $EXECUTABLE_TARGETS " in
            *" $EXEC_TARGET "*)
                echo "Error: Duplicate executable target: $EXEC_NAME ($EXEC_ABI)" >&2
                exit 1
                ;;
        esac
        EXECUTABLE_TARGETS="$EXECUTABLE_TARGETS $EXEC_TARGET"

        EXEC_PACKAGE_NAME=$(printf '%s' "$EXEC_NAME" | tr '.-' '__')
        EXEC_PACKAGE_FILE="libexec_${EXEC_PACKAGE_NAME}.so"
        EXEC_PACKAGE_DIR="$NATIVE_LIBS_DIR/lib/$EXEC_ABI"
        mkdir -p "$EXEC_PACKAGE_DIR"
        cp "$EXEC_PATH" "$EXEC_PACKAGE_DIR/$EXEC_PACKAGE_FILE" || exit 1

        case " $EXECUTABLE_NAMES " in
            *" $EXEC_NAME "*)
                ;;
            *)
                EXECUTABLE_NAMES="$EXECUTABLE_NAMES $EXEC_NAME"
                if [ -n "$JAVA_EXECUTABLE_NAMES" ]; then
                    JAVA_EXECUTABLE_NAMES="$JAVA_EXECUTABLE_NAMES, "
                fi
                JAVA_EXECUTABLE_NAMES="$JAVA_EXECUTABLE_NAMES\"$EXEC_NAME\""
                ;;
        esac

        echo "Including executable: $EXEC_NAME ($EXEC_ABI)"
    done <<EOF
$EXECUTABLES
EOF
}

# Escapes a value for a sed replacement using # as the delimiter.
# @param $1 Replacement value.
# @return Prints the escaped replacement.
escape_template_value () {
    printf '%s' "$1" | sed 's/[\\&#]/\\&/g'
}

# Renders one source template into the generated Android project.
# @param $1 Template path.
# @param $2 Destination path.
# @return None.
render_template () {
    TEMPLATE_FILE="$1"
    DESTINATION_FILE="$2"

    [ -f "$TEMPLATE_FILE" ] || { echo "Error: Source template not found: $TEMPLATE_FILE" >&2; exit 1; }
    mkdir -p "$(dirname "$DESTINATION_FILE")"

    PACKAGE_VALUE=$(escape_template_value "$PACKAGE_NAME")
    VERSION_CODE_VALUE=$(escape_template_value "$VERSION_CODE")
    VERSION_NAME_VALUE=$(escape_template_value "$VERSION_NAME")
    DISPLAY_NAME_VALUE=$(escape_template_value "$DISPLAY_NAME")
    ICON_BACKGROUND_VALUE=$(escape_template_value "$ICON_BACKGROUND")
    BACKGROUND_VALUE=$(escape_template_value "$BACKGROUND")
    APP_THEME_VALUE=$(escape_template_value "$APP_THEME")
    WEBVIEW_URL_VALUE=$(escape_template_value "$WEBVIEW_URL")
    TRUSTED_ORIGINS_VALUE=$(escape_template_value "$JAVA_TRUSTED_ORIGINS")
    EXECUTABLE_NAMES_VALUE=$(escape_template_value "$JAVA_EXECUTABLE_NAMES")
    FULLSCREEN_VALUE=$(escape_template_value "$IS_FULLSCREEN")
    MIN_SDK_VALUE=$(escape_template_value "$MIN_SDK")
    TARGET_SDK_VALUE=$(escape_template_value "$TARGET_SDK")

    sed \
        -e "s#@PACKAGE_NAME@#$PACKAGE_VALUE#g" \
        -e "s#@VERSION_CODE@#$VERSION_CODE_VALUE#g" \
        -e "s#@VERSION_NAME@#$VERSION_NAME_VALUE#g" \
        -e "s#@DISPLAY_NAME@#$DISPLAY_NAME_VALUE#g" \
        -e "s#@ICON_BACKGROUND@#$ICON_BACKGROUND_VALUE#g" \
        -e "s#@BACKGROUND@#$BACKGROUND_VALUE#g" \
        -e "s#@APP_THEME@#$APP_THEME_VALUE#g" \
        -e "s#@WEBVIEW_URL@#$WEBVIEW_URL_VALUE#g" \
        -e "s#@TRUSTED_ORIGINS@#$TRUSTED_ORIGINS_VALUE#g" \
        -e "s#@EXECUTABLE_NAMES@#$EXECUTABLE_NAMES_VALUE#g" \
        -e "s#@IS_FULLSCREEN@#$FULLSCREEN_VALUE#g" \
        -e "s#@MIN_SDK@#$MIN_SDK_VALUE#g" \
        -e "s#@TARGET_SDK@#$TARGET_SDK_VALUE#g" \
        "$TEMPLATE_FILE" > "$DESTINATION_FILE" || { echo "Error: Failed to render template: $TEMPLATE_FILE" >&2; exit 1; }
}

# Copies and renders the Android source tree used by generated apps.
# @return None.
prepare_source_templates () {
    JAVA_TEMPLATE_DIR="$KCAPK_SRC_DIR/java"
    RESOURCE_TEMPLATE_DIR="$KCAPK_SRC_DIR/res"
    MANIFEST_TEMPLATE="$KCAPK_SRC_DIR/AndroidManifest.xml.in"
    RESOURCE_TEMPLATE_LIST="$TEMP_ROOT_DIR/resource_templates.list"

    [ -d "$JAVA_TEMPLATE_DIR" ] || { echo "Error: Java source template directory not found: $JAVA_TEMPLATE_DIR" >&2; exit 1; }
    [ -d "$RESOURCE_TEMPLATE_DIR" ] || { echo "Error: Resource template directory not found: $RESOURCE_TEMPLATE_DIR" >&2; exit 1; }

    echo "Writing Android source templates..."
    render_template "$MANIFEST_TEMPLATE" "$MANIFEST_FILE"

    MANIFEST_DYNAMIC_TEMP="$TEMP_ROOT_DIR/AndroidManifest.dynamic"
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in
            *'@PERMISSIONS@'*)
                cat "$PERMISSION_DECLARATIONS_FILE"
                ;;
            *'@SHARE_TARGETS@'*)
                cat "$SHARE_TARGET_DECLARATIONS_FILE"
                ;;
            *)
                printf '%s\n' "$LINE"
                ;;
        esac
    done < "$MANIFEST_FILE" > "$MANIFEST_DYNAMIC_TEMP"
    mv "$MANIFEST_DYNAMIC_TEMP" "$MANIFEST_FILE"

    for TEMPLATE_FILE in "$JAVA_TEMPLATE_DIR"/*.java.in; do
        [ -f "$TEMPLATE_FILE" ] || continue
        TARGET_NAME=$(basename "$TEMPLATE_FILE" .in)
        render_template "$TEMPLATE_FILE" "$SRC_DIR/$TARGET_NAME"
    done

    cp -R "$RESOURCE_TEMPLATE_DIR/." "$RES_DIR/" || { echo "Error: Failed to copy Android resource templates." >&2; exit 1; }
    find "$RES_DIR" -type f -name '*.in' -print > "$RESOURCE_TEMPLATE_LIST" || { echo "Error: Failed to enumerate Android resource templates." >&2; exit 1; }
    while IFS= read -r TEMPLATE_FILE; do
        [ -n "$TEMPLATE_FILE" ] || continue
        DESTINATION_FILE=${TEMPLATE_FILE%.in}
        render_template "$TEMPLATE_FILE" "$DESTINATION_FILE"
        rm -f "$TEMPLATE_FILE"
    done < "$RESOURCE_TEMPLATE_LIST"
    rm -f "$RESOURCE_TEMPLATE_LIST"

    if [ -z "$BACKGROUND" ]; then
        rm -f "$VALUES_DIR/app_colors.xml" "$VALUES_DIR/styles.xml"
    fi
}

# Builds the Android App Bundle.
# @return None.
build_aab () {
    setup_release_signing

    case "$BASE_MODULE_ZIP" in
        /*) ABS_BASE_MODULE_ZIP="$BASE_MODULE_ZIP" ;;
        *)  ABS_BASE_MODULE_ZIP="$(pwd)/$BASE_MODULE_ZIP" ;;
    esac

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

    if [ -d "$NATIVE_LIBS_DIR/lib" ]; then
        cp -r "$NATIVE_LIBS_DIR/lib" "$FINAL_MODULE_DIR/"
    fi

    (
        cd "$FINAL_MODULE_DIR" || exit 1
        set -- manifest res dex resources.pb
        [ -d assets ] && set -- "$@" assets
        [ -d lib ] && set -- "$@" lib
        zip -r -q "$ABS_BASE_MODULE_ZIP" "$@"
    ) || { echo "Error: ZIP tool failed to re-package module."; exit 1; }

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

    if [ -d "$NATIVE_LIBS_DIR/lib" ]; then
        case "$UNSIGNED_APK_TEMP" in
            /*) ABS_UNSIGNED_APK_TEMP="$UNSIGNED_APK_TEMP" ;;
            *) ABS_UNSIGNED_APK_TEMP="$(pwd)/$UNSIGNED_APK_TEMP" ;;
        esac
        (cd "$NATIVE_LIBS_DIR" && zip -r -q "$ABS_UNSIGNED_APK_TEMP" lib) || { echo "Error: Failed to package executables."; exit 1; }
    fi

    echo "Generating debug KeyStore if it does not exist..."
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
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
    "$MIPMAP_XXHDPI_DIR" "$MIPMAP_XXXHDPI_DIR" "$MIPMAP_ANYDPI_V26_DIR"
rm -rf "$TEMP_ROOT_DIR"
mkdir -p "$TEMP_CLASSES_DIR" "$FLAT_RES_DIR" "$R_PACKAGE_DIR" "$TEMP_BUILD_DATA_DIR" "$AAB_TEMP_DIR" "$NATIVE_LIBS_DIR"
prepare_permissions
prepare_share_targets
prepare_executables

DENSITY_PAIRS="mdpi:48x48 hdpi:72x72 xhdpi:96x96 xxhdpi:144x144 xxxhdpi:192x192"
FOREGROUND_DENSITY_PAIRS="mdpi:108x108 hdpi:162x162 xhdpi:216x216 xxhdpi:324x324 xxxhdpi:432x432"
ICON_TEMP_FILE="$RES_DIR/temp_icon_file_base"
ICON_RENDER_FILE="$RES_DIR/temp_icon_render.png"

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

ICON_RENDER_SOURCE="$ICON_TEMP_FILE"
case "$ICON_SOURCE_FILE" in
    *.svg|*.SVG)
        if command -v rsvg-convert >/dev/null 2>&1; then
            rsvg-convert -w 432 -h 432 -o "$ICON_RENDER_FILE" "$ICON_TEMP_FILE" || { echo "Error: SVG icon conversion failed." ; exit 1; }
            ICON_RENDER_SOURCE="$ICON_RENDER_FILE"
        fi
        ;;
esac

if command -v convert >/dev/null 2>&1; then
    for PAIR in $DENSITY_PAIRS; do
        DENSITY=$(echo "$PAIR" | cut -d: -f1)
        SIZE=$(echo "$PAIR" | cut -d: -f2)

        MIPMAP_SUBDIR="$RES_DIR/mipmap-$DENSITY"
        ICON_FINAL_PNG="$MIPMAP_SUBDIR/ic_launcher.png"

        convert "$ICON_RENDER_SOURCE" -resize "$SIZE" "$ICON_FINAL_PNG" || { echo "Error: ImageMagick conversion failed for $DENSITY." ; exit 1; }
    done
    for PAIR in $FOREGROUND_DENSITY_PAIRS; do
        DENSITY=$(echo "$PAIR" | cut -d: -f1)
        SIZE=$(echo "$PAIR" | cut -d: -f2)

        MIPMAP_SUBDIR="$RES_DIR/mipmap-$DENSITY"
        FOREGROUND_FINAL_PNG="$MIPMAP_SUBDIR/ic_launcher_foreground.png"

        convert -background none "$ICON_RENDER_SOURCE" -resize "$SIZE" -gravity center -extent "$SIZE" "$FOREGROUND_FINAL_PNG" || { echo "Error: ImageMagick adaptive icon generation failed for $DENSITY." ; exit 1; }
    done
else
    echo "Error: 'convert' (ImageMagick) not found. Cannot generate icons."
    rm -f "$ICON_TEMP_FILE" "$ICON_RENDER_FILE"
    exit 1
fi

rm -f "$ICON_TEMP_FILE" "$ICON_RENDER_FILE"

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

APP_THEME="@android:style/Theme.DeviceDefault.NoActionBar"
if [ -n "$BACKGROUND" ]; then
    APP_THEME="@style/AppTheme"
fi

prepare_source_templates

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
javac -g:none --release 11 \
    -classpath "$ANDROID_JAR" \
    -d "$TEMP_CLASSES_DIR" \
    "$R_PACKAGE_DIR/R.java" \
    "$SRC_DIR"/*.java || { echo "Error: JAVAC failed."; exit 1; }

echo "Packaging .class files into temporary JAR..."
case "$TEMP_JAR_FILE" in
    /*) ABS_TEMP_JAR_FILE="$TEMP_JAR_FILE" ;;
    *) ABS_TEMP_JAR_FILE="$(pwd)/$TEMP_JAR_FILE" ;;
esac
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
