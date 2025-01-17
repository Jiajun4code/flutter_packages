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

import android.webkit.WebView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.engine.FlutterEngine;

/**
 * App and package facing native API provided by the `webview_flutter_android` plugin.
 *
 * <p>This class follows the convention of breaking changes of the Dart API, which means that any
 * changes to the class that are not backwards compatible will only be made with a major version
 * change of the plugin.
 *
 * <p>Native code other than this external API does not follow breaking change conventions, so app
 * or plugin clients should not use any other native APIs.
 */
@SuppressWarnings("unused")
public interface WebViewFlutterAndroidExternalApi {
  /**
   * Retrieves the {@link WebView} that is associated with `identifier`.
   *
   * <p>See the Dart method `AndroidWebViewController.webViewIdentifier` to get the identifier of an
   * underlying `WebView`.
   *
   * @param engine the execution environment the {@link WebViewFlutterPlugin} should belong to. If
   *     the engine doesn't contain an attached instance of {@link WebViewFlutterPlugin}, this
   *     method returns null.
   * @param identifier the associated identifier of the `WebView`.
   * @return the `WebView` associated with `identifier` or null if a `WebView` instance associated
   *     with `identifier` could not be found.
   */
  @Nullable
  static WebView getWebView(@NonNull FlutterEngine engine, long identifier) {
    final WebViewFlutterPlugin webViewPlugin =
        (WebViewFlutterPlugin) engine.getPlugins().get(WebViewFlutterPlugin.class);

    if (webViewPlugin != null && webViewPlugin.getInstanceManager() != null) {
      final Object instance = webViewPlugin.getInstanceManager().getInstance(identifier);
      if (instance instanceof WebView) {
        return (WebView) instance;
      }
    }

    return null;
  }
}
