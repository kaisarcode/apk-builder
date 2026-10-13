# Testing

KCAPK includes an integration test that builds a real generated Android application and validates key packaging and bridge behavior.

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

## What the host-side test validates

The integration script checks that KCAPK can:

- generate the Android project,
- compile the current Java bridge classes,
- generate the standalone NativeBridge JavaScript resource,
- include the Promise request/completion layer,
- generate `AsyncBridge` and `ExecBridge`,
- forward permission and activity results from `MainActivity`,
- include required Android permissions,
- include alarm receivers,
- package external executables for multiple ABIs,
- produce the final APK.

The script verifies that `NativeBridge.exec()` and `NativeBridge.Android.permissions.request()` are wired through the asynchronous request layer rather than through synchronous return values.

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

- asynchronous packaged executable execution,
- two concurrent executable requests with `Promise.all`,
- Android notification permission results,
- network-state queries,
- vibration and haptics,
- clipboard round trips,
- Android Sharesheet integration,
- keep-screen-on behavior.

Interactive results are surfaced with Android toasts.

## Install the generated test APK

After a successful test build:

```sh
adb install -r -t tests/test.apk
```

The test script also prints the corresponding install command.

## Manual validation

A successful host-side build proves that generated source compiles and the APK packages correctly, but device behavior still needs manual validation for Android features that depend on runtime services, permissions, lifecycle, system settings, or hardware.

The async layer should be manually checked for:

- `await NativeBridge.exec()` resolving with executable output,
- parallel executable requests resolving independently,
- notification permission requests resolving only after the Android result,
- page navigation not receiving stale native completions,
- pending native processes being cleaned up when the Activity is destroyed.

Other device-dependent checks include:

- vibration hardware,
- exact-alarm special access,
- Sharesheet availability,
- system-bar behavior across Android versions.

When adding a new asynchronous Android bridge API, update both host-side generated-source checks and the test application when practical.

## Next step

Return to the complete [Documentation index](../README.md#documentation).
