# Android APIs

KCAPK exposes a curated set of Android platform capabilities under:

```js
NativeBridge.Android
```

The goal is not to mirror the complete Android SDK. These APIs are intended to cover useful general-purpose operations that a WebView application commonly needs.

All methods require the current WebView page to be trusted. See [WebView and trusted origins](WEBVIEW.md).

## Toast

```js
NativeBridge.Android.showToast(message);
```

Shows a short Android toast.

Parameters:

- `message`: text to display.

The method does not return a meaningful result.

Example:

```js
NativeBridge.Android.showToast("Saved");
```

## Network state

```js
NativeBridge.Android.isOnline();
```

Returns a boolean indicating whether Android reports an active connected network.

Example:

```js
if (NativeBridge.Android.isOnline()) {
    // network available
}
```

The generated manifest includes `android.permission.ACCESS_NETWORK_STATE`.

## Permissions

```js
NativeBridge.Android.permissions.has(name);
NativeBridge.Android.permissions.request(name);
```

`has(name)` returns whether the requested permission or special access is currently available.

`request(name)` returns whether KCAPK could start the relevant Android request flow. A `true` return value does not necessarily mean the user granted the permission. Query `has(name)` again after the user returns to the application.

Supported aliases in the bridge are:

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

A full Android permission string beginning with `android.permission.` may also be passed.

Example:

```js
if (!NativeBridge.Android.permissions.has("notifications")) {
    NativeBridge.Android.permissions.request("notifications");
}
```

`notifications` maps to `POST_NOTIFICATIONS` and is treated as granted on Android versions before API 33.

`exactAlarm` and `exactAlarms` refer to Android's exact-alarm special access. On Android versions before API 31, this is treated as available.

Important: a permission must also be declared by the generated Android manifest to be usable. KCAPK currently declares the permissions needed by its built-in capabilities. The camera, microphone, and location aliases exist in the bridge implementation but are not currently added to the manifest by default.

## Notifications

Namespace:

```js
NativeBridge.Android.notifications
```

### Check whether notifications can be posted

```js
NativeBridge.Android.notifications.canPost();
```

Returns `false` when notifications are disabled or when Android 13+ notification permission is not granted.

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

On Android versions before API 26, channel creation is treated as successful because notification channels do not exist there.

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
- `autoCancel`: automatically dismiss after the user opens it. Defaults to `true`.
- `ongoing`: make the notification ongoing/persistent.
- `onlyAlertOnce`: avoid repeated alerting when updating the same notification.
- `category`: Android notification category.
- `group`: notification group key.
- `groupSummary`: whether this notification summarizes a group.
- `when`: timestamp in Unix epoch milliseconds.
- `number`: numeric badge/count value.
- `importance`: used for pre-API-26 priority and for automatic channel creation.
- `sound`: used for pre-API-26 notifications and for automatic channel creation.
- `timeout`: automatic timeout in milliseconds on API 26+.

Progress can be provided as:

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

For indeterminate progress:

```js
progress: {
    max: 100,
    value: 0,
    indeterminate: true
}
```

On Android API 26+, channel sound and importance are channel properties. Once Android creates a channel, posting another notification does not freely redefine those settings; the user also retains control through Android system settings.

### Cancel notifications

```js
NativeBridge.Android.notifications.cancel(id);
NativeBridge.Android.notifications.cancelAll();
```

`cancel(id)` cancels one notification by ID.

`cancelAll()` cancels all notifications posted by the application.

## Alarms

Namespace:

```js
NativeBridge.Android.alarms
```

KCAPK alarms are native Android alarms. They can trigger while the WebView is not alive.

The currently supported alarm action is a notification.

### Check exact-alarm availability

```js
NativeBridge.Android.alarms.canScheduleExact();
```

Returns whether exact alarms can currently be scheduled.

On Android API 31+, exact alarms may require Android's Alarms & reminders special access.

### Schedule an alarm

```js
NativeBridge.Android.alarms.schedule(options);
```

Example:

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

Supported alarm options:

- `id`: required non-negative alarm ID.
- `at`: required Unix epoch time in milliseconds.
- `exact`: whether to request exact scheduling. Defaults to `false`.
- `allowWhileIdle`: whether the alarm may run while the device is idle. Defaults to the value of `exact`.
- `action`: required native action object.

The supported action is:

```js
{
    type: "notification",
    ...notificationOptions
}
```

If the notification action does not contain its own `id`, KCAPK uses the alarm ID as the notification ID.

Scheduled definitions are persisted by the generated application and future alarms are restored after device boot. Past alarms are discarded during restoration.

KCAPK does not implement recurrence rules. Applications should calculate future occurrences and schedule the corresponding native alarm themselves.

### Cancel alarms

```js
NativeBridge.Android.alarms.cancel(id);
NativeBridge.Android.alarms.cancelAll();
```

Cancelling an alarm also removes its stored definition.

## Haptics and vibration

Namespace:

```js
NativeBridge.Android.haptics
```

### Check hardware availability

```js
NativeBridge.Android.haptics.hasVibrator();
```

Returns whether Android reports a vibrator.

### Vibrate for a duration

```js
NativeBridge.Android.haptics.vibrate(milliseconds);
```

Example:

```js
NativeBridge.Android.haptics.vibrate(200);
```

The duration must be greater than zero.

### Predefined haptic effects

```js
NativeBridge.Android.haptics.effect(name);
```

Supported names:

```text
click
doubleClick
tick
heavyClick
```

On API 29+ KCAPK uses Android predefined vibration effects. Older Android versions fall back to short duration-based vibrations.

### Cancel vibration

```js
NativeBridge.Android.haptics.cancel();
```

The generated manifest includes `android.permission.VIBRATE`.

## Intents

Namespace:

```js
NativeBridge.Android.intents
```

### Share

```js
NativeBridge.Android.intents.share(options);
```

Example:

```js
NativeBridge.Android.intents.share({
    text: "Hello",
    subject: "Optional subject",
    title: "Optional content title",
    chooserTitle: "Share with",
    type: "text/plain"
});
```

Supported options:

- `text`: shared text.
- `subject`: optional subject.
- `title`: optional content title.
- `chooserTitle`: optional Android chooser title.
- `type`: MIME type. Defaults to `text/plain`.

Returns whether Android could start the Sharesheet intent.

### Open a URL

```js
NativeBridge.Android.intents.openUrl(url);
```

Only `http` and `https` URLs are accepted.

Returns whether Android could start an activity for the URL.

### Open application settings

```js
NativeBridge.Android.intents.openAppSettings();
```

Opens the Android application-details settings page for the generated app.

## System UI

Namespace:

```js
NativeBridge.Android.systemUI
```

### Status bar icon appearance

```js
NativeBridge.Android.systemUI.statusBar({ icons: "light" });
NativeBridge.Android.systemUI.statusBar({ icons: "dark" });
```

`light` means light-colored foreground icons. `dark` means dark-colored foreground icons.

Dark status-bar icons require Android API 23+.

### Navigation bar icon appearance

```js
NativeBridge.Android.systemUI.navigationBar({ icons: "light" });
NativeBridge.Android.systemUI.navigationBar({ icons: "dark" });
```

Dark navigation-bar icons require Android API 26+.

### Hide system bars

```js
NativeBridge.Android.systemUI.hideBars();
```

Hides status and navigation bars using immersive behavior.

### Show system bars

```js
NativeBridge.Android.systemUI.showBars();
```

Restores status and navigation bars.

These calls control system-bar visibility and icon appearance. On modern edge-to-edge Android versions, the visible bar background is generally application content behind the system bars rather than a separately painted bar color.

## Clipboard

Namespace:

```js
NativeBridge.Android.clipboard
```

### Set text

```js
NativeBridge.Android.clipboard.set("text");
```

Returns whether the clipboard service was available and the text was set.

### Get text

```js
NativeBridge.Android.clipboard.get();
```

Returns the first clipboard item coerced to text, or an empty string when no value is available.

### Check clipboard content

```js
NativeBridge.Android.clipboard.hasText();
```

Returns whether Android reports a primary clipboard item.

### Clear clipboard

```js
NativeBridge.Android.clipboard.clear();
```

On API 28+ KCAPK clears the primary clip directly. Older versions replace it with an empty text clip.

## Screen wake behavior

Namespace:

```js
NativeBridge.Android.screen
```

### Keep the screen on

```js
NativeBridge.Android.screen.keepOn(true);
```

Adds Android's keep-screen-on window flag to the generated Activity.

### Return to normal timeout behavior

```js
NativeBridge.Android.screen.keepOn(false);
```

Removes the flag.

This applies while the Activity is visible. It is not a background wake lock.

## Adding more Android APIs

New Android integrations should follow the same principles:

- expose general-purpose primitives rather than application-specific concepts,
- keep public APIs under `NativeBridge.Android`,
- use a dedicated Java bridge class when the capability is non-trivial,
- avoid arbitrary reflection or unrestricted access to Android classes,
- document permissions and Android-version behavior explicitly,
- add asynchronous capabilities only through a consistent future Promise/request mechanism.
