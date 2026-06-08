package com.kaisarcode.myapp;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.content.res.Resources;


public class MainActivity extends Activity {
    private WebView webView;
    private static final String WEBVIEW_URL = "https://google.com/";
    private static final String JS_INTERFACE_NAME = "AndroidBridge";

    @Override
    public void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        Resources res = getResources();

        int layoutResId = res.getIdentifier("activity_main", "layout", getPackageName());
        setContentView(layoutResId);

        int webViewResId = res.getIdentifier("webview", "id", getPackageName());
        webView = (WebView) findViewById(webViewResId);

        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.setWebViewClient(new WebViewClient());

        webView.addJavascriptInterface( new JSBridge(this), JS_INTERFACE_NAME );
        webView.loadUrl(WEBVIEW_URL);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) { webView.goBack(); } else { super.onBackPressed(); }
    }
}
