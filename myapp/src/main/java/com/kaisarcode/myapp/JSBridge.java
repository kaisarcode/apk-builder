package com.kaisarcode.myapp;

import android.content.Context;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.widget.Toast;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import java.net.URI;

public class JSBridge {
    private static final String LOCAL_ASSET_PREFIX = "file:///android_asset/";
    private final Context context;
    private final WebView webView;
    private final String[] trustedOrigins;

    public JSBridge(Context context, WebView webView, String[] trustedOrigins) {
        this.context = context;
        this.webView = webView;
        this.trustedOrigins = trustedOrigins;
    }

    public static boolean isTrustedUrl(String url, String[] trustedOrigins) {
        if (url == null || url.isEmpty()) {
            return false;
        }

        if (url.startsWith(LOCAL_ASSET_PREFIX)) {
            return true;
        }

        try {
            URI parsedUrl = URI.create(url);
            String origin = normalizeOrigin(parsedUrl);

            if (origin == null) {
                return false;
            }

            for (String trustedOrigin : trustedOrigins) {
                if (origin.equals(trustedOrigin)) {
                    return true;
                }
            }
        } catch (IllegalArgumentException ignored) {
            return false;
        }

        return false;
    }

    private static String normalizeOrigin(URI uri) {
        String scheme = uri.getScheme();
        String host = uri.getHost();

        if (scheme == null || host == null) {
            return null;
        }

        scheme = scheme.toLowerCase();
        host = host.toLowerCase();

        int port = uri.getPort();
        if (port == -1) {
            return scheme + "://" + host;
        }

        return scheme + "://" + host + ":" + port;
    }

    private boolean canUseBridge() {
        return isTrustedUrl(webView.getUrl(), trustedOrigins);
    }

    @JavascriptInterface
    public void showToast(String message) {
        if (!canUseBridge()) {
            return;
        }

        Toast.makeText(context, message, Toast.LENGTH_SHORT).show();
    }

    @JavascriptInterface
    public boolean isOnline() {
        if (!canUseBridge()) {
            return false;
        }

        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm != null) {
            NetworkInfo netInfo = cm.getActiveNetworkInfo();
            return netInfo != null && netInfo.isConnected();
        }
        return false;
    }
}
