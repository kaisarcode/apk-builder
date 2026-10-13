/**
 * native_bridge.js
 * Summary: JavaScript bridge for KCAPK WebView native communication.
 *
 * Author:  KaisarCode
 * Website: https://kaisarcode.com
 * License: https://www.gnu.org/licenses/gpl-3.0.html
 */

(function () {
    "use strict";

    if (window.NativeBridge && window.NativeBridge.__kcapk === true) {
        return;
    }

    var pending = Object.create(null);
    var nextRequestId = 1;

    /**
     * Creates a standardized error object for native bridge failures.
     *
     * @param {string} code - Error code identifier.
     * @param {string} message - Human-readable error message.
     * @param {Object} [details] - Additional error details.
     * @return {Error} Configured error object.
     */
    function makeError(code, message, details) {
        var error = new Error(message || "Native request failed");
        error.code = code || "NATIVE_ERROR";

        if (details) {
            Object.keys(details).forEach(function (key) {
                if (key !== "code" && key !== "message") {
                    error[key] = details[key];
                }
            });
        }

        return error;
    }

    /**
     * Rejects all pending requests with the specified error.
     *
     * @param {string} code - Error code identifier.
     * @param {string} message - Human-readable error message.
     * @return {void}
     */
    function rejectAll(code, message) {
        Object.keys(pending).forEach(function (id) {
            var request = pending[id];
            delete pending[id];
            request.reject(makeError(code, message));
        });
    }

    /**
     * Initiates an asynchronous native request with a starter function.
     *
     * @param {Function} starter - Function called with (requestId, generation)
     * to start the request.
     * @return {Promise} Promise resolved/rejected based on native response.
     */
    function asyncRequest(starter) {
        return new Promise(function (resolve, reject) {
            var requestId = nextRequestId++;
            var generation = api.__generation;

            if (!generation) {
                reject(makeError("BRIDGE_NOT_READY", "NativeBridge is not ready for this page"));
                return;
            }

            pending[requestId] = {
                generation: generation,
                resolve: resolve,
                reject: reject
            };

            var started = false;
            try {
                started = starter(requestId, generation) === true;
            } catch (cause) {
                delete pending[requestId];
                reject(makeError("NATIVE_START_FAILED", cause && cause.message ? cause.message : String(cause)));
                return;
            }

            if (!started && pending[requestId]) {
                delete pending[requestId];
                reject(makeError("BRIDGE_UNAVAILABLE", "Native request could not be started"));
            }
        });
    }

    /**
     * Completes a pending request with the native response.
     *
     * @param {number} requestId - Identifier of the pending request.
     * @param {number} generation - Generation number for page change detection.
     * @param {boolean} success - Whether the native call succeeded.
     * @param {string} [payloadJson] - JSON payload from native side.
     * @return {void}
     */
    function complete(requestId, generation, success, payloadJson) {
        var request = pending[requestId];
        if (!request || request.generation !== generation || api.__generation !== generation) {
            return;
        }

        delete pending[requestId];

        var payload = {};
        if (payloadJson) {
            try {
                payload = JSON.parse(payloadJson);
            } catch (cause) {
                request.reject(makeError("INVALID_NATIVE_RESPONSE", "NativeBridge received an invalid response"));
                return;
            }
        }

        if (success) {
            request.resolve(Object.prototype.hasOwnProperty.call(payload, "value") ? payload.value : undefined);
            return;
        }

        request.reject(makeError(payload.code, payload.message, payload));
    }

    var api = {
        __kcapk: true,
        __generation: 0,
        __setGeneration: function (generation) {
            if (api.__generation && api.__generation !== generation) {
                rejectAll("PAGE_CHANGED", "The WebView page changed before the native request completed");
            }
            api.__generation = generation;
        },
        __complete: complete,

        exec: function (args) {
            return asyncRequest(function (requestId, generation) {
                return window.AndroidBridge.exec(requestId, generation, JSON.stringify(args || []));
            });
        },

        Android: {
            showToast: function (message) {
                return window.AndroidBridge.showToast(message);
            },
            isOnline: function () {
                return window.AndroidBridge.isOnline();
            },
            permissions: {
                has: function (name) {
                    return window.AndroidBridge.permissionHas(name);
                },
                request: function (name) {
                    return asyncRequest(function (requestId, generation) {
                        return window.AndroidBridge.permissionRequest(requestId, generation, name);
                    });
                }
            },
            notifications: {
                canPost: function () {
                    return window.AndroidBridge.notificationCanPost();
                },
                createChannel: function (options) {
                    return window.AndroidBridge.notificationCreateChannel(JSON.stringify(options || {}));
                },
                post: function (options) {
                    return window.AndroidBridge.notificationPost(JSON.stringify(options || {}));
                },
                cancel: function (id) {
                    return window.AndroidBridge.notificationCancel(id);
                },
                cancelAll: function () {
                    return window.AndroidBridge.notificationCancelAll();
                }
            },
            alarms: {
                canScheduleExact: function () {
                    return window.AndroidBridge.alarmCanScheduleExact();
                },
                schedule: function (options) {
                    return window.AndroidBridge.alarmSchedule(JSON.stringify(options || {}));
                },
                cancel: function (id) {
                    return window.AndroidBridge.alarmCancel(id);
                },
                cancelAll: function () {
                    return window.AndroidBridge.alarmCancelAll();
                }
            },
            haptics: {
                hasVibrator: function () {
                    return window.AndroidBridge.hapticHasVibrator();
                },
                vibrate: function (milliseconds) {
                    return window.AndroidBridge.hapticVibrate(milliseconds);
                },
                effect: function (name) {
                    return window.AndroidBridge.hapticEffect(name);
                },
                cancel: function () {
                    return window.AndroidBridge.hapticCancel();
                }
            },
            intents: {
                share: function (options) {
                    return window.AndroidBridge.intentShare(JSON.stringify(options || {}));
                },
                openUrl: function (url) {
                    return window.AndroidBridge.intentOpenUrl(url);
                },
                openAppSettings: function () {
                    return window.AndroidBridge.intentOpenAppSettings();
                }
            },
            systemUI: {
                statusBar: function (options) {
                    return window.AndroidBridge.systemUIStatusBar(JSON.stringify(options || {}));
                },
                navigationBar: function (options) {
                    return window.AndroidBridge.systemUINavigationBar(JSON.stringify(options || {}));
                },
                hideBars: function () {
                    return window.AndroidBridge.systemUIHideBars();
                },
                showBars: function () {
                    return window.AndroidBridge.systemUIShowBars();
                }
            },
            clipboard: {
                set: function (text) {
                    return window.AndroidBridge.clipboardSet(text);
                },
                get: function () {
                    return window.AndroidBridge.clipboardGet();
                },
                hasText: function () {
                    return window.AndroidBridge.clipboardHasText();
                },
                clear: function () {
                    return window.AndroidBridge.clipboardClear();
                }
            },
            screen: {
                keepOn: function (enabled) {
                    return window.AndroidBridge.screenKeepOn(!!enabled);
                }
            }
        }
    };

    window.NativeBridge = api;
})();
