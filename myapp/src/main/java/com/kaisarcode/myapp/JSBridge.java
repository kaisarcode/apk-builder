package com.kaisarcode.myapp;

import android.content.Context;
import android.webkit.JavascriptInterface;
import android.widget.Toast;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

public class JSBridge {
    private Context context;

    public JSBridge(Context context) {
        this.context = context;
    }

    @JavascriptInterface
    public void showToast(String message) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show();
    }

    @JavascriptInterface
    public boolean isOnline() {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm != null) {
            NetworkInfo netInfo = cm.getActiveNetworkInfo();
            return netInfo != null && netInfo.isConnected();
        }
        return false;
    }
}
