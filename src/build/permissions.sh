# Build-time permissions and share-target generation.

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
            *" $RESOLVED_PERMISSION "*) continue ;;
        esac
        SEEN_PERMISSIONS="$SEEN_PERMISSIONS $RESOLVED_PERMISSION"
        printf '    <uses-permission android:name="%s" />\n' "$RESOLVED_PERMISSION" >> "$PERMISSION_DECLARATIONS_FILE"
    done <<EOF
$PERMISSIONS
EOF
}

# Generates Android share target intent filters for the manifest template.
# @return None.
prepare_share_targets () {
    SHARE_TARGET_DECLARATIONS_FILE="$TEMP_ROOT_DIR/share_targets.xml"
    : > "$SHARE_TARGET_DECLARATIONS_FILE"
    SEEN_SHARE_TARGETS=""

    [ -n "$SHARE_TARGETS" ] || return

    {
        printf '            <intent-filter>\n'
        printf '                <action android:name="android.intent.action.SEND" />\n'
        printf '                <action android:name="android.intent.action.SEND_MULTIPLE" />\n'
        printf '                <category android:name="android.intent.category.DEFAULT" />\n'
    } >> "$SHARE_TARGET_DECLARATIONS_FILE"

    while IFS= read -r MIME_TYPE; do
        [ -n "$MIME_TYPE" ] || continue
        if ! printf '%s\n' "$MIME_TYPE" | grep -Eq '^[A-Za-z0-9.+*-]+/[A-Za-z0-9.+*-]+$'; then
            echo "Error: Invalid MIME type for --share-target: $MIME_TYPE" >&2
            exit 1
        fi

        case " $SEEN_SHARE_TARGETS " in
            *" $MIME_TYPE "*) continue ;;
        esac
        SEEN_SHARE_TARGETS="$SEEN_SHARE_TARGETS $MIME_TYPE"
        printf '                <data android:mimeType="%s" />\n' "$MIME_TYPE" >> "$SHARE_TARGET_DECLARATIONS_FILE"
    done <<EOF
$SHARE_TARGETS
EOF

    printf '%s\n' '            </intent-filter>' >> "$SHARE_TARGET_DECLARATIONS_FILE"
}
