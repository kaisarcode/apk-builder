# Tests

Build the local KCAPK test application with:

```sh
sh ./tests/test.sh
```

The generated APK is written to:

```text
tests/test.apk
```

The test also packages prebuilt native Android executables through `--exec`. The repository ships the same logical `kcapk-test-exec` fixture for `arm64-v8a` and `x86_64` under `tests/fixtures/`, so running the test does not require an Android NDK or C compiler.

The minimal source used for those fixtures is kept in `tests/fixtures/exec.c` for reference and reproducibility. It is not compiled by `tests/test.sh`.

After building, the test inspects the APK and generated source and verifies the multi-ABI executable entries, NativeBridge Promise resource, async bridge classes, result forwarding, and required manifest entries.

When the app runs on a compatible Android device, press **Run packaged executable**. The page invokes:

```js
var output = await NativeBridge.exec(["kcapk-test-exec"]);
```

The bundled fixture resolves with:

```text
kcapk external executable OK
```

The app also includes a **Parallel exec** control that starts two executable requests concurrently and a **Notifications permission** control that tests the asynchronous Android permission result.

The Android build workspace is created in a temporary directory outside `tests/` and removed when the test finishes. Only `tests/test.apk` is kept as the generated test artifact.
