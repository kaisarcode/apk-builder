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

The minimal source used for those fixtures is kept in `tests/exec.c` for reference and reproducibility. It is not compiled by `tests/test.sh`.

After building, the test inspects the APK and verifies that both ABI-specific executable entries were packaged.

When the app runs on a compatible Android device, press **Run packaged executable**. The page invokes:

```js
NativeBridge.exec(["kcapk-test-exec"]);
```

The bundled fixture returns:

```text
kcapk external executable OK
```

The Android build workspace is created in a temporary directory outside `tests/` and removed when the test finishes. Only `tests/test.apk` is kept as the generated test artifact.
