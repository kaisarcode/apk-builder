# APK-BUILDER
Android WebView App Builder

---

## Description

APK-BUILDER is a lightweight POSIX shell script that builds Android apps - mainly WebView-based - directly from the command line.
It automates every step: generates a full Android project, compiles, signs, and outputs an APK, with optional AAB generation for Play Store distribution.
No Android Studio, no Gradle - just the Android SDK and a shell.

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
git clone https://github.com/kaisarcode/apk-builder.git
cd apk-builder
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

By default, it builds a debug APK in *./<project-name>/bin/*.

### Command-line options

| Option | Description |
|------|--------------|
| `--display-name <name>` | Application display name. |
| `--project-name <name>` | Local generated project/output directory name. |
| `--package-name <name>` | Android package name. |
| `--webview-url <url|file>` | Remote URL or local HTML entry file. |
| `--icon <path|url>` | Local or remote icon source. |
| `--icon-background <color>` | Adaptive icon background color. |
| `--background <color>` | Activity/WebView startup background using `#RRGGBB` or `#AARRGGBB`. |
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

Build a local WebView app with a packaged executable:

```bash
./build.sh \
    --display-name "Demo" \
    --project-name demo \
    --package-name com.kaisarcode.demo \
    --webview-url ./web/index.html \
    --background '#101010' \
    --exec ~/work/kccli/proj/demo.c/bin/aarch64/android/demo
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
PACKAGE_NAME="com.kaisarcode.myapp"
WEBVIEW_URL="https://google.com/"
ICON_SOURCE_FILE="./icon.svg"
ICON_BACKGROUND="#1a1a1a"
BACKGROUND=""
TRUSTED_ORIGINS=""
IS_FULLSCREEN="false"
VERSION_CODE=1
VERSION_NAME="1.0"
```

The precedence is:

```text
command-line option > environment variable > built-in default
```

### WebView source

`--webview-url` / `WEBVIEW_URL` can point to:
- A remote web page, such as `https://example.com`
- A local HTML file, such as `~/myproject/index.html`

If a local file is detected, the script automatically copies its entire containing directory into the app's `assets/` directory and changes the startup URL to the corresponding `file:///android_asset/...` URL. CSS, JavaScript, images, subdirectories, and other adjacent web assets are therefore packaged together.

### Background

`--background` sets both the Activity window background shown while the WebView starts and the WebView background itself.

Accepted forms are:

```text
#RRGGBB
#AARRGGBB
```

For example:

```bash
./build.sh --background '#101010'
```

An alpha value can be supplied with `#AARRGGBB`. This controls the Activity/WebView background color; it does not enable a special translucent-Activity mode.

### Trusted origins for JS bridge

For remote content, `--trusted-origin` can be repeated:

```bash
./build.sh \
    --webview-url https://app.example.com \
    --trusted-origin https://app.example.com \
    --trusted-origin https://cdn.example.com
```

`TRUSTED_ORIGINS` remains available as a whitespace-separated environment fallback.

If no explicit trusted origin is supplied and `WEBVIEW_URL` is remote, APK-BUILDER automatically trusts the origin of `WEBVIEW_URL`.

For local packaged content, `file:///android_asset/...` remains trusted automatically.

Links outside the trusted list open in the external browser, and the JavaScript bridge is only available while the WebView is on a trusted URL.

### Packaged executables

`--exec` packages a native Android executable into the APK and exposes its basename through the `NativeBridge.exec` whitelist.

```bash
./build.sh \
    --exec ~/work/kccli/proj/demo.c/bin/aarch64/android/demo
```

JavaScript can then invoke it with:

```js
NativeBridge.exec(["demo", "Kaisar"]);
```

Only executables explicitly passed with `--exec` are exposed. Multiple executables can be included by repeating the option.

### Icon source

`--icon` / `ICON_SOURCE_FILE` accepts:
- A local image file (SVG, PNG, etc.)
- An external URL such as `https://example.com/icon.png`

ImageMagick (**convert**) is used to generate icons in all Android densities automatically. On Android 8+ the launcher uses adaptive icons; `--icon-background` / `ICON_BACKGROUND` sets the adaptive icon background color, while raster icons remain the fallback for older Android versions. If the input is an SVG and *rsvg-convert* is available, it is used first for high-quality rasterization.

### Android SDK location

If you already have the SDK installed, set either `ANDROID_SDK_ROOT` or `ANDROID_HOME` before running the script and your existing installation will be reused. When neither variable is present, APK-BUILDER falls back to `~/android-sdk` and downloads the command-line tools there. To override the download location manually, set `CMDLINE_TOOLS_URL` and optionally `SDK_ZIP` before invoking the script.

### Environment-variable examples

```bash
WEBVIEW_URL="~/site/index.html" ICON_SOURCE_FILE="~/icons/app.svg" ./build.sh --release
```

```bash
TRUSTED_ORIGINS="https://app.example.com https://cdn.example.com" \
WEBVIEW_URL="https://app.example.com" \
./build.sh --release
```

---

## Output

After building, the results are stored in:

```text
./<project-name>/bin/
```

| File | Description |
|------|--------------|
| `*.apk` | Installable debug Android package. |
| `*.aab` | Android App Bundle for Play Store distribution. |

Example:

```text
myapp/bin/myapp.apk
myapp/bin/myapp.aab
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
- Compatible with Android SDK 24-34.

---

## Beta Notice

This is a beta project tested only on Debian x86_64. It was created out of a personal need for these libraries, but no guarantees are provided regarding its stability or future support. You are free to test it, use it, and modify it as you please.

If you'd like to reach out, you can send an email to kaisar@kaisarcode.com. Please note that I do not accept pull requests; the goal is to avoid long-term dependency on platforms like GitHub, and I do not maintain fixed infrastructure to guarantee long-term stability for these projects.

---

## License

[![GPLv3](https://www.gnu.org/graphics/gplv3-127x51.png)](https://www.gnu.org/licenses/gpl-3.0.html)

This project is distributed under the **GNU General Public License version 3 (GPLv3)**.
