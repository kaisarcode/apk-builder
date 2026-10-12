# Testing

KCAPK includes an integration test that builds a real generated Android application and validates key packaging behavior.

## Run the test

From the repository root:

```sh
sh ./tests/test.sh
```

The generated test APK is written to:

```text
tests/test.apk
```

The temporary generated Android project is created outside `tests/` and removed after the test completes.

## What the test validates

The integration script checks that KCAPK can:

- generate the Android project,
- compile the current Java bridge classes,
- generate the `NativeBridge.Android` namespace,
- include required Android permissions,
- include alarm receivers,
- package external executables for multiple ABIs,
- produce the final APK.

The script currently checks bridge namespaces and generated classes for the Android utility integrations as well as manifest entries such as notification, vibration, and network-state permissions.

## Native executable fixtures

The repository includes the same logical test executable for multiple Android ABIs under:

```text
tests/fixtures/
```

The fixture source is kept in:

```text
tests/fixtures/exec.c
```

The integration test does not compile that C source. Prebuilt Android fixtures are included so running the test does not require an Android NDK or C compiler.

The test packages them through `--exec` and verifies the resulting APK entries.

See [External binaries](EXTERNAL_BINARIES.md) for the integration model.

## Test application

`tests/index.html` is a small WebView application designed to exercise the bridge on a real Android device.

Its controls test operations such as:

- packaged executable execution,
- network-state queries,
- vibration and haptics,
- clipboard round trips,
- Android Sharesheet integration,
- keep-screen-on behavior.

Interactive results are generally surfaced with Android toasts.

## Install the generated test APK

After a successful test build:

```sh
adb install -r -t tests/test.apk
```

The test script also prints the corresponding install command.

## Manual validation

A successful host-side build proves that the generated source compiles and the APK packages correctly, but device behavior still needs manual validation for Android features that depend on runtime services, permissions, system settings, or hardware.

Examples include:

- vibration hardware,
- notification permission,
- exact-alarm special access,
- Sharesheet availability,
- system-bar behavior across Android versions.

When adding a new Android bridge API, update both the generated integration test checks and the test application when practical.
