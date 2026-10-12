# Architecture

KCAPK is a small command-line Android builder designed to keep the build process visible and inspectable.

## Source layout

KCAPK separates build logic from reusable Android source material:

```text
build.sh
src/
├── AndroidManifest.xml.in
├── assets/
├── java/
└── res/
tests/
doc/
```

`build.sh` orchestrates the build. Android templates and resources are kept under `src/` so the builder can grow without embedding Java or XML source inside the shell script.

## Build pipeline

A normal build performs these stages:

1. Resolve configuration from command-line options, environment variables, and defaults.
2. Locate or bootstrap the Android SDK command-line tools.
3. Prepare the generated Android project and resources.
4. Package local WebView assets when a local entry file is used.
5. Render the Android manifest, Java templates, and resource templates.
6. Generate launcher icons.
7. Compile and link Android resources with AAPT2.
8. Compile Java sources with `javac`.
9. Convert the Java classes to Dalvik/ART bytecode with D8.
10. Build, align, and sign the debug APK.
11. Optionally build an AAB through BundleTool.

The generated project remains under the configured build directory so its source and intermediate output can be inspected.

## Generated application

The generated application is a native Android Activity containing a WebView.

The WebView may load:

- packaged local assets, or
- a remote HTTP/HTTPS application.

Trusted content receives a JavaScript bridge named `NativeBridge`.

## NativeBridge layers

The public JavaScript API is deliberately divided into two layers.

### Android framework APIs

```js
NativeBridge.Android.*
```

This namespace exposes selected Android platform primitives such as notifications, alarms, haptics, intents, clipboard access, system UI controls, permissions, and screen wake behavior.

KCAPK does not attempt to expose the complete Android SDK. The goal is a useful general-purpose bridge, not a reflection layer over arbitrary Android classes.

See [Android APIs](ANDROID_APIS.md).

### External native binaries

```js
NativeBridge.exec(...)
```

This is separate from `NativeBridge.Android` because it does not represent an Android framework API. It executes only binaries explicitly packaged at build time with `--exec`.

See [External binaries](EXTERNAL_BINARIES.md).

## Trust boundary

The raw Java bridge is installed only for WebView pages considered trusted by KCAPK. Packaged local assets are trusted automatically. Remote applications use origin matching and may add explicit trusted origins.

Untrusted top-level navigation is opened outside the application rather than receiving bridge access.

See [WebView and trusted origins](WEBVIEW.md).

## Application logic

KCAPK intentionally exposes primitives rather than application-specific concepts.

For example, alarms and notifications are native capabilities, while concepts such as tasks, reminders, recurrence rules, synchronization models, or business workflows belong to the web application using KCAPK.

This keeps the builder reusable across unrelated applications.

## Next step

Continue with [Building](BUILDING.md).
