# NativeBridge

`NativeBridge` is the JavaScript API KCAPK injects into trusted WebView content.

It is intentionally small and explicit. KCAPK does not expose arbitrary Java reflection or the complete Android SDK.

## Public structure

```text
NativeBridge
├── exec(...)
└── Android
    ├── showToast(...)
    ├── isOnline()
    ├── permissions
    ├── notifications
    ├── alarms
    ├── haptics
    ├── intents
    ├── systemUI
    ├── clipboard
    └── screen
```

The separation is deliberate:

- `NativeBridge.exec()` is a KCAPK facility for explicitly packaged native executables.
- `NativeBridge.Android.*` contains Android framework integrations.

This prevents Android APIs from turning the top-level namespace into an unstructured collection of unrelated methods.

## Trust boundary

The bridge is available only while KCAPK considers the current top-level WebView page trusted.

Packaged local assets are trusted automatically. Remote applications use origin matching and optional `--trusted-origin` entries.

See [WebView and trusted origins](WEBVIEW.md).

## Synchronous and asynchronous methods

Methods that can produce an immediate result remain synchronous:

```js
var online = NativeBridge.Android.isOnline();
var value = NativeBridge.Android.clipboard.get();
var opened = NativeBridge.Android.intents.openUrl("https://example.com");
```

Operations that wait for native work or user interaction return Promises:

```js
var output = await NativeBridge.exec(["mytool", "status"]);
var granted = await NativeBridge.Android.permissions.request("notifications");
```

KCAPK does not provide separate sync and async variants of the same operation. An operation uses a Promise when its result is inherently deferred.

The Promise/request mechanism, page-generation protection, lifecycle behavior, and common errors are documented in [Async operations](ASYNC.md).

## Error model

Synchronous Android bridge methods generally return `false` when an immediate operation cannot be performed and empty strings when a string value is unavailable.

Asynchronous operations reject their Promise with a JavaScript `Error`. KCAPK adds a stable `code` property and may attach operation-specific fields such as an executable `exitCode` or captured `output`.

Example:

```js
try {
    await NativeBridge.exec(["missing-tool"]);
} catch (error) {
    console.log(error.code);
    console.log(error.message);
}
```

## Android APIs

The complete current API exposed under `NativeBridge.Android` is documented separately in [Android APIs](ANDROID_APIS.md).

## External executables

Packaging native programs, ABI handling, the executable whitelist, and the Promise returned by `NativeBridge.exec()` are documented in [External binaries](EXTERNAL_BINARIES.md).

## Implementation boundary

The public JavaScript wrapper lives as a generated Android raw resource rather than as a Java string. Java bridge classes implement the native side, while the JavaScript resource defines the public namespace and Promise registry.

This keeps the JavaScript contract readable and allows future asynchronous Android APIs to share one request mechanism instead of inventing per-feature callbacks.

## Next step

Continue with [Async operations](ASYNC.md).
