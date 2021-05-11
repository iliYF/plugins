// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.webviewflutter;

import android.net.Uri;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.webkit.CookieManager;

import android.webkit.ValueCallback;
import java.net.HttpCookie;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

class FlutterCookieManager implements MethodCallHandler {
  private final MethodChannel methodChannel;

  FlutterCookieManager(BinaryMessenger messenger) {
    methodChannel = new MethodChannel(messenger, "plugins.flutter.io/cookie_manager");
    methodChannel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(MethodCall methodCall, Result result) {
    switch (methodCall.method) {
      case "clearCookies":
        clearCookies(result);
        break;
      case "setCookies":
        setCookies(methodCall, result);
        break;
      case "hasCookies":
        hasCookies(result);
        break;
      case "getCookies":
        getCookies(methodCall, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  void dispose() {
    methodChannel.setMethodCallHandler(null);
  }

  private static void clearCookies(final Result result) {
    CookieManager cookieManager = CookieManager.getInstance();
    final boolean hasCookies = cookieManager.hasCookies();
    if (Build.VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
      cookieManager.removeAllCookies(
          new ValueCallback<Boolean>() {
            @Override
            public void onReceiveValue(Boolean value) {
              result.success(hasCookies);
            }
          });
    } else {
      cookieManager.removeAllCookie();
      result.success(hasCookies);
    }
  }

  private static void setCookies(final MethodCall methodCall, final Result result) {
    if (!(methodCall.arguments() instanceof List)) {
      result.error(
              "Invalid argument. Expected List<Map<String,String>>, received "
                      + (methodCall.arguments().getClass().getSimpleName()),
              null,
              null);
      return;
    }

    final List<Map<String, Object>> serializedCookies = methodCall.arguments();

    CookieManager cookieManager = CookieManager.getInstance();
    cookieManager.setAcceptCookie(true);

    for (Map<String, Object> cookieMap : serializedCookies) {
      Object domain = cookieMap.get("domain");
      String domainString = domain == null ? "" : domain.toString();
      cookieManager.setCookie(domainString, cookieMap.get("asString").toString());
    }

    result.success(null);
  }

  private static void hasCookies(final Result result) {
    CookieManager cookieManager = CookieManager.getInstance();
    final boolean hasCookies = cookieManager.hasCookies();
    result.success(hasCookies);
  }

  private static void getCookies(final MethodCall methodCall, final Result result) {
    if (!(methodCall.arguments() instanceof Map)) {
      result.error(
              "Invalid argument. Expected Map<String,String>, received "
                      + (methodCall.arguments().getClass().getSimpleName()),
              null,
              null);
      return;
    }

    final Map<String, String> arguments = methodCall.arguments();

    CookieManager cookieManager = CookieManager.getInstance();

    final String url = arguments.get("url");
    final String allCookiesString = url == null ? null : cookieManager.getCookie(url);
    final ArrayList<String> individualCookieStrings = allCookiesString == null ?
            new ArrayList<String>()
            : new ArrayList<String>(Arrays.asList(allCookiesString.split(";")));

    ArrayList<Map<String, Object>> serializedCookies = new ArrayList<>();
    for (String cookieString : individualCookieStrings) {
      try {
        final HttpCookie cookie = HttpCookie.parse(cookieString).get(0);
        if (cookie.getDomain() == null) {
          cookie.setDomain(Uri.parse(url).getHost());
        }
        if (cookie.getPath() == null) {
          cookie.setPath("/");
        }
        serializedCookies.add(cookieToMap(cookie));
      } catch (IllegalArgumentException e) {
        // Cookie is invalid. Ignoring.
      }
    }

    result.success(serializedCookies);
  }

  private static Map<String, Object> cookieToMap(HttpCookie cookie) {
    final HashMap<String, Object> resultMap = new HashMap<>();
    resultMap.put("name", cookie.getName());
    resultMap.put("value", cookie.getValue());
    resultMap.put("path", cookie.getPath());
    resultMap.put("domain", cookie.getDomain());
    resultMap.put("secure", cookie.getSecure());

    if (!cookie.hasExpired() && !cookie.getDiscard() && cookie.getMaxAge() > 0) {
      // translate `max-age` to `expires` by computing future expiration date
      long expires = (System.currentTimeMillis() / 1000) + cookie.getMaxAge();
      resultMap.put("expires", expires);
    }

    if (Build.VERSION.SDK_INT >= VERSION_CODES.N) {
      resultMap.put("httpOnly", cookie.isHttpOnly());
    }

    return resultMap;
  }

}
