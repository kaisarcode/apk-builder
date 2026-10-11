# Tests

Build the local KCAPK test application with:

```sh
sh ./tests/test.sh
```

The generated APK is written to:

```text
tests/test.apk
```

The test also packages a native Android executable through `--exec`. By default, `tests/exec.c` is compiled for Android arm64 using the Android NDK. Set `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT`, or make the NDK available under `$ANDROID_SDK_ROOT/ndk/`.

You can instead provide an already compiled Android executable:

```sh
TEST_EXECUTABLE=/path/to/android/executable sh ./tests/test.sh
```

The supplied executable is copied to the logical command name `kcapk-test-exec`, packaged into the APK, and verified after the build by inspecting the APK contents.

When the app runs on a compatible Android device, press **Run packaged executable**. The page invokes:

```js
NativeBridge.exec(["kcapk-test-exec", "hello"]);
```

The bundled fixture returns:

```text
kcapk external executable OK hello
```

The intermediate Android project is kept under `tests/.build/`, and the generated executable under `tests/.exec/`. Those directories and `tests/test.apk` are ignored by Git.
