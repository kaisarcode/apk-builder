package com.kaisarcode.myapp;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class TrustedWebViewClient extends WebViewClient {
    private final Context context;
    private final String[] trustedOrigins;

    public TrustedWebViewClient(Context context, String[] trustedOrigins) {
        this.context = context;
        this.trustedOrigins = trustedOrigins;
    }

    private boolean openExternally(String url) {
        try {
            context.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            return true;
        } catch (Exception ignored) {
            return true;
        }
    }

    private boolean handleNavigation(String url) {
        if (JSBridge.isTrustedUrl(url, trustedOrigins)) {
            return false;
        }

        return openExternally(url);
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        if (!request.isForMainFrame()) {
            return false;
        }

        return handleNavigation(request.getUrl().toString());
    }
}
