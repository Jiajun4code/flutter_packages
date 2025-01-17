# Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package io.flutter.plugins.webviewflutter;

import android.os.Build;
import android.view.View;
import android.webkit.ConsoleMessage;
import android.webkit.GeolocationPermissions;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugins.webviewflutter.GeneratedAndroidWebView.WebChromeClientFlutterApi;
import java.util.List;
import java.util.Objects;

/**
 * Flutter Api implementation for {@link WebChromeClient}.
 *
 * <p>Passes arguments of callbacks methods from a {@link WebChromeClient} to Dart.
 */
public class WebChromeClientFlutterApiImpl extends WebChromeClientFlutterApi {
  private final BinaryMessenger binaryMessenger;
  private final InstanceManager instanceManager;
  private final WebViewFlutterApiImpl webViewFlutterApi;

  private static GeneratedAndroidWebView.ConsoleMessageLevel toConsoleMessageLevel(
      ConsoleMessage.MessageLevel level) {
    switch (level) {
      case TIP:
        return GeneratedAndroidWebView.ConsoleMessageLevel.TIP;
      case LOG:
        return GeneratedAndroidWebView.ConsoleMessageLevel.LOG;
      case WARNING:
        return GeneratedAndroidWebView.ConsoleMessageLevel.WARNING;
      case ERROR:
        return GeneratedAndroidWebView.ConsoleMessageLevel.ERROR;
      case DEBUG:
        return GeneratedAndroidWebView.ConsoleMessageLevel.DEBUG;
    }

    return GeneratedAndroidWebView.ConsoleMessageLevel.UNKNOWN;
  }

  /**
   * Creates a Flutter api that sends messages to Dart.
   *
   * @param binaryMessenger handles sending messages to Dart
   * @param instanceManager maintains instances stored to communicate with Dart objects
   */
  public WebChromeClientFlutterApiImpl(
      @NonNull BinaryMessenger binaryMessenger, @NonNull InstanceManager instanceManager) {
    super(binaryMessenger);
    this.binaryMessenger = binaryMessenger;
    this.instanceManager = instanceManager;
    webViewFlutterApi = new WebViewFlutterApiImpl(binaryMessenger, instanceManager);
  }

  /** Passes arguments from {@link WebChromeClient#onProgressChanged} to Dart. */
  public void onProgressChanged(
      @NonNull WebChromeClient webChromeClient,
      @NonNull WebView webView,
      @NonNull Long progress,
      @NonNull Reply<Void> callback) {
    webViewFlutterApi.create(webView, reply -> {});

    final Long webViewIdentifier =
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(webView));
    super.onProgressChanged(
        getIdentifierForClient(webChromeClient), webViewIdentifier, progress, callback);
  }

  /** Passes arguments from {@link WebChromeClient#onShowFileChooser} to Dart. */
  @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
  public void onShowFileChooser(
      @NonNull WebChromeClient webChromeClient,
      @NonNull WebView webView,
      @NonNull WebChromeClient.FileChooserParams fileChooserParams,
      @NonNull Reply<List<String>> callback) {
    webViewFlutterApi.create(webView, reply -> {});

    new FileChooserParamsFlutterApiImpl(binaryMessenger, instanceManager)
        .create(fileChooserParams, reply -> {});

    onShowFileChooser(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(webChromeClient)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(webView)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(fileChooserParams)),
        callback);
  }

  /** Passes arguments from {@link WebChromeClient#onGeolocationPermissionsShowPrompt} to Dart. */
  public void onGeolocationPermissionsShowPrompt(
      @NonNull WebChromeClient webChromeClient,
      @NonNull String origin,
      @NonNull GeolocationPermissions.Callback callback,
      @NonNull WebChromeClientFlutterApi.Reply<Void> replyCallback) {
    new GeolocationPermissionsCallbackFlutterApiImpl(binaryMessenger, instanceManager)
        .create(callback, reply -> {});
    onGeolocationPermissionsShowPrompt(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(webChromeClient)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(callback)),
        origin,
        replyCallback);
  }

  /**
   * Sends a message to Dart to call `WebChromeClient.onGeolocationPermissionsHidePrompt` on the
   * Dart object representing `instance`.
   */
  public void onGeolocationPermissionsHidePrompt(
      @NonNull WebChromeClient instance, @NonNull WebChromeClientFlutterApi.Reply<Void> callback) {
    super.onGeolocationPermissionsHidePrompt(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(instance)),
        callback);
  }

  /**
   * Sends a message to Dart to call `WebChromeClient.onPermissionRequest` on the Dart object
   * representing `instance`.
   */
  @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
  public void onPermissionRequest(
      @NonNull WebChromeClient instance,
      @NonNull PermissionRequest request,
      @NonNull WebChromeClientFlutterApi.Reply<Void> callback) {
    new PermissionRequestFlutterApiImpl(binaryMessenger, instanceManager)
        .create(request, request.getResources(), reply -> {});

    super.onPermissionRequest(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(instance)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(request)),
        callback);
  }

  /**
   * Sends a message to Dart to call `WebChromeClient.onShowCustomView` on the Dart object
   * representing `instance`.
   */
  public void onShowCustomView(
      @NonNull WebChromeClient instance,
      @NonNull View view,
      @NonNull WebChromeClient.CustomViewCallback customViewCallback,
      @NonNull WebChromeClientFlutterApi.Reply<Void> callback) {
    new ViewFlutterApiImpl(binaryMessenger, instanceManager).create(view, reply -> {});
    new CustomViewCallbackFlutterApiImpl(binaryMessenger, instanceManager)
        .create(customViewCallback, reply -> {});

    onShowCustomView(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(instance)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(view)),
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(customViewCallback)),
        callback);
  }

  /**
   * Sends a message to Dart to call `WebChromeClient.onHideCustomView` on the Dart object
   * representing `instance`.
   */
  public void onHideCustomView(
      @NonNull WebChromeClient instance, @NonNull WebChromeClientFlutterApi.Reply<Void> callback) {
    super.onHideCustomView(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(instance)),
        callback);
  }

  /**
   * Sends a message to Dart to call `WebChromeClient.onConsoleMessage` on the Dart object
   * representing `instance`.
   */
  public void onConsoleMessage(
      @NonNull WebChromeClient instance,
      @NonNull ConsoleMessage message,
      @NonNull Reply<Void> callback) {
    super.onConsoleMessage(
        Objects.requireNonNull(instanceManager.getIdentifierForStrongReference(instance)),
        new GeneratedAndroidWebView.ConsoleMessage.Builder()
            .setLineNumber((long) message.lineNumber())
            .setMessage(message.message())
            .setLevel(toConsoleMessageLevel(message.messageLevel()))
            .setSourceId(message.sourceId())
            .build(),
        callback);
  }

  private long getIdentifierForClient(WebChromeClient webChromeClient) {
    final Long identifier = instanceManager.getIdentifierForStrongReference(webChromeClient);
    if (identifier == null) {
      throw new IllegalStateException("Could not find identifier for WebChromeClient.");
    }
    return identifier;
  }
}
