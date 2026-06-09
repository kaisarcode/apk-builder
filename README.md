# APK-BUILDER
Android WebView App Builder

---

## Description

APK-BUILDER is a lightweight POSIX shell script that builds Android apps - mainly WebView-based - directly from the command line.
It automates every step: generates a full Android project, compiles, signs, and outputs both APK and AAB packages, ready for installation or Play Store upload.
No Android Studio, no Gradle - just the Android SDK and a shell.

---

## Requirements

Make sure your system includes:

- Android SDK (with build-tools and platforms)
- Java JDK 11+
- POSIX shell (Linux, macOS, or WSL)
- ImageMagick (*convert*) - for icon generation
- Standard command-line tools:
*git*, *curl* (or *wget*), *unzip*, *sed*, *awk*, *zipalign*, *apksigner*, *keytool*, *bundletool*

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

### Command-line Flags

| Flag | Description |
|------|--------------|
| *--clean* | Deletes the existing debug keystore and temporary build data. |
| *--release* | Builds both APK and AAB packages (ready for Play Store). |

### Examples

Build a debug APK (default):

```bash
./build.sh
```

Clean everything and rebuild:

```bash
./build.sh --clean
```

Build Play Store-ready release packages:

```bash
./build.sh --release
```

Combine both:

```bash
./build.sh --clean --release
```

---

## Configuration

At the top of the script you'll find the main settings:

```sh
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
```

### WebView source

The *WEBVIEW_URL* variable can point to:
- A remote web page, such as *https://example.com*
- A local HTML file, such as *~/myproject/index.html*

If a local file is detected, the script automatically copies the directory to the app's assets/ folder and adjusts the WebView path accordingly.

### Icon source

The *ICON_SOURCE_FILE* variable accepts:
- A local image file (SVG, PNG, etc.)
- An external URL (e.g. *https://example.com/icon.png*) - downloaded automatically with *curl* or *wget*

ImageMagick (**convert**) is used to generate icons in all Android densities automatically.

### Android SDK location

If you already have the SDK installed, set either `ANDROID_SDK_ROOT` or `ANDROID_HOME` before running the script and your existing installation will be reused. When neither variable is present, APK-BUILDER falls back to `~/android-sdk` and downloads the command-line tools there. To override the download location manually, set `CMDLINE_TOOLS_URL` (and optionally `SDK_ZIP`) before invoking the script.

### Override configuration inline

```bash
WEBVIEW_URL="~/site/index.html" ICON_SOURCE_FILE="~/icons/app.svg" ./build.sh --release
```

---

## Output

After building, the results are stored in:

```
./<project-name>/bin/
```

| File | Description |
|------|--------------|
| *<project>.apk* | Installable Android package. |
| *<project>.aab* | Android App Bundle (Play Store format). |
| *debug.keystore* | Auto-generated debug keystore (if missing). |

Example:

```
myapp/bin/myapp.apk
myapp/bin/myapp.aab
```

---

## Release Signing

If you define these environment variables before running *--release*, the *.aab* will be signed automatically:

```bash
export RELEASE_KEYSTORE="/path/to/keystore.jks"
export RELEASE_KEY_ALIAS="mykey"
export RELEASE_STORE_PASS="storepassword"
export RELEASE_KEY_PASS="keypassword"
```

You can add these lines permanently to your shell configuration file (for example *~/.bashrc*, *~/.zshrc*, or *~/.profile*) so they are automatically available in all sessions.

If they're not set, the build still completes, producing an unsigned AAB (suitable for Google Play App Signing).

### Creating a Keystore

If you don't have one, create it manually with:

```bash
keytool -genkeypair -v   -keystore my-release-key.jks   -keyalg RSA -keysize 2048 -validity 10000   -alias mykey   -storepass storepassword   -keypass keypassword   -dname "CN=MyCompany, OU=Dev, O=MyCompany, L=City, S=State, C=US"
```

Save the *.jks* file and reference it via the environment variables above.

---

## Example

Build a Play Store-ready app from a website:

```bash
WEBVIEW_URL="https://myportfolio.com" DISPLAY_NAME="My Portfolio" PACKAGE_NAME="com.me.portfolio" ./build.sh --release
```

Or from a local HTML file:

```bash
WEBVIEW_URL="~/projects/portfolio/index.html" DISPLAY_NAME="My Portfolio" PACKAGE_NAME="com.me.portfolio" ICON_SOURCE_FILE="~/icons/portfolio.svg" ./build.sh --release
```

Results:

```
myportfolio/bin/myportfolio.apk
myportfolio/bin/myportfolio.aab
```

---

## Notes

- Works fully offline once SDK tools are installed
- Supports both remote URLs and local HTML assets
- Accepts icons from local files or remote URLs
- Generates icons automatically for all densities
- Compatible with Android SDK 24-34

---

## Beta Notice

This is a beta project tested only on Debian x86_64. It was created out of a personal need for these libraries, but no guarantees are provided regarding its stability or future support. You are free to test it, use it, and modify it as you please.

If you'd like to reach out, you can send an email to kaisar@kaisarcode.com. Please note that I do not accept pull requests; the goal is to avoid long-term dependency on platforms like GitHub, and I do not maintain fixed infrastructure to guarantee long-term stability for these projects.

---

## License

[![GPLv3](https://www.gnu.org/graphics/gplv3-127x51.png)](https://www.gnu.org/licenses/gpl-3.0.html)

This project is distributed under the **GNU General Public License version 3 (GPLv3)**.
