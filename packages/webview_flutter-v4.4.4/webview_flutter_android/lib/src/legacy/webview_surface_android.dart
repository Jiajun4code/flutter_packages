/*
 * Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:webview_flutter_platform_interface/src/webview_flutter_platform_interface_legacy.dart';

import '../android_webview.dart';
import 'webview_android.dart';
import 'webview_android_widget.dart';

/// Android [WebViewPlatform] that uses [AndroidViewSurface] to build the
/// [WebView] widget.
///
/// To use this, set [WebView.platform] to an instance of this class.
///
/// This implementation uses [AndroidViewSurface] to render the [WebView] on
/// Android. It solves multiple issues related to accessibility and interaction
/// with the [WebView] at the cost of some performance on Android versions below
/// 10.
///
/// To support transparent backgrounds on all Android devices, this
/// implementation uses hybrid composition when the opacity of
/// `CreationParams.backgroundColor` is less than 1.0. See
/// https://github.com/flutter/flutter/wiki/Hybrid-Composition for more
/// information.
class SurfaceAndroidWebView extends AndroidWebView {
  /// Constructs a [SurfaceAndroidWebView].
  SurfaceAndroidWebView({@visibleForTesting super.instanceManager});

  @override
  Widget build({
    required BuildContext context,
    required CreationParams creationParams,
    required JavascriptChannelRegistry javascriptChannelRegistry,
    WebViewPlatformCreatedCallback? onWebViewPlatformCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
    required WebViewPlatformCallbacksHandler webViewPlatformCallbacksHandler,
  }) {
    return WebViewAndroidWidget(
      creationParams: creationParams,
      callbacksHandler: webViewPlatformCallbacksHandler,
      javascriptChannelRegistry: javascriptChannelRegistry,
      onBuildWidget: (WebViewAndroidPlatformController controller) {
        return PlatformViewLink(
          viewType: 'plugins.flutter.io/webview',
          surfaceFactory: (
            BuildContext context,
            PlatformViewController controller,
          ) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: gestureRecognizers ??
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            final Color? backgroundColor = creationParams.backgroundColor;
            return _createViewController(
              // On some Android devices, transparent backgrounds can cause
              // rendering issues on the non hybrid composition
              // AndroidViewSurface. This switches the WebView to Hybrid
              // Composition when the background color is not 100% opaque.
              hybridComposition:
                  backgroundColor != null && backgroundColor.opacity < 1.0,
              id: params.id,
              viewType: 'plugins.flutter.io/webview',
              // WebView content is not affected by the Android view's layout direction,
              // we explicitly set it here so that the widget doesn't require an ambient
              // directionality.
              layoutDirection:
                  Directionality.maybeOf(context) ?? TextDirection.ltr,
              webViewIdentifier:
                  instanceManager.getIdentifier(controller.webView)!,
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..addOnPlatformViewCreatedListener((int id) {
                if (onWebViewPlatformCreated != null) {
                  onWebViewPlatformCreated(controller);
                }
              })
              ..create();
          },
        );
      },
    );
  }

  AndroidViewController _createViewController({
    required bool hybridComposition,
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    required int webViewIdentifier,
  }) {
    if (hybridComposition) {
      return PlatformViewsService.initExpensiveAndroidView(
        id: id,
        viewType: viewType,
        layoutDirection: layoutDirection,
        creationParams: webViewIdentifier,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return PlatformViewsService.initSurfaceAndroidView(
      id: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: webViewIdentifier,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
