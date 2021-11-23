package io.flutter.plugins.webviewflutter;

import android.webkit.WebViewClient;

public interface FlutterWebViewDelegate {

    WebViewClient createWebViewClient(WebViewClient flutterWebViewClient);
    FlutterWebChromeClient createWebChromeClient();

}
