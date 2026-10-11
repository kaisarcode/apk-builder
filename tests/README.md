# Test app

Build the local KCAPK test application with:

```sh
sh ./tests/test.sh
```

The generated APK is written to:

```text
tests/test.apk
```

The intermediate generated Android project is kept under `tests/.build/`; both it and `tests/test.apk` are ignored by Git.
