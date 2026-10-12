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

The bridge is available only to trusted WebView content.

Packaged local assets are trusted automatically. Remote applications use origin matching and optional `--trusted-origin` entries.

See [WebView and trusted origins](WEBVIEW.md).

## Synchronous interface

The current bridge methods are synchronous from JavaScript's point of view and return primitive values such as strings or booleans.

Examples:

```js
var online = NativeBridge.Android.isOnline();
var value = NativeBridge.Android.clipboard.get();
var started = NativeBridge.Android.intents.openUrl("https://example.com");
```

A boolean `true` generally means the native operation was accepted or started successfully. It does not always mean a later system interaction completed successfully.

For example, a permission request may return `true` because KCAPK successfully opened Android's permission flow. The application should query the permission state again after the user returns.

## Error model

Most Android bridge methods return `false` when:

- the bridge is unavailable for the current page,
- the Android service is unavailable,
- input is invalid,
- a required permission or special access is missing, or
- Android rejects the requested operation.

String-returning operations generally return an empty string when no value is available.

`NativeBridge.exec()` is different: it returns process output as a string and uses textual `exec:` errors for invalid or rejected execution requests.

## Android APIs

The complete current API exposed under `NativeBridge.Android` is documented separately in [Android APIs](ANDROID_APIS.md).

## External executables

Packaging native programs, ABI handling, the executable whitelist, and the `NativeBridge.exec()` contract are documented in [External binaries](EXTERNAL_BINARIES.md).

## Future asynchronous APIs

Some Android capabilities naturally require asynchronous results, such as file pickers or activity-result based flows. KCAPK does not currently expose a general Promise/request-ID layer.

Such APIs should be added only after a consistent asynchronous bridge mechanism exists rather than inventing a different callback convention for each feature.

## Next step

Continue with [Android APIs](ANDROID_APIS.md).
