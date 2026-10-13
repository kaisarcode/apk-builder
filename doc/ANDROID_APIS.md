# Android APIs

KCAPK exposes a curated set of Android platform capabilities under:

```js
NativeBridge.Android
```

The goal is not to mirror the complete Android SDK. These APIs cover useful general-purpose operations that a WebView application commonly needs.

All methods require the current top-level WebView state to be trusted. See [WebView and trusted origins](WEBVIEW.md).

Methods are synchronous unless explicitly documented as Promise-returning. See [Async operations](ASYNC.md) for the shared asynchronous contract.

## Toast

```js
NativeBridge.Android.showToast(message);
```

Shows a short Android toast.

## Network state

```js
NativeBridge.Android.isOnline();
```

Returns a boolean indicating whether Android reports an active connected network.

The generated manifest includes `android.permission.ACCESS_NETWORK_STATE`.

## Permissions

Android permissions have two distinct stages in KCAPK:

1. build-time declaration in `AndroidManifest.xml`, and
2. runtime permission or special-access flow when Android requires it.

Optional permissions are declared with repeatable build options:

```sh
./build.sh \
    --permission notifications \
    --permission camera \
    --permission locationCoarse
```

Then application code can query or request them at runtime:

```js
NativeBridge.Android.permissions.has(name);
await NativeBridge.Android.permissions.request(name);
```

`has(name)` is synchronous and returns whether the permission or special access is currently available.

`request(name)` returns a Promise. It resolves with the effective state after Android finishes the permission flow:

```text
true  -> granted / available
false -> denied / unavailable
```

Example:

```js
if (!NativeBridge.Android.permissions.has("notifications")) {
    var granted = await NativeBridge.Android.permissions.request("notifications");
    if (!granted) {
        // continue without notifications
    }
}
```

Supported aliases are:

```text
notifications
exactAlarm
exactAlarms
camera
microphone
location
locationFine
locationCoarse
```

A full Android permission string beginning with `android.permission.` may also be passed to both `--permission` and the runtime permission bridge.

`notifications` maps to `POST_NOTIFICATIONS` and is treated as granted before Android API 33. On API 33+, build with `--permission notifications` before requesting it.

`exactAlarm` and `exactAlarms` map to `SCHEDULE_EXACT_ALARM`. Before API 31 exact-alarm access is treated as available. On newer Android versions, build with `--permission exactAlarm`; KCAPK opens the relevant Settings flow and resolves the Promise after the Activity resumes with the current state.

If Android requires a permission and it was not declared in the generated manifest, `request()` rejects with:

```text
PERMISSION_NOT_DECLARED
```

Only one runtime permission request and one exact-alarm special-access request may be active at a time. A conflicting request rejects with `BUSY`.

The following base permissions are declared automatically because KCAPK uses them for built-in behavior:

```text
android.permission.INTERNET
android.permission.ACCESS_NETWORK_STATE
android.permission.RECEIVE_BOOT_COMPLETED
android.permission.VIBRATE
```

See [Configuration](CONFIGURATION.md) for build-time permission declaration.

## Notifications

Namespace:

```js
NativeBridge.Android.notifications
```

### Check whether notifications can be posted

```js
NativeBridge.Android.notifications.canPost();
```

Returns `false` when notifications are disabled or when Android 13+ notification permission is not granted. Apps targeting Android 13+ notification permission should be built with `--permission notifications`.

### Create a channel

```js
NativeBridge.Android.notifications.createChannel(options);
```

Example:

```js
NativeBridge.Android.notifications.createChannel({
    id: "tasks",
    name: "Tasks",
    description: "Task notifications",
    importance: "high",
    showBadge: true,
    sound: "default"
});
```

Supported channel options:

- `id`: channel identifier. Defaults to `default`.
- `name`: user-visible channel name. Defaults to the channel ID.
- `description`: optional channel description.
- `importance`: `none`, `min`, `low`, `default`, `high`, or an Android importance number.
- `showBadge`: whether the channel may show launcher badges.
- `sound`: `default`, `none`, or a sound URI.

Before API 26, channel creation is treated as successful because channels do not exist there.

### Post a notification

```js
NativeBridge.Android.notifications.post(options);
```

A non-negative `id` is required.

Example:

```js
NativeBridge.Android.notifications.post({
    id: 10,
    channel: "tasks",
    title: "Review server",
    text: "Check the production logs"
});
```

Common options:

- `id`: required notification ID.
- `channel`: channel ID. Defaults to `default`.
- `channelName`: name used when KCAPK automatically creates a missing channel.
- `title`: notification title.
- `text`: notification body.
- `subText`: secondary text.
- `autoCancel`: defaults to `true`.
- `ongoing`: persistent/ongoing state.
- `onlyAlertOnce`: avoid repeated alerting on updates.
- `category`: Android notification category.
- `group`: notification group key.
- `groupSummary`: whether this notification summarizes a group.
- `when`: Unix epoch milliseconds.
- `number`: numeric count/badge value.
- `importance`: pre-26 priority and automatic-channel importance.
- `sound`: pre-26 sound and automatic-channel sound.
- `timeout`: automatic timeout in milliseconds on API 26+.

Progress:

```js
NativeBridge.Android.notifications.post({
    id: 20,
    channel: "sync",
    title: "Synchronizing",
    text: "23 files",
    ongoing: true,
    onlyAlertOnce: true,
    progress: {
        max: 100,
        value: 42,
        indeterminate: false
    }
});
```

On API 26+, channel sound and importance are channel properties. Once Android creates a channel, reposting notifications does not freely redefine them, and the user retains final control through Android settings.

### Cancel notifications

```js
NativeBridge.Android.notifications.cancel(id);
NativeBridge.Android.notifications.cancelAll();
```

## Alarms

Namespace:

```js
NativeBridge.Android.alarms
```

KCAPK alarms are native Android alarms and can trigger while the WebView is not alive. The current native alarm action is a notification.

### Check exact-alarm availability

```js
NativeBridge.Android.alarms.canScheduleExact();
```

On API 31+, exact alarms may require Android's Alarms & reminders special access. Apps that use exact scheduling should be built with `--permission exactAlarm`.

### Schedule an alarm

```js
NativeBridge.Android.alarms.schedule({
    id: 10,
    at: Date.now() + 60000,
    exact: true,
    action: {
        type: "notification",
        channel: "tasks",
        title: "Review server",
        text: "Check the production logs"
    }
});
```

Supported options:

- `id`: required non-negative alarm ID.
- `at`: required Unix epoch milliseconds.
- `exact`: defaults to `false`.
- `allowWhileIdle`: defaults to the value of `exact`.
- `action`: required native action object.

The supported action is:

```js
{
    type: "notification",
    ...notificationOptions
}
```

If the action has no notification `id`, KCAPK uses the alarm ID.

Scheduled definitions are persisted and future alarms are restored after device boot. Past alarms are discarded during restoration.

KCAPK does not implement recurrence rules. Applications calculate future occurrences and schedule their native alarms.

### Cancel alarms

```js
NativeBridge.Android.alarms.cancel(id);
NativeBridge.Android.alarms.cancelAll();
```

## Haptics and vibration

Namespace:

```js
NativeBridge.Android.haptics
```

```js
NativeBridge.Android.haptics.hasVibrator();
NativeBridge.Android.haptics.vibrate(200);
NativeBridge.Android.haptics.effect("click");
NativeBridge.Android.haptics.cancel();
```

Supported predefined effect names:

```text
click
doubleClick
tick
heavyClick
```

On API 29+ KCAPK uses Android predefined vibration effects. Older versions fall back to duration-based vibrations.

The generated manifest includes `android.permission.VIBRATE`.

## Intents

Namespace:

```js
NativeBridge.Android.intents
```

### Share

```js
NativeBridge.Android.intents.share({
    text: "Hello",
    subject: "Optional subject",
    title: "Optional content title",
    chooserTitle: "Share with",
    type: "text/plain"
});
```

Supported options are `text`, `subject`, `title`, `chooserTitle`, and MIME `type` (default `text/plain`). The method returns whether Android could start the Sharesheet.

### Open a URL

```js
NativeBridge.Android.intents.openUrl("https://example.com");
```

Only `http` and `https` URLs are accepted.

### Open application settings

```js
NativeBridge.Android.intents.openAppSettings();
```

Opens the Android application-details settings page for the generated app.

### Receive shares

Incoming shares are enabled at build time with one or more MIME types:

```sh
./build.sh \
    --share-target 'image/*' \
    --share-target 'application/pdf'
```

Then the pending Android share can be consumed synchronously:

```js
var share = NativeBridge.Android.intents.consumeShare();
```

The method returns `null` when there is no pending share. Otherwise it returns an object shaped like:

```js
{
    action: "send",
    type: "image/png",
    text: "optional shared text",
    subject: "optional subject",
    files: [
        {
            uri: "content://...",
            name: "photo.png",
            type: "image/png",
            size: 12345
        }
    ]
}
```

For `ACTION_SEND_MULTIPLE`, `action` is `sendMultiple` and `files` may contain more than one item.

KCAPK does not read or copy the shared file when receiving it. It keeps the incoming `content://` URI and queries metadata such as display name, MIME type, and size. Shared URI access is granted by Android through the incoming intent and may be temporary.

The share is consumed once: after a successful `consumeShare()` call, a second call returns `null` until Android delivers another share.

A universal share target can be declared with `--share-target '*/*'`, though applications should normally register only MIME types they actually understand. The KCAPK test app uses `*/*` specifically to validate generic file reception.

See [Configuration](CONFIGURATION.md) for build-time share target declaration.

## System UI

Namespace:

```js
NativeBridge.Android.systemUI
```

Status bar icon appearance:

```js
NativeBridge.Android.systemUI.statusBar({ icons: "light" });
NativeBridge.Android.systemUI.statusBar({ icons: "dark" });
```

Navigation bar icon appearance:

```js
NativeBridge.Android.systemUI.navigationBar({ icons: "light" });
NativeBridge.Android.systemUI.navigationBar({ icons: "dark" });
```

System bars:

```js
NativeBridge.Android.systemUI.hideBars();
NativeBridge.Android.systemUI.showBars();
```

Dark status-bar icons require API 23+. Dark navigation-bar icons require API 26+.

On modern edge-to-edge Android versions, the visible bar background is generally application content behind the system bars rather than a separately painted bar color.

## Clipboard

Namespace:

```js
NativeBridge.Android.clipboard
```

```js
NativeBridge.Android.clipboard.set("text");
NativeBridge.Android.clipboard.get();
NativeBridge.Android.clipboard.hasText();
NativeBridge.Android.clipboard.clear();
```

`get()` returns the first clipboard item coerced to text, or an empty string when unavailable.

On API 28+ `clear()` clears the primary clip directly. Older versions replace it with an empty text clip.

## Screen wake behavior

Namespace:

```js
NativeBridge.Android.screen
```

```js
NativeBridge.Android.screen.keepOn(true);
NativeBridge.Android.screen.keepOn(false);
```

The flag applies while the generated Activity is visible. It is not a background wake lock.

## Adding more Android APIs

New integrations should:

- expose general-purpose primitives rather than application-specific concepts,
- live under `NativeBridge.Android`,
- use a dedicated Java bridge class when non-trivial,
- avoid arbitrary reflection or unrestricted Android-class access,
- document permissions and Android-version behavior,
- use the shared Promise layer when a result is inherently asynchronous.

Activity-result based APIs such as future file pickers should use the shared async request/result registry rather than feature-specific callback conventions.

## Next step

Continue with [External binaries](EXTERNAL_BINARIES.md).
