# KCAPK
Android WebView App Builder

---

## Description

KCAPK is a lightweight POSIX shell script that builds Android apps - mainly WebView-based - directly from the command line.
It automates every step: generates a full Android project, compiles, signs, and outputs an APK, with optional AAB generation for Play Store distribution.
No Android Studio, no Gradle.

---

## Requirements

Make sure your system includes:

- Android SDK (with build-tools and platforms)
- Java JDK 11+
- POSIX shell (Linux, macOS, or WSL)
- ImageMagick (*convert*) - for icon generation
- *rsvg-convert* (optional) - improved SVG icon rendering when available
- Standard command-line tools:
*git*, *curl* (or *wget*), *unzip*, *zip*

`zipalign` and `apksigner` are provided by the Android SDK build-tools. `keytool` and `jarsigner` are provided by the JDK. `bundletool` is downloaded automatically when needed for `--release` builds.

---

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/kaisarcode/kcapk.git
cd kcapk
chmod +x build.sh
```

### Installing Required Packages

#### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk imagemagick wget unzip zipalign apksigner git curl
```

- On older systems, *zipalign* and *apksigner* are part of Android build-tools.
- If not available, install the Android SDK manually.

#### Arch Linux / Manjaro

```bash
sudo pacman -S jdk17-openjdk imagemagick git curl unzip wget
```

Optionally install Android SDK from AUR:
```bash
yay -S android-sdk android-sdk-build-tools android-sdk-platform-tools
```

#### macOS (Homebrew)

```bash
brew install openjdk imagemagick git curl unzip wget
```

Set `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) to the location of your existing SDK if it is not already configured:

```bash
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
```

#### Windows Subsystem for Linux (WSL)

1. Install Ubuntu or Debian under WSL.
2. Run the same commands as the Ubuntu section above.
3. Ensure Java and ImageMagick work correctly:

```bash
java -version
convert -version
```

---

## Usage

Run directly:

```bash
./build.sh
```

By default, it builds a debug APK in *./build/<project-name>/bin/*.

### Command-line options

| Option | Description |
|------|--------------|
| `--display-name <name>` | Application display name. |
| `--project-name <name>` | Project name used for generated package filenames and the default build directory. |
| `--output-path <path>` | Generated Android project/build directory. Defaults to `./build/<project-name>`. |
| `--package-name <name>` | Android package name. |
| `--webview-url <url|file>` | Remote URL or local HTML entry file. |
| `--icon <path|url>` | Local or remote icon source. |
| `--icon-background <color>` | Adaptive icon background color. |
| `--background <color>` | Activity/WebView/system-bar startup background using `#RRGGBB` or `#AARRGGBB`. Defaults to `#101010`. |
| `--trusted-origin <origin>` | Trusted bridge origin; repeatable. |
| `--fullscreen` | Enables fullscreen mode. |
| `--version-code <N>` | Android version code. |
| `--version-name <name>` | Android version name. |
| `--exec <path>` | Packages one native executable and exposes it to `NativeBridge.exec`; repeatable. |
| `--clean` | Deletes the existing debug keystore before building. |
| `--release` | Builds a debug APK plus an AAB for Play Store distribution. |

Command-line options override the equivalent environment variables. Environment variables remain supported as fallbacks.

### Examples

Build a debug APK:

```bash
./build.sh
```

Build into a custom directory:

```bash
./build.sh --project-name myapp --output-path /tmp/kcapk/myapp
```

Build a local WebView app with a packaged executable:

```bash
./build.sh \
    --display-name "My App" \
    --project-name myapp \
    --package-name com.example.myapp \
    --webview-url ./web/index.html \
    --exec /path/to/aarch64/android/myexe \
    --exec /path/to/armv7/android/myexe
```

Build a debug APK plus a Play Store AAB:

```bash
./build.sh --release
```

Combine clean and release:

```bash
./build.sh --clean --release
```

---

## Configuration

The primary settings can also be supplied through environment variables:

```sh
DISPLAY_NAME="My App"
PROJECT_NAME="myapp"
OUTPUT_PATH="./build/myapp"
PACKAGE_NAME="com.example.myapp"
WEBVIEW_URL="https://example.com/"
ICON_SOURCE_FILE="./src/assets/icon.svg"
ICON_BACKGROUND="#1a1a1a"
BACKGROUND="#101010"
TRUSTED_ORIGINS=""
IS_FULLSCREEN="false"
VERSION_CODE=1
VERSION_NAME="1.0"
```

The precedence is:

```text
command-line option > environment variable > built-in default
```

When `OUTPUT_PATH` is not set, KCAPK uses `./build/<project-name>`.

### WebView source

`--webview-url` / `WEBVIEW_URL` can point to:
- A remote web page, such as `https://example.com`
- A local HTML file, such as `~/myproject/index.html`

If a local file is detected, the script automatically copies its entire containing directory into the app's `assets/` directory and changes the startup URL to the corresponding `file:///android_asset/...` URL. CSS, JavaScript, images, subdirectories, and other adjacent web assets are therefore packaged together.

### Background

KCAPK uses a dark `#101010` background by default. This color is applied to the Activity window shown while the WebView starts, the WebView itself, and the Android status/navigation bars to avoid bright startup surfaces.

`--background` / `BACKGROUND` overrides that color.

Accepted forms are:

```text
#RRGGBB
#AARRGGBB
```

For example:

```bash
./build.sh --background '#202020'
```

An alpha value can be supplied with `#AARRGGBB`. This controls the Activity/WebView/system-bar background color; it does not enable a special translucent-Activity mode.

### Trusted origins for JS bridge

For remote content, `--trusted-origin` can be repeated:

```bash
./build.sh \
    --webview-url https://app.example.com \
    --trusted-origin https://app.example.com \
    --trusted-origin https://cdn.example.com
```

`TRUSTED_ORIGINS` remains available as a whitespace-separated environment fallback.

If no explicit trusted origin is supplied and `WEBVIEW_URL` is remote, KCAPK automatically trusts the origin of `WEBVIEW_URL`.

For local packaged content, `file:///android_asset/...` remains trusted automatically.

Links outside the trusted list open in the external browser, and the JavaScript bridge is only available while the WebView is on a trusted URL.

### NativeBridge.exec

`NativeBridge.exec` executes native Android command-line programs explicitly packaged with `--exec`.

The JavaScript API receives an argv-style array. The first element is the logical executable name and the remaining elements are passed as arguments:

```js
NativeBridge.exec(["myexe", "--param", "hello"]);
```

Only executables explicitly supplied with `--exec` are available. JavaScript cannot execute arbitrary paths or commands outside that whitelist.

The executable is exposed by its basename. For example:

```bash
./build.sh \
    --webview-url ./web/index.html \
    --exec /path/to/aarch64/android/myexe
```

makes this available to trusted WebView content:

```js
NativeBridge.exec(["myexe", "--param", "hello"]);
```

`NativeBridge.exec` returns the process output as a string. Standard error is merged into standard output.

### NativeBridge.Android

Android platform APIs exposed by KCAPK live under `NativeBridge.Android`. `NativeBridge.exec` remains at the top level because it represents packaged native executables rather than an Android framework API.

Existing Android helpers are therefore exposed as:

```js
NativeBridge.Android.showToast("Hello");
NativeBridge.Android.isOnline();
```

Permissions are exposed through `NativeBridge.Android.permissions`:

```js
NativeBridge.Android.permissions.has("notifications");
NativeBridge.Android.permissions.request("notifications");

NativeBridge.Android.permissions.has("exactAlarms");
NativeBridge.Android.permissions.request("exactAlarms");
```

`request()` returns whether KCAPK could start the Android permission request flow. Runtime and special-access requests are asynchronous, so call `has()` again after the user returns to the app to determine the effective state.

Notifications are exposed through `NativeBridge.Android.notifications`:

```js
NativeBridge.Android.notifications.createChannel({
    id: "tasks",
    name: "Tasks",
    description: "Task notifications",
    importance: "high",
    sound: "default"
});

NativeBridge.Android.notifications.post({
    id: 10,
    channel: "tasks",
    title: "Review server",
    text: "Check the production logs",
    group: "work"
});

NativeBridge.Android.notifications.cancel(10);
NativeBridge.Android.notifications.cancelAll();
NativeBridge.Android.notifications.canPost();
```

On Android 8.0 and newer, importance and sound are channel properties. Once Android creates a channel, the user has final control over those settings and the channel behavior cannot be freely changed by reposting notifications.

Alarms are exposed through `NativeBridge.Android.alarms`. Alarm timestamps use Unix epoch milliseconds. Alarm actions are native so they can run when the WebView is not alive; the first supported action type posts a notification:

```js
NativeBridge.Android.alarms.schedule({
    id: 10,
    at: Date.now() + 60000,
    exact: true,
    action: {
        type: "notification",
        id: 10,
        channel: "tasks",
        title: "Review server",
        text: "Check the production logs"
    }
});
```

Exact alarms require Android's Alarms & reminders special access on Android 12 and newer. The access can be queried with `NativeBridge.Android.alarms.canScheduleExact()` and requested through `NativeBridge.Android.permissions.request("exactAlarms")`.

Scheduled alarms are persisted by the generated app and future alarms are restored after device boot. Recurrence remains application logic: KCAPK schedules Android alarms but does not define tasks, reminder models, or recurrence rules.

```js
NativeBridge.Android.alarms.cancel(10);
NativeBridge.Android.alarms.cancelAll();
```

### Multi-ABI executables

The same logical executable can be supplied more than once when each file targets a different Android ABI:

```bash
./build.sh \
    --webview-url ./web/index.html \
    --exec /path/to/aarch64/android/myexe \
    --exec /path/to/armv7/android/myexe
```

They are packaged as ABI-specific variants of the same logical command:

```text
lib/arm64-v8a/libexec_myexe.so
lib/armeabi-v7a/libexec_myexe.so
```

The JavaScript call remains identical on every supported device:

```js
NativeBridge.exec(["myexe", "--param", "hello"]);
```

Android selects the native ABI variant for the device automatically.

The current architecture mapping is:

```text
aarch64/android -> arm64-v8a
armv7/android   -> armeabi-v7a
```

Passing the same executable basename more than once for the same ABI is rejected.

Multiple different commands can also be exposed by repeating `--exec`:

```bash
./build.sh \
    --webview-url ./web/index.html \
    --exec /path/to/aarch64/android/tool-a \
    --exec /path/to/aarch64/android/tool-b
```

Then each basename is available separately:

```js
NativeBridge.exec(["tool-a", "--version"]);
NativeBridge.exec(["tool-b", "status"]);
```

### Icon source

`--icon` / `ICON_SOURCE_FILE` accepts:
- A local image file (SVG, PNG, etc.)
- An external URL such as `https://example.com/icon.png`

The bundled default icon lives at `src/assets/icon.svg`.

ImageMagick (**convert**) is used to generate icons in all Android densities automatically. On Android 8+ the launcher uses adaptive icons; `--icon-background` / `ICON_BACKGROUND` sets the adaptive icon background color, while raster icons remain the fallback for older Android versions. If the input is an SVG and *rsvg-convert* is available, it is used first for high-quality rasterization.

### Android SDK location

If you already have the SDK installed, set either `ANDROID_SDK_ROOT` or `ANDROID_HOME` before running the script and your existing installation will be reused. When neither variable is present, KCAPK falls back to `~/android-sdk` and downloads the command-line tools there. To override the download location manually, set `CMDLINE_TOOLS_URL` and optionally `SDK_ZIP` before invoking the script.

### Environment-variable examples

```bash
WEBVIEW_URL="~/site/index.html" ICON_SOURCE_FILE="~/icons/app.svg" ./build.sh --release
```

```bash
OUTPUT_PATH="/tmp/kcapk/myapp" WEBVIEW_URL="~/site/index.html" ./build.sh
```

```bash
TRUSTED_ORIGINS="https://app.example.com https://cdn.example.com" \
WEBVIEW_URL="https://app.example.com" \
./build.sh --release
```

---

## Output

By default, the generated Android project and build artifacts are stored under:

```text
./build/<project-name>/
```

The final APK/AAB files are stored in:

```text
./build/<project-name>/bin/
```

Use `--output-path <path>` or `OUTPUT_PATH` to relocate the entire generated project/build tree.

| File | Description |
|------|--------------|
| `*.apk` | Installable debug Android package. |
| `*.aab` | Android App Bundle for Play Store distribution. |

Example:

```text
build/myapp/bin/myapp.apk
build/myapp/bin/myapp.aab
```

The automatically generated debug keystore is stored at `~/.android/debug.keystore`.

---

## Release Signing

If you define these environment variables before running `--release`, the `.aab` will be signed automatically:

```bash
export RELEASE_KEYSTORE="/path/to/keystore.jks"
export RELEASE_KEY_ALIAS="mykey"
export RELEASE_STORE_PASS="storepassword"
export RELEASE_KEY_PASS="keypassword"
```

If they are not set, the build still completes, producing an unsigned AAB suitable for Google Play App Signing. The APK generated by `--release` remains a debug APK for installation and testing.

### Creating a Keystore

```bash
keytool -genkeypair -v \
    -keystore my-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias mykey \
    -storepass storepassword \
    -keypass keypassword \
    -dname "CN=MyCompany, OU=Dev, O=MyCompany, L=City, S=State, C=US"
```

---

## Notes

- Works offline for local apps once the required Android SDK tools and BundleTool, when building AABs, are already available.
- Supports both remote URLs and packaged local HTML assets.
- Accepts icons from local files or remote URLs.
- Generates icons automatically for all densities.
- Can package explicitly selected native Android executables.
- Uses a dark startup background by default to avoid bright flashes before WebView content renders.
- Compatible with Android SDK 24-36.

---

## Beta Notice

This is a beta project tested only on Debian x86_64. It was created out of a personal need for these libraries, but no guarantees are provided regarding its stability or future support. You are free to test it, use it, and modify it as you please.

If you'd like to reach out, you can send an email to kaisar@kaisarcode.com. Please note that I do not accept pull requests; the goal is to avoid long-term dependency on platforms like GitHub, and I do not maintain fixed infrastructure to guarantee long-term stability for these projects.

---

## License

[![LGPLv3](https://www.gnu.org/graphics/lgplv3-147x51.png)](https://www.gnu.org/licenses/lgplv3-147x51.png)

KCAPK is distributed under the **GNU Lesser General Public License version 3 (LGPLv3)**.
