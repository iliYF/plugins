// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../platform_interface.dart';

/// A [WebViewPlatformController] that uses a method channel to control the webview.
class MethodChannelWebViewPlatform implements WebViewPlatformController {
  /// Constructs an instance that will listen for webviews broadcasting to the
  /// given [id], using the given [WebViewPlatformCallbacksHandler].
  MethodChannelWebViewPlatform(int id, this._platformCallbacksHandler)
      : assert(_platformCallbacksHandler != null),
        _channel = MethodChannel('plugins.flutter.io/webview_$id') {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final WebViewPlatformCallbacksHandler _platformCallbacksHandler;

  final MethodChannel _channel;

  static const MethodChannel _cookieManagerChannel =
      MethodChannel('plugins.flutter.io/cookie_manager');

  Future<bool> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'javascriptChannelMessage':
        final String channel = call.arguments['channel'];
        final String message = call.arguments['message'];
        _platformCallbacksHandler.onJavaScriptChannelMessage(channel, message);
        return true;
      case 'navigationRequest':
        return await _platformCallbacksHandler.onNavigationRequest(
          url: call.arguments['url'],
          isForMainFrame: call.arguments['isForMainFrame'],
        );
      case 'onPageFinished':
        _platformCallbacksHandler.onPageFinished(call.arguments['url']);
        return null;
      case 'onPageStarted':
        _platformCallbacksHandler.onPageStarted(call.arguments['url']);
        return null;
      case 'onWebResourceError':
        _platformCallbacksHandler.onWebResourceError(
          WebResourceError(
            errorCode: call.arguments['errorCode'],
            description: call.arguments['description'],
            domain: call.arguments['domain'],
            failingUrl: call.arguments['failingUrl'],
            errorType: call.arguments['errorType'] == null
                ? null
                : WebResourceErrorType.values.firstWhere(
                    (WebResourceErrorType type) {
                      return type.toString() ==
                          '$WebResourceErrorType.${call.arguments['errorType']}';
                    },
                  ),
          ),
        );
        return null;
    }

    throw MissingPluginException(
      '${call.method} was invoked but has no handler',
    );
  }

  @override
  Future<void> loadUrl(
    String url,
    Map<String, String> headers,
  ) async {
    assert(url != null);
    return _channel.invokeMethod<void>('loadUrl', <String, dynamic>{
      'url': url,
      'headers': headers,
    });
  }

  @override
  Future<void> postUrl(String url, Uint8List params) async {
    assert(url != null);
    assert(params != null);
    return _channel.invokeMethod('postUrl', <String, dynamic>{
      'url': url,
      'params': params,
    });
  }

  @override
  Future<String> currentUrl() => _channel.invokeMethod<String>('currentUrl');

  @override
  Future<bool> canGoBack() => _channel.invokeMethod<bool>("canGoBack");

  @override
  Future<bool> canGoForward() => _channel.invokeMethod<bool>("canGoForward");

  @override
  Future<void> goBack() => _channel.invokeMethod<void>("goBack");

  @override
  Future<void> goForward() => _channel.invokeMethod<void>("goForward");

  @override
  Future<void> reload() => _channel.invokeMethod<void>("reload");

  @override
  Future<void> clearCache() => _channel.invokeMethod<void>("clearCache");

  @override
  Future<void> updateSettings(WebSettings settings) {
    final Map<String, dynamic> updatesMap = _webSettingsToMap(settings);
    if (updatesMap.isEmpty) {
      return null;
    }
    return _channel.invokeMethod<void>('updateSettings', updatesMap);
  }

  @override
  Future<String> evaluateJavascript(String javascriptString) {
    return _channel.invokeMethod<String>(
        'evaluateJavascript', javascriptString);
  }

  @override
  Future<void> addJavascriptChannels(Set<String> javascriptChannelNames) {
    return _channel.invokeMethod<void>(
        'addJavascriptChannels', javascriptChannelNames.toList());
  }

  @override
  Future<void> removeJavascriptChannels(Set<String> javascriptChannelNames) {
    return _channel.invokeMethod<void>(
        'removeJavascriptChannels', javascriptChannelNames.toList());
  }

  @override
  Future<String> getTitle() => _channel.invokeMethod<String>("getTitle");

  @override
  Future<void> scrollTo(int x, int y) {
    return _channel.invokeMethod<void>('scrollTo', <String, int>{
      'x': x,
      'y': y,
    });
  }

  @override
  Future<void> scrollBy(int x, int y) {
    return _channel.invokeMethod<void>('scrollBy', <String, int>{
      'x': x,
      'y': y,
    });
  }

  @override
  Future<int> getScrollX() => _channel.invokeMethod<int>("getScrollX");

  @override
  Future<int> getScrollY() => _channel.invokeMethod<int>("getScrollY");

  /// Method channel implementation for [WebViewPlatform.clearCookies].
  static Future<bool> clearCookies() {
    return _cookieManagerChannel
        .invokeMethod<bool>('clearCookies')
        .then<bool>((dynamic result) => result);
  }

  /// Method channel implementation for [WebViewPlatform.setCookies].
  static Future<void> setCookies(List<Cookie> cookies) {
    final transferCookies = cookies.map((Cookie c) {
      final output = <String, dynamic>{
        'name': c.name,
        'value': c.value,
        'path': c.path,
        'domain': c.domain,
        'secure': c.secure,
        'httpOnly': c.httpOnly,
        'asString': c.toString(),
      };

      if (c.expires != null) {
        output['expires'] = c.expires.millisecondsSinceEpoch ~/ 1000;
      }

      return output;
    }).toList();

    return _cookieManagerChannel.invokeMethod('setCookies', transferCookies);
  }

  /// Method channel implementation for [WebViewPlatform.hasCookies].
  static Future<bool> hasCookies() {
    return _cookieManagerChannel
        .invokeMethod<bool>('hasCookies')
        .then<bool>((dynamic result) => result ?? false);
  }

  /// Method channel implementation for [WebViewPlatform.getCookies].
  static Future<List<Cookie>> getCookies(String url) {
    return _cookieManagerChannel
        .invokeListMethod<Map>('getCookies', {'url': url}).then((results) {
      if (results == null) {
        return <Cookie>[];
      }

      return results.map((Map result) {
        final c = Cookie(result['name'] ?? '',
            _removeInvalidCharacter(result['value'] ?? ''))
          // following values optionally work on iOS only
          ..path = result['path']
          ..domain = result['domain']
          ..secure = result['secure'] ?? false
          ..httpOnly = result['httpOnly'] ?? true;

        if (result['expires'] != null) {
          c.expires = DateTime.fromMillisecondsSinceEpoch(
              (result['expires'] * 1000).toInt());
        }

        return c;
      }).toList();
    });
  }

  static String _removeInvalidCharacter(String value) {
    // Remove Invalid Character
    var valueModified = value.replaceAll('\\"', "'");
    valueModified = valueModified.replaceAll(String.fromCharCode(32), "");
    return valueModified;
  }

  static Map<String, dynamic> _webSettingsToMap(WebSettings settings) {
    final Map<String, dynamic> map = <String, dynamic>{};
    void _addIfNonNull(String key, dynamic value) {
      if (value == null) {
        return;
      }
      map[key] = value;
    }

    void _addSettingIfPresent<T>(String key, WebSetting<T> setting) {
      if (!setting.isPresent) {
        return;
      }
      map[key] = setting.value;
    }

    _addIfNonNull('jsMode', settings.javascriptMode?.index);
    _addIfNonNull('hasNavigationDelegate', settings.hasNavigationDelegate);
    _addIfNonNull('debuggingEnabled', settings.debuggingEnabled);
    _addIfNonNull(
        'gestureNavigationEnabled', settings.gestureNavigationEnabled);
    _addSettingIfPresent('userAgent', settings.userAgent);
    _addIfNonNull('mixedContentMode', settings.mixedContentMode?.index);
    return map;
  }

  /// Converts a [CreationParams] object to a map as expected by `platform_views` channel.
  ///
  /// This is used for the `creationParams` argument of the platform views created by
  /// [AndroidWebViewBuilder] and [CupertinoWebViewBuilder].
  static Map<String, dynamic> creationParamsToMap(
      CreationParams creationParams) {
    return <String, dynamic>{
      'initialUrl': creationParams.initialUrl,
      'settings': _webSettingsToMap(creationParams.webSettings),
      'javascriptChannelNames': creationParams.javascriptChannelNames.toList(),
      'userAgent': creationParams.userAgent,
      'autoMediaPlaybackPolicy': creationParams.autoMediaPlaybackPolicy.index,
    };
  }
}
