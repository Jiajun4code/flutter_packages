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

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../common/instance_manager.dart';
import '../foundation/foundation.dart';
import '../web_kit/web_kit.dart';
import 'ui_kit_api_impls.dart';

/// A view that allows the scrolling and zooming of its contained views.
///
/// Wraps [UIScrollView](https://developer.apple.com/documentation/uikit/uiscrollview?language=objc).
@immutable
class UIScrollView extends UIView {
  /// Constructs a [UIScrollView] that is owned by [webView].
  factory UIScrollView.fromWebView(
    WKWebView webView, {
    BinaryMessenger? binaryMessenger,
    InstanceManager? instanceManager,
  }) {
    final UIScrollView scrollView = UIScrollView.detached(
      binaryMessenger: binaryMessenger,
      instanceManager: instanceManager,
    );
    scrollView._scrollViewApi.createFromWebViewForInstances(
      scrollView,
      webView,
    );
    return scrollView;
  }

  /// Constructs a [UIScrollView] without creating the associated
  /// Objective-C object.
  ///
  /// This should only be used by subclasses created by this library or to
  /// create copies.
  UIScrollView.detached({
    super.observeValue,
    super.binaryMessenger,
    super.instanceManager,
  })  : _scrollViewApi = UIScrollViewHostApiImpl(
          binaryMessenger: binaryMessenger,
          instanceManager: instanceManager,
        ),
        super.detached();

  final UIScrollViewHostApiImpl _scrollViewApi;

  /// Point at which the origin of the content view is offset from the origin of the scroll view.
  ///
  /// Represents [WKWebView.contentOffset](https://developer.apple.com/documentation/uikit/uiscrollview/1619404-contentoffset?language=objc).
  Future<Point<double>> getContentOffset() {
    return _scrollViewApi.getContentOffsetForInstances(this);
  }

  /// Move the scrolled position of this view.
  ///
  /// This method is not a part of UIKit and is only a helper method to make
  /// scrollBy atomic.
  Future<void> scrollBy(Point<double> offset) {
    return _scrollViewApi.scrollByForInstances(this, offset);
  }

  /// Set point at which the origin of the content view is offset from the origin of the scroll view.
  ///
  /// The default value is `Point<double>(0.0, 0.0)`.
  ///
  /// Sets [WKWebView.contentOffset](https://developer.apple.com/documentation/uikit/uiscrollview/1619404-contentoffset?language=objc).
  Future<void> setContentOffset(Point<double> offset) {
    return _scrollViewApi.setContentOffsetForInstances(this, offset);
  }

  @override
  UIScrollView copy() {
    return UIScrollView.detached(
      observeValue: observeValue,
      binaryMessenger: _viewApi.binaryMessenger,
      instanceManager: _viewApi.instanceManager,
    );
  }
}

/// Manages the content for a rectangular area on the screen.
///
/// Wraps [UIView](https://developer.apple.com/documentation/uikit/uiview?language=objc).
@immutable
class UIView extends NSObject {
  /// Constructs a [UIView] without creating the associated
  /// Objective-C object.
  ///
  /// This should only be used by subclasses created by this library or to
  /// create copies.
  UIView.detached({
    super.observeValue,
    super.binaryMessenger,
    super.instanceManager,
  })  : _viewApi = UIViewHostApiImpl(
          binaryMessenger: binaryMessenger,
          instanceManager: instanceManager,
        ),
        super.detached();

  final UIViewHostApiImpl _viewApi;

  /// The view’s background color.
  ///
  /// The default value is null, which results in a transparent background color.
  ///
  /// Sets [UIView.backgroundColor](https://developer.apple.com/documentation/uikit/uiview/1622591-backgroundcolor?language=objc).
  Future<void> setBackgroundColor(Color? color) {
    return _viewApi.setBackgroundColorForInstances(this, color);
  }

  /// Determines whether the view is opaque.
  ///
  /// Sets [UIView.opaque](https://developer.apple.com/documentation/uikit/uiview?language=objc).
  Future<void> setOpaque(bool opaque) {
    return _viewApi.setOpaqueForInstances(this, opaque);
  }

  @override
  UIView copy() {
    return UIView.detached(
      observeValue: observeValue,
      binaryMessenger: _viewApi.binaryMessenger,
      instanceManager: _viewApi.instanceManager,
    );
  }
}
