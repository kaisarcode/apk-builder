# Alarms

Activation:

```sh
--api alarms
```

Namespace:

```js
NativeBridge.Android.alarms
```

Enabling alarms adds the native alarm classes, alarm receivers, boot restore support, and `RECEIVE_BOOT_COMPLETED` to the generated Manifest.

The current native alarm action is a notification. KCAPK includes the notification internals required by alarms automatically; this does not expose `NativeBridge.Android.notifications` unless `--api notifications` is also enabled.

## Exact-alarm access

```js
NativeBridge.Android.alarms.canScheduleExact();
```

On API 31+, exact alarms may require Android's Alarms & reminders special access.

If exact scheduling is needed, declare:

```sh
--permission exactAlarm
```

Use `--api permissions` if the web app needs to drive the special-access request flow itself.

## Schedule

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

Options:

- `id`: required non-negative alarm ID.
- `at`: required Unix epoch milliseconds.
- `exact`: defaults to `false`.
- `allowWhileIdle`: defaults to the value of `exact`.
- `action`: required native action object.

If the notification action has no `id`, KCAPK uses the alarm ID.

## Persistence and reboot

Scheduled definitions are stored in `SharedPreferences`. Future alarms are restored after device boot. Past alarms are discarded during restoration.

The alarm fires natively even if the WebView is not alive.

## Recurrence

KCAPK does not implement recurrence rules. The application calculates future occurrences and schedules the corresponding native alarms.

## Cancel

```js
NativeBridge.Android.alarms.cancel(id);
NativeBridge.Android.alarms.cancelAll();
```

The public alarm methods are synchronous.
