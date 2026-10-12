# External binaries

KCAPK can package native Android command-line executables and expose them to trusted WebView content through:

```js
NativeBridge.exec(...)
```

This feature is deliberately separate from `NativeBridge.Android.*` because it executes explicitly bundled native programs rather than calling Android framework APIs.

## Add a binary

Use `--exec` during the build:

```sh
./build.sh \
    --webview-url ./web/index.html \
    --exec /path/to/arm64-v8a/mytool
```

The executable basename becomes its logical JavaScript name:

```js
NativeBridge.exec(["mytool", "--version"]);
```

The first array element is the executable name. Remaining elements are passed as process arguments without shell interpretation.

## No shell evaluation

`NativeBridge.exec()` constructs an argument vector and starts the packaged executable directly.

For example:

```js
NativeBridge.exec(["mytool", "--name", "hello world"]);
```

passes three arguments to the process. KCAPK does not concatenate this into a shell command and does not expose arbitrary shell execution.

## Whitelist model

Only executables supplied with `--exec` are available.

If JavaScript requests a name that was not packaged, KCAPK rejects it:

```text
exec: executable not exposed: <name>
```

JavaScript cannot provide an arbitrary filesystem path to bypass this whitelist.

The whitelist is generated at build time from the basenames of the packaged executables.

## Supported names

Executable basenames may contain:

```text
A-Z
a-z
0-9
.
_
-
```

Names containing other characters are rejected during the build.

## ABI detection

KCAPK uses the host `file` command to inspect each binary and map its ELF architecture to an Android ABI.

Current mappings are:

```text
AArch64 / aarch64 -> arm64-v8a
ARM               -> armeabi-v7a
x86-64 / x86_64   -> x86_64
80386              -> x86
```

Unsupported architectures are rejected.

## Multi-ABI integration

The same logical executable can be supplied once per ABI:

```sh
./build.sh \
    --webview-url ./web/index.html \
    --exec /path/to/arm64-v8a/mytool \
    --exec /path/to/x86_64/mytool
```

Both files have the same basename, so JavaScript still calls:

```js
NativeBridge.exec(["mytool", "--version"]);
```

Android selects the matching native library directory for the device ABI.

Providing the same executable basename more than once for the same ABI is rejected as a duplicate target.

## APK packaging

KCAPK packages executables inside the APK native library tree.

A logical executable named:

```text
my-tool
```

is normalized for packaging and stored as:

```text
lib/<abi>/libexec_my_tool.so
```

Dots and hyphens in the logical basename are converted to underscores for the packaged `.so` filename. The public JavaScript name remains the original basename.

For example:

```text
Logical name:        my-tool
Packaged filename:   libexec_my_tool.so
JavaScript call:     NativeBridge.exec(["my-tool"])
```

## Multiple different tools

`--exec` is repeatable for unrelated executables:

```sh
./build.sh \
    --exec /path/to/arm64-v8a/tool-a \
    --exec /path/to/arm64-v8a/tool-b
```

JavaScript can invoke each independently:

```js
NativeBridge.exec(["tool-a", "--version"]);
NativeBridge.exec(["tool-b", "status"]);
```

## Return value

`NativeBridge.exec()` returns merged standard output and standard error as a string.

```js
var output = NativeBridge.exec(["mytool", "status"]);
```

If the process exits with a non-zero code and produces no output, KCAPK returns:

```text
exec: process exited with code N
```

Other execution failures use an `exec:` textual error.

## Security boundary

The feature is intentionally constrained in three places:

1. bridge access is limited to trusted WebView content,
2. executable names are fixed at build time,
3. arguments are passed directly to `ProcessBuilder` rather than evaluated by a shell.

These constraints reduce the risk of turning the bridge into arbitrary command execution.

The packaged native program itself still defines what operations are possible. A broadly privileged or unsafe executable can expose powerful behavior through its own arguments, so packaged binaries should be treated as part of the application's trusted native code.

## Building native binaries

KCAPK does not compile the binaries supplied with `--exec`. They must already be valid Android executables for the desired ABI.

They may be produced with the Android NDK, another compatible cross-compiler, or an existing build system.

The KCAPK integration point begins with the finished executable file.

## Testing multi-ABI packaging

The repository integration test packages the same fixture executable for multiple ABIs and verifies that the expected entries exist inside the APK.

See [Testing](TESTING.md).

## Next step

Continue with [Release builds](RELEASES.md).
