# Architecture

KCAPK is a small command-line Android builder designed to keep the build process visible and inspectable.

## Source layout

KCAPK separates the public build entrypoint, build engine, and reusable Android source material:

```text
build.sh
src/
├── build-main.sh
├── AndroidManifest.xml.in
├── assets/
├── java/
└── res/
tests/
doc/
```

`build.sh` is the user-facing entrypoint. It resolves NativeBridge API selection and prepares a temporary reduced source tree.

`src/build-main.sh` is the internal Android build engine. It receives the filtered source tree and performs the SDK, resource, Java, DEX, APK, and AAB build steps.

Android templates and resources remain under `src/` so native source stays readable instead of being embedded as shell-script strings.

## Build pipeline

A normal build performs these stages:

1. Parse the user-facing options and resolve repeatable `--api` selections.
2. Create a temporary source view containing only selected NativeBridge APIs and required internal dependencies.
3. Remove disabled bridge classes, JavaScript namespaces, lifecycle hooks, and API-specific Manifest components from that temporary source view.
4. Delegate to the internal build engine.
5. Resolve remaining configuration from command-line options, environment variables, and defaults.
6. Locate or bootstrap the Android SDK command-line tools.
7. Prepare the generated Android project and resources.
8. Package local WebView assets when a local entry file is used.
9. Render the Android Manifest, Java templates, and resource templates.
10. Generate launcher icons.
11. Compile and link Android resources with AAPT2.
12. Compile Java sources with `javac`.
13. Convert the Java classes to Dalvik/ART bytecode with D8.
14. Build, align, and sign the debug APK.
15. Optionally build an AAB through BundleTool.

The temporary source view exists only for the build. The canonical templates in the repository stay complete.

The generated Android project remains under the configured output directory so its selected source and intermediate output can be inspected.

## API selection

The always-present bridge core is deliberately small and currently exposes `NativeBridge.Android.showToast()`.

Optional APIs are selected with repeated build arguments:

```sh
./build.sh \
    --api notifications \
    --api clipboard \
    --api screen
```

Selection is physical, not merely a JavaScript visibility switch. When an API is disabled, KCAPK omits its public wrapper namespace and, when no selected feature needs it internally, its Java implementation class and Manifest integration as well.

Internal dependencies do not automatically expose public APIs. For example, alarms use notification implementation code for their native notification action, but `NativeBridge.Android.notifications` remains absent unless `--api notifications` is selected explicitly.

The shared async implementation is included only when `--exec` or an enabled asynchronous Android capability requires it.

See [Android APIs](ANDROID_APIS.md) and the [detailed API reference](apis/README.md).

## Generated application

The generated application is a native Android Activity containing a WebView.

The WebView may load:

- packaged local assets, or
- a remote HTTP/HTTPS application.

Trusted content receives a JavaScript bridge named `NativeBridge` containing only the capabilities selected for that build.

## NativeBridge layers

The public JavaScript API is deliberately divided into two layers.

### Android framework APIs

```js
NativeBridge.Android.*
```

This namespace exposes selected Android platform primitives. KCAPK does not attempt to expose the complete Android SDK. The goal is a useful set of explicit general-purpose capabilities, not a reflection layer over arbitrary Android classes.

Except for the small core, Android APIs are opt-in at build time.

See [Android APIs](ANDROID_APIS.md).

### External native binaries

```js
NativeBridge.exec(...)
```

This is separate from `NativeBridge.Android` because it does not represent an Android framework API. It is generated only when binaries are explicitly packaged with `--exec` and executes only those packaged binaries.

See [External binaries](EXTERNAL_BINARIES.md).

## Permissions and capabilities

NativeBridge API selection and Android permissions are separate concerns.

An API controls what native bridge functionality is compiled into the app. A permission controls what Android capability the packaged application declares or can request.

This separation avoids silently broadening an application's Manifest simply because KCAPK knows how to expose a related API.

See [Configuration](CONFIGURATION.md) and [Permissions](apis/permissions.md).

## Trust boundary

The raw Java bridge is installed only for WebView pages considered trusted by KCAPK. Packaged local assets are trusted automatically. Remote applications use origin matching and may add explicit trusted origins.

Untrusted top-level navigation is opened outside the application rather than receiving bridge access.

Build-time API pruning and runtime origin trust are complementary: pruning limits which native capabilities exist in the APK, while the trust boundary limits which loaded content may call the capabilities that were included.

See [WebView and trusted origins](WEBVIEW.md).

## Application logic

KCAPK intentionally exposes primitives rather than application-specific concepts.

For example, alarms and notifications are native capabilities, while concepts such as tasks, reminders, recurrence rules, synchronization models, or business workflows belong to the web application using KCAPK.

This keeps the builder reusable across unrelated applications.

## Next step

Continue with [Building](BUILDING.md).
