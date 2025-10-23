# APK-BUILDER
Generic Android WebView App Builder (POSIX Shell Script)

---

## Description

APK-BUILDER is a lightweight POSIX shell script that builds Android apps - mainly WebView-based - directly from the command line.
It automates every step: generates a full Android project, compiles, signs, and outputs both APK and AAB packages, ready for installation or Play Store upload.
No Android Studio, no Gradle - just the Android SDK and a shell.

---

## Requirements

Make sure your system includes:

- Android SDK (with build-tools and platforms)
- Java JDK 8+
- POSIX shell (Linux, macOS, or WSL)
- ImageMagick (*convert*) - for icon generation
- Standard command-line tools:
*git*, *curl*, *unzip*, *sed*, *awk*, *zipalign*, *apksigner*, *keytool*, *bundletool*

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

- Make sure the Android SDK path is set, for example:
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
- An external URL (e.g. *https://example.com/icon.png*)

ImageMagick (**convert**) is used to generate icons in all Android densities automatically.

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
- Accepts icons from local files or external URLs
- Generates icons automatically for all densities
- Compatible with Android SDK 24-34
- Tested for personal use in a clean Ubuntu 24 environment

---

## Author

KaisarCode
Email: [kaisar@kaisarcode.com](mailto:kaisar@kaisarcode.com)
Website: [https://kaisarcode.com](https://kaisarcode.com)

---

## License

Licensed under the GNU General Public License v3.0.
See [LICENSE](./LICENSE) for details.

---

© 2025 KaisarCode
