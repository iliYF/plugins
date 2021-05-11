package io.flutter.plugins.webviewflutter;

import android.webkit.WebViewClient;

public interface FlutterWebViewDelegate {

    WebViewClient createWebViewClient();
    FlutterWebChromeClient createWebChromeClient();

}
