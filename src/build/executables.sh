# Native executable packaging helpers.

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
            *" $EXEC_NAME "*) ;;
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
