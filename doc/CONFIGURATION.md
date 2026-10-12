# Configuration

KCAPK can be configured with command-line options or environment variables.

Command-line values take precedence over environment variables, which take precedence over built-in defaults.

```text
command-line option > environment variable > built-in default
```

## Command-line options

| Option | Description |
|---|---|
| `--display-name <name>` | Application display name. |
| `--project-name <name>` | Project name and default build directory name. |
| `--output-path <path>` | Generated project/build directory. |
| `--package-name <name>` | Android package name. |
| `--webview-url <url|file>` | Remote URL or local HTML entry file. |
| `--icon <path|url>` | Local or remote icon source. |
| `--icon-background <color>` | Adaptive launcher icon background. |
| `--background <color>` | Activity, WebView, and system-bar startup background. |
| `--trusted-origin <origin>` | Additional trusted bridge origin; repeatable. |
| `--fullscreen` | Enable fullscreen mode. |
| `--version-code <N>` | Android version code. |
| `--version-name <name>` | Android version name. |
| `--exec <path>` | Package one native executable; repeatable. |
| `--clean` | Regenerate the debug keystore. |
| `--release` | Build the debug APK and an AAB. |

## Main environment variables

```sh
DISPLAY_NAME="My App"
PROJECT_NAME="myapp"
OUTPUT_PATH="./build/myapp"
PACKAGE_NAME="com.example.myapp"
WEBVIEW_URL="./web/index.html"
ICON_SOURCE_FILE="./src/assets/icon.svg"
ICON_BACKGROUND="#000000"
BACKGROUND="#101010"
TRUSTED_ORIGINS=""
IS_FULLSCREEN="false"
VERSION_CODE=1
VERSION_NAME="1.0"
```

When `OUTPUT_PATH` is empty, KCAPK uses:

```text
./build/<project-name>
```

## Display and package names

`DISPLAY_NAME` / `--display-name` controls the user-visible application name.

`PROJECT_NAME` / `--project-name` controls generated artifact names and the default build directory.

`PACKAGE_NAME` / `--package-name` controls the Android package identifier.

Example:

```sh
./build.sh \
    --display-name "Notes" \
    --project-name notes \
    --package-name com.example.notes
```

## Background

The default startup background is:

```text
#101010
```

Accepted values are:

```text
#RRGGBB
#AARRGGBB
```

Example:

```sh
./build.sh --background '#202020'
```

The value is applied to the generated Activity window, WebView, and system-bar startup surfaces.

## Icons

The bundled default icon lives at:

```text
src/assets/icon.svg
```

A custom icon may be local or remote:

```sh
./build.sh --icon ./assets/icon.svg
```

```sh
./build.sh --icon https://example.com/icon.png
```

KCAPK generates raster launcher assets for the standard Android densities and adaptive launcher icon assets for modern Android versions.

`--icon-background` / `ICON_BACKGROUND` sets the adaptive icon background color.

## Fullscreen

```sh
./build.sh --fullscreen
```

The generated Activity starts in fullscreen mode. Runtime system-bar control is also available through `NativeBridge.Android.systemUI`; see [Android APIs](ANDROID_APIS.md).

## Trusted origins

Remote bridge access can be extended with repeated options:

```sh
./build.sh \
    --webview-url https://app.example.com \
    --trusted-origin https://app.example.com \
    --trusted-origin https://cdn.example.com
```

The `TRUSTED_ORIGINS` environment variable remains available as a whitespace-separated fallback.

See [WebView and trusted origins](WEBVIEW.md) for the trust model.

## Native executables

`--exec` can be repeated to package native binaries:

```sh
./build.sh \
    --exec /path/to/arm64-v8a/tool \
    --exec /path/to/x86_64/tool
```

See [External binaries](EXTERNAL_BINARIES.md).

## Release settings

Release signing uses these environment variables:

```sh
RELEASE_KEYSTORE
RELEASE_KEY_ALIAS
RELEASE_STORE_PASS
RELEASE_KEY_PASS
```

See [Release builds](RELEASES.md).
