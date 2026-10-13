# Async operations

KCAPK uses one Promise-based request layer for native operations whose result is not available immediately.

The public API does not expose request IDs or callback objects. Application code uses normal JavaScript Promises:

```js
var output = await NativeBridge.exec(["mytool", "status"]);
var granted = await NativeBridge.Android.permissions.request("notifications");
```

## Which methods are async

An operation is asynchronous when it must wait for native work, Android lifecycle callbacks, or user interaction.

Current asynchronous operations are:

```text
NativeBridge.exec(...)
NativeBridge.Android.permissions.request(...)
```

Immediate operations remain synchronous. KCAPK does not create duplicate `foo()` / `fooAsync()` APIs.

## Request flow

Each Promise receives an internal request ID and the generation of the current top-level WebView page.

Conceptually:

```text
JavaScript Promise
    -> AndroidBridge request
    -> native worker / Android system flow
    -> native result
    -> WebView.evaluateJavascript()
    -> Promise resolve or reject
```

The request IDs are internal implementation details and are not part of the public API.

## Page generations

Each top-level page load receives a new generation number.

A native request belongs to the page generation that created it. If navigation starts before the request completes, KCAPK drops the stale native result rather than delivering it into a different page.

The JavaScript wrapper also rejects pending requests with:

```text
PAGE_CHANGED
```

when it observes a generation change while the old document is still alive.

This prevents a delayed permission result or native process result from resolving a Promise in unrelated content after navigation.

## Native completion

The native side completes requests through a private bridge callback. It is not intended for application code.

Successful requests resolve with the operation result.

Failed requests reject with a JavaScript `Error` containing at least:

```js
error.code
error.message
```

Operation-specific fields may also be included.

For example, a failed native executable can expose:

```js
error.code === "EXEC_FAILED"
error.exitCode
error.output
```

## Common error codes

The current infrastructure uses codes such as:

```text
BRIDGE_NOT_READY
BRIDGE_UNAVAILABLE
BRIDGE_DESTROYED
NATIVE_START_FAILED
INVALID_NATIVE_RESPONSE
INVALID_ARGUMENT
ACTIVITY_UNAVAILABLE
PERMISSION_REQUEST_FAILED
BUSY
EXEC_NOT_EXPOSED
EXEC_FAILED
CANCELLED
PAGE_CHANGED
INTERNAL_ERROR
```

Additional APIs may define more specific codes while keeping the same Promise error shape.

## External executables

`NativeBridge.exec()` always returns a Promise.

Native processes run outside the JavaScript bridge thread in a bounded worker pool, so JavaScript no longer waits inside the synchronous `addJavascriptInterface` call while the process executes.

Multiple executions can be pending concurrently:

```js
var results = await Promise.all([
    NativeBridge.exec(["tool-a"]),
    NativeBridge.exec(["tool-b"])
]);
```

When the WebView moves to another page, running processes belonging to older page generations are terminated when possible.

When the Activity is destroyed, KCAPK destroys active processes and shuts down the executor.

See [External binaries](EXTERNAL_BINARIES.md) for the complete executable integration model.

## Permissions

`NativeBridge.Android.permissions.request()` resolves to the effective permission state:

```js
var granted = await NativeBridge.Android.permissions.request("notifications");
```

The Promise resolves:

```text
true  -> granted / available
false -> denied / unavailable after the user flow
```

Runtime permissions resolve from Android's permission-result callback.

Special access such as exact alarms is checked again when the Activity resumes after returning from Android Settings.

Only one runtime permission dialog and one exact-alarm settings request are allowed to be active at a time. A conflicting request rejects with `BUSY`.

## Activity results

The async layer also maintains a request-code registry for Android activity results.

`MainActivity` forwards `onActivityResult()` to the bridge. No current public API consumes that registry yet, but it is the intended basis for future operations such as file pickers, directory selection, camera flows, or other Android activities that return data.

This keeps those future APIs on the same Promise mechanism rather than adding feature-specific callback conventions.

## UI-thread delivery

Native results are delivered back into the WebView with `evaluateJavascript()` on the Activity UI thread.

The native bridge itself may be called by WebView on a non-UI thread, so operations that interact with Android UI or lifecycle APIs explicitly switch to the Activity thread when required.

## Adding new async APIs

A new async bridge API should:

1. register the request in the shared async layer,
2. start its native operation,
3. keep the request ID and page generation associated with the operation,
4. resolve or reject through the shared completion mechanism,
5. stop or discard stale work when the page changes when practical,
6. document cancellation and lifecycle behavior.

The public API should expose only the natural Promise-returning method, not the internal request machinery.

## Next step

Continue with [Android APIs](ANDROID_APIS.md).
