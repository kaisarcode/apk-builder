# Test app

Build the local KCAPK test application with:

```sh
sh ./test/build.sh
```

The generated APK is written to:

```text
test/test.apk
```

The intermediate generated Android project is kept under `test/.build/`; both it and `test/test.apk` are ignored by Git.
