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

// This test is run using `flutter drive` by the CI (see /script/tool/README.md
// in this repository for details on driving that tooling manually), but can
// also be run using `flutter test` directly during development.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter_android/src/android_webview.dart' as android;
import 'package:webview_flutter_android/src/android_webview.g.dart';
import 'package:webview_flutter_android/src/android_webview_api_impls.dart';
import 'package:webview_flutter_android/src/instance_manager.dart';
import 'package:webview_flutter_android/src/weak_reference_utils.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
  unawaited(server.forEach((HttpRequest request) {
    if (request.uri.path == '/hello.txt') {
      request.response.writeln('Hello, world.');
    } else if (request.uri.path == '/secondary.txt') {
      request.response.writeln('How are you today?');
    } else if (request.uri.path == '/headers') {
      request.response.writeln('${request.headers}');
    } else if (request.uri.path == '/favicon.ico') {
      request.response.statusCode = HttpStatus.notFound;
    } else if (request.uri.path == '/http-basic-authentication') {
      final bool isAuthenticating = request.headers['Authorization'] != null;
      if (isAuthenticating) {
        request.response.writeln('Authorized');
      } else {
        request.response.headers
            .add('WWW-Authenticate', 'Basic realm="Test realm"');
        request.response.statusCode = HttpStatus.unauthorized;
      }
    } else {
      fail('unexpected request: ${request.method} ${request.uri}');
    }
    request.response.close();
  }));
  final String prefixUrl = 'http://${server.address.address}:${server.port}';
  final String primaryUrl = '$prefixUrl/hello.txt';
  final String secondaryUrl = '$prefixUrl/secondary.txt';
  final String headersUrl = '$prefixUrl/headers';
  final String basicAuthUrl = '$prefixUrl/http-basic-authentication';

  testWidgets('loadRequest', (WidgetTester tester) async {
    final Completer<void> pageFinished = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageFinished.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));
    await controller.loadRequest(
      LoadRequestParams(uri: Uri.parse(primaryUrl)),
    );

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageFinished.future;

    final String? currentUrl = await controller.currentUrl();
    expect(currentUrl, primaryUrl);
  });

  testWidgets(
      'withWeakRefenceTo allows encapsulating class to be garbage collected',
      (WidgetTester tester) async {
    final Completer<int> gcCompleter = Completer<int>();
    final InstanceManager instanceManager = InstanceManager(
      onWeakReferenceRemoved: gcCompleter.complete,
    );

    ClassWithCallbackClass? instance = ClassWithCallbackClass();
    instanceManager.addHostCreatedInstance(instance.callbackClass, 0);
    instance = null;

    // Force garbage collection.
    await IntegrationTestWidgetsFlutterBinding.instance
        .watchPerformance(() async {
      await tester.pumpAndSettle();
    });

    final int gcIdentifier = await gcCompleter.future;
    expect(gcIdentifier, 0);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets(
    'WebView is released by garbage collection',
    (WidgetTester tester) async {
      final Completer<void> webViewGCCompleter = Completer<void>();

      late final InstanceManager instanceManager;
      instanceManager =
          InstanceManager(onWeakReferenceRemoved: (int identifier) {
        final Copyable instance =
            instanceManager.getInstanceWithWeakReference(identifier)!;
        if (instance is android.WebView && !webViewGCCompleter.isCompleted) {
          webViewGCCompleter.complete();
        }
      });

      // Since the InstanceManager of the apis are being changed, the native
      // InstanceManager needs to be cleared otherwise an exception will be
      // thrown that an identifier is being reused.
      await InstanceManagerHostApi().clear();

      android.WebView.api = WebViewHostApiImpl(
        instanceManager: instanceManager,
      );
      android.WebSettings.api =
          WebSettingsHostApiImpl(instanceManager: instanceManager);
      android.WebChromeClient.api = WebChromeClientHostApiImpl(
        instanceManager: instanceManager,
      );

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            return PlatformWebViewWidget(
              AndroidWebViewWidgetCreationParams(
                instanceManager: instanceManager,
                controller: PlatformWebViewController(
                  const PlatformWebViewControllerCreationParams(),
                ),
              ),
            ).build(context);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            return PlatformWebViewWidget(
              AndroidWebViewWidgetCreationParams(
                instanceManager: instanceManager,
                controller: PlatformWebViewController(
                  const PlatformWebViewControllerCreationParams(),
                ),
              ),
            ).build(context);
          },
        ),
      );
      await tester.pumpAndSettle();

      // Force garbage collection.
      await IntegrationTestWidgetsFlutterBinding.instance
          .watchPerformance(() async {
        await tester.pumpAndSettle();
      });

      await tester.pumpAndSettle();
      await expectLater(webViewGCCompleter.future, completes);

      android.WebView.api = WebViewHostApiImpl();
      android.WebSettings.api = WebSettingsHostApiImpl();
      android.WebChromeClient.api = WebChromeClientHostApiImpl();
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  testWidgets('runJavaScriptReturningResult', (WidgetTester tester) async {
    final Completer<void> pageFinished = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageFinished.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));
    await controller.loadRequest(LoadRequestParams(uri: Uri.parse(primaryUrl)));

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageFinished.future;

    await expectLater(
      controller.runJavaScriptReturningResult('1 + 1'),
      completion(2),
    );
  });

  testWidgets('loadRequest with headers', (WidgetTester tester) async {
    final Map<String, String> headers = <String, String>{
      'test_header': 'flutter_test_header'
    };

    final StreamController<String> pageLoads = StreamController<String>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((String url) => pageLoads.add(url)));
    unawaited(controller.setPlatformNavigationDelegate(delegate));
    await controller.loadRequest(
      LoadRequestParams(
        uri: Uri.parse(headersUrl),
        headers: headers,
      ),
    );

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageLoads.stream.firstWhere((String url) => url == headersUrl);

    final String content = await controller.runJavaScriptReturningResult(
      'document.documentElement.innerText',
    ) as String;
    expect(content.contains('flutter_test_header'), isTrue);
  });

  testWidgets('JavascriptChannel', (WidgetTester tester) async {
    final Completer<void> pageFinished = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageFinished.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));

    final Completer<String> channelCompleter = Completer<String>();
    await controller.addJavaScriptChannel(
      JavaScriptChannelParams(
        name: 'Echo',
        onMessageReceived: (JavaScriptMessage message) {
          channelCompleter.complete(message.message);
        },
      ),
    );

    await controller.loadHtmlString(
      'data:text/html;charset=utf-8;base64,PCFET0NUWVBFIGh0bWw+',
    );

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageFinished.future;

    await controller.runJavaScript('Echo.postMessage("hello");');
    await expectLater(channelCompleter.future, completion('hello'));
  });

  testWidgets('resize webview', (WidgetTester tester) async {
    final Completer<void> initialResizeCompleter = Completer<void>();
    final Completer<void> buttonTapResizeCompleter = Completer<void>();
    final Completer<void> onPageFinished = Completer<void>();

    bool resizeButtonTapped = false;
    await tester.pumpWidget(ResizableWebView(
      onResize: () {
        if (resizeButtonTapped) {
          buttonTapResizeCompleter.complete();
        } else {
          initialResizeCompleter.complete();
        }
      },
      onPageFinished: () => onPageFinished.complete(),
    ));

    await onPageFinished.future;
    // Wait for a potential call to resize after page is loaded.
    await initialResizeCompleter.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );

    resizeButtonTapped = true;

    await tester.tap(find.byKey(const ValueKey<String>('resizeButton')));
    await tester.pumpAndSettle();

    await expectLater(buttonTapResizeCompleter.future, completes);
  });

  testWidgets('set custom userAgent', (WidgetTester tester) async {
    final Completer<void> pageFinished = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(controller.setUserAgent('Custom_User_Agent1'));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageFinished.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));

    await controller
        .loadRequest(LoadRequestParams(uri: Uri.parse('about:blank')));

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageFinished.future;

    final String? customUserAgent = await controller.getUserAgent();
    expect(customUserAgent, 'Custom_User_Agent1');
  });

  group('Video playback policy', () {
    late String videoTestBase64;
    setUpAll(() async {
      final ByteData videoData =
          await rootBundle.load('assets/sample_video.mp4');
      final String base64VideoData =
          base64Encode(Uint8List.view(videoData.buffer));
      final String videoTest = '''
          <!DOCTYPE html><html>
          <head><title>Video auto play</title>
            <style>
              body,
              html,
              #container {
                  height: 100%;
                  width: 100%;
              }

              div {
                height: 50%;
                width: 100%;
              }
            </style>
            <script type="text/javascript">
              function play() {
                var video = document.getElementById("video");
                video.play();
                video.addEventListener('timeupdate', videoTimeUpdateHandler, false);
              }
              function videoTimeUpdateHandler(e) {
                var video = document.getElementById("video");
                VideoTestTime.postMessage(video.currentTime);
              }
              function isPaused() {
                var video = document.getElementById("video");
                return video.paused;
              }
              function isFullScreen() {
                var video = document.getElementById("video");
                return video.webkitDisplayingFullscreen;
              }
              function toggleFullScreen() {
                let elem = document.getElementById("video");

                if (!document.fullscreenElement) {
                  elem.requestFullscreen();
                } else {
                  document.exitFullscreen();
                }
              }
            </script>
          </head>
          <body onload="play();">
            <div onclick="toggleFullScreen();" style="background-color: aqua;"></div>
            <div>
              <video controls playsinline autoplay id="video" height="100%">
                <source src="data:video/mp4;charset=utf-8;base64,$base64VideoData">
              </video>
            </div>
          </body>
          </html>
        ''';
      videoTestBase64 = base64Encode(const Utf8Encoder().convert(videoTest));
    });

    testWidgets('Auto media playback', (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      AndroidWebViewController controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      unawaited(controller.setMediaPlaybackRequiresUserGesture(false));
      AndroidNavigationDelegate delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$videoTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      bool isPaused =
          await controller.runJavaScriptReturningResult('isPaused();') as bool;
      expect(isPaused, false);

      pageLoaded = Completer<void>();
      controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$videoTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      isPaused =
          await controller.runJavaScriptReturningResult('isPaused();') as bool;
      expect(isPaused, true);
    });

    testWidgets('Video plays inline', (WidgetTester tester) async {
      final Completer<void> pageLoaded = Completer<void>();
      final Completer<void> videoPlaying = Completer<void>();

      final AndroidWebViewController controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      unawaited(controller.setMediaPlaybackRequiresUserGesture(false));
      final AndroidNavigationDelegate delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      unawaited(controller.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'VideoTestTime',
          onMessageReceived: (JavaScriptMessage message) {
            final double currentTime = double.parse(message.message);
            // Let it play for at least 1 second to make sure the related video's properties are set.
            if (currentTime > 1 && !videoPlaying.isCompleted) {
              videoPlaying.complete(null);
            }
          },
        ),
      ));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$videoTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      // Makes sure we get the correct event that indicates the video is actually playing.
      await videoPlaying.future;

      final bool fullScreen = await controller
          .runJavaScriptReturningResult('isFullScreen();') as bool;
      expect(fullScreen, false);
    });

    testWidgets('Video plays fullscreen', (WidgetTester tester) async {
      final Completer<void> fullscreenEntered = Completer<void>();
      final Completer<void> fullscreenExited = Completer<void>();
      final Completer<void> pageLoaded = Completer<void>();

      final AndroidWebViewController controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      unawaited(controller.setMediaPlaybackRequiresUserGesture(false));
      final AndroidNavigationDelegate delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      unawaited(controller.setCustomWidgetCallbacks(onHideCustomWidget: () {
        fullscreenExited.complete();
      }, onShowCustomWidget:
          (Widget webView, void Function() onHideCustomView) {
        fullscreenEntered.complete();
        onHideCustomView();
      }));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$videoTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(
              key: const Key('webview_widget'),
              controller: controller,
            ),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      await tester.pumpAndSettle();

      // Due to security reasons, Chrome doesn't allow to programmatically
      // toggle a video to fullscreen unless the call is directly coming from
      // a user triggered event.
      // The top half of the loaded web content contains a clickable div, which
      // is tapped using the code below, triggering a user event.
      //
      // The offset of 20 x 20 is chosen at random.
      await tester.tapAt(const Offset(20, 20));

      await expectLater(fullscreenEntered.future, completes);
      await expectLater(fullscreenExited.future, completes);
    });
  });

  group('Audio playback policy', () {
    late String audioTestBase64;
    setUpAll(() async {
      final ByteData audioData =
          await rootBundle.load('assets/sample_audio.ogg');
      final String base64AudioData =
          base64Encode(Uint8List.view(audioData.buffer));
      final String audioTest = '''
        <!DOCTYPE html><html>
        <head><title>Audio auto play</title>
          <script type="text/javascript">
            function play() {
              var audio = document.getElementById("audio");
              audio.play();
            }
            function isPaused() {
              var audio = document.getElementById("audio");
              return audio.paused;
            }
          </script>
        </head>
        <body onload="play();">
        <audio controls id="audio">
          <source src="data:audio/ogg;charset=utf-8;base64,$base64AudioData">
        </audio>
        </body>
        </html>
      ''';
      audioTestBase64 = base64Encode(const Utf8Encoder().convert(audioTest));
    });

    testWidgets('Auto media playback', (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      AndroidWebViewController controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      unawaited(controller.setMediaPlaybackRequiresUserGesture(false));
      AndroidNavigationDelegate delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$audioTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      bool isPaused =
          await controller.runJavaScriptReturningResult('isPaused();') as bool;
      expect(isPaused, false);

      pageLoaded = Completer<void>();
      controller = AndroidWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      delegate = AndroidNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$audioTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      isPaused =
          await controller.runJavaScriptReturningResult('isPaused();') as bool;
      expect(isPaused, true);
    });
  });

  testWidgets('getTitle', (WidgetTester tester) async {
    const String getTitleTest = '''
        <!DOCTYPE html><html>
        <head><title>Some title</title>
        </head>
        <body>
        </body>
        </html>
      ''';
    final String getTitleTestBase64 =
        base64Encode(const Utf8Encoder().convert(getTitleTest));
    final Completer<void> pageLoaded = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));

    await controller.loadRequest(
      LoadRequestParams(
        uri: Uri.parse(
          'data:text/html;charset=utf-8;base64,$getTitleTestBase64',
        ),
      ),
    );

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await pageLoaded.future;

    // On at least iOS, it does not appear to be guaranteed that the native
    // code has the title when the page load completes. Execute some JavaScript
    // before checking the title to ensure that the page has been fully parsed
    // and processed.
    await controller.runJavaScript('1;');

    final String? title = await controller.getTitle();
    expect(title, 'Some title');
  });

  group('Programmatic Scroll', () {
    testWidgets('setAndGetScrollPosition', (WidgetTester tester) async {
      const String scrollTestPage = '''
        <!DOCTYPE html>
        <html>
          <head>
            <style>
              body {
                height: 100%;
                width: 100%;
              }
              #container{
                width:5000px;
                height:5000px;
            }
            </style>
          </head>
          <body>
            <div id="container"/>
          </body>
        </html>
      ''';

      final String scrollTestPageBase64 =
          base64Encode(const Utf8Encoder().convert(scrollTestPage));

      final Completer<void> pageLoaded = Completer<void>();
      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$scrollTestPageBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      await tester.pumpAndSettle(const Duration(seconds: 3));

      Offset scrollPos = await controller.getScrollPosition();

      // Check scrollTo()
      const int X_SCROLL = 123;
      const int Y_SCROLL = 321;
      // Get the initial position; this ensures that scrollTo is actually
      // changing something, but also gives the native view's scroll position
      // time to settle.
      expect(scrollPos.dx, isNot(X_SCROLL));
      expect(scrollPos.dy, isNot(Y_SCROLL));

      await controller.scrollTo(X_SCROLL, Y_SCROLL);
      scrollPos = await controller.getScrollPosition();
      expect(scrollPos.dx, X_SCROLL);
      expect(scrollPos.dy, Y_SCROLL);

      // Check scrollBy() (on top of scrollTo())
      await controller.scrollBy(X_SCROLL, Y_SCROLL);
      scrollPos = await controller.getScrollPosition();
      expect(scrollPos.dx, X_SCROLL * 2);
      expect(scrollPos.dy, Y_SCROLL * 2);
    });
  });

  group('NavigationDelegate', () {
    const String blankPage = '<!DOCTYPE html><head></head><body></body></html>';
    final String blankPageEncoded = 'data:text/html;charset=utf-8;base64,'
        '${base64Encode(const Utf8Encoder().convert(blankPage))}';

    testWidgets('can allow requests', (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(
        delegate.setOnNavigationRequest((NavigationRequest navigationRequest) {
          return (navigationRequest.url.contains('youtube.com'))
              ? NavigationDecision.prevent
              : NavigationDecision.navigate;
        }),
      );
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(uri: Uri.parse(blankPageEncoded)),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future; // Wait for initial page load.

      pageLoaded = Completer<void>();
      await controller.runJavaScript('location.href = "$secondaryUrl"');
      await pageLoaded.future; // Wait for the next page load.

      final String? currentUrl = await controller.currentUrl();
      expect(currentUrl, secondaryUrl);
    });

    testWidgets('onWebResourceError', (WidgetTester tester) async {
      final Completer<WebResourceError> errorCompleter =
          Completer<WebResourceError>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(
        delegate.setOnWebResourceError((WebResourceError error) {
          errorCompleter.complete(error);
        }),
      );
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller.loadRequest(
        LoadRequestParams(uri: Uri.parse('https://www.notawebsite..com')),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      final WebResourceError error = await errorCompleter.future;
      expect(error, isNotNull);

      expect(error.errorType, isNotNull);
      expect(
        error.url?.startsWith('https://www.notawebsite..com'),
        isTrue,
      );
    });

    testWidgets('onWebResourceError is not called with valid url',
        (WidgetTester tester) async {
      final Completer<WebResourceError> errorCompleter =
          Completer<WebResourceError>();
      final Completer<void> pageFinishCompleter = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(
        delegate.setOnPageFinished((_) => pageFinishCompleter.complete()),
      );
      unawaited(
        delegate.setOnWebResourceError((WebResourceError error) {
          errorCompleter.complete(error);
        }),
      );
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,PCFET0NUWVBFIGh0bWw+',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      expect(errorCompleter.future, doesNotComplete);
      await pageFinishCompleter.future;
    });

    testWidgets('can block requests', (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(delegate
          .setOnNavigationRequest((NavigationRequest navigationRequest) {
        return (navigationRequest.url.contains('youtube.com'))
            ? NavigationDecision.prevent
            : NavigationDecision.navigate;
      }));
      unawaited(controller.setPlatformNavigationDelegate(delegate));

      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(blankPageEncoded)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future; // Wait for initial page load.

      pageLoaded = Completer<void>();
      await controller
          .runJavaScript('location.href = "https://www.youtube.com/"');

      // There should never be any second page load, since our new URL is
      // blocked. Still wait for a potential page change for some time in order
      // to give the test a chance to fail.
      await pageLoaded.future
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      final String? currentUrl = await controller.currentUrl();
      expect(currentUrl, isNot(contains('youtube.com')));
    });

    testWidgets('supports asynchronous decisions', (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(delegate
          .setOnNavigationRequest((NavigationRequest navigationRequest) async {
        NavigationDecision decision = NavigationDecision.prevent;
        decision = await Future<NavigationDecision>.delayed(
            const Duration(milliseconds: 10),
            () => NavigationDecision.navigate);
        return decision;
      }));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(blankPageEncoded)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future; // Wait for initial page load.

      pageLoaded = Completer<void>();
      await controller.runJavaScript('location.href = "$secondaryUrl"');
      await pageLoaded.future; // Wait for second page to load.

      final String? currentUrl = await controller.currentUrl();
      expect(currentUrl, secondaryUrl);
    });

    testWidgets('can receive url changes', (WidgetTester tester) async {
      final Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(blankPageEncoded)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;
      await delegate.setOnPageFinished((_) {});

      final Completer<String> urlChangeCompleter = Completer<String>();
      await delegate.setOnUrlChange((UrlChange change) {
        urlChangeCompleter.complete(change.url);
      });

      await controller.runJavaScript('location.href = "$primaryUrl"');

      await expectLater(urlChangeCompleter.future, completion(primaryUrl));
    });

    testWidgets('can receive updates to history state',
        (WidgetTester tester) async {
      final Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(primaryUrl)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;
      await delegate.setOnPageFinished((_) {});

      final Completer<String> urlChangeCompleter = Completer<String>();
      await delegate.setOnUrlChange((UrlChange change) {
        urlChangeCompleter.complete(change.url);
      });

      await controller.runJavaScript(
        'window.history.pushState({}, "", "secondary.txt");',
      );

      await expectLater(urlChangeCompleter.future, completion(secondaryUrl));
    });
  });

  testWidgets('can receive HTTP basic auth requests',
      (WidgetTester tester) async {
    final Completer<void> authRequested = Completer<void>();
    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );

    final PlatformNavigationDelegate navigationDelegate =
        PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    await navigationDelegate.setOnHttpAuthRequest(
        (HttpAuthRequest request) => authRequested.complete());
    await controller.setPlatformNavigationDelegate(navigationDelegate);

    // Clear cache so that the auth request is always received and we don't get
    // a cached response.
    await controller.clearCache();

    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            AndroidWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ),
    );

    await controller.loadRequest(
      LoadRequestParams(uri: Uri.parse(basicAuthUrl)),
    );

    await expectLater(authRequested.future, completes);
  });

  testWidgets('can reply to HTTP basic auth requests',
      (WidgetTester tester) async {
    final Completer<void> pageFinished = Completer<void>();
    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );

    final PlatformNavigationDelegate navigationDelegate =
        PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    await navigationDelegate.setOnPageFinished((_) => pageFinished.complete());
    await navigationDelegate.setOnHttpAuthRequest(
      (HttpAuthRequest request) => request.onProceed(
        const WebViewCredential(user: 'user', password: 'password'),
      ),
    );
    await controller.setPlatformNavigationDelegate(navigationDelegate);

    // Clear cache so that the auth request is always received and we do not get
    // a cached response.
    await controller.clearCache();

    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            AndroidWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ),
    );

    await controller.loadRequest(
      LoadRequestParams(uri: Uri.parse(basicAuthUrl)),
    );

    await expectLater(pageFinished.future, completes);
  });

  testWidgets('target _blank opens in same window',
      (WidgetTester tester) async {
    final Completer<void> pageLoaded = Completer<void>();

    final PlatformWebViewController controller = PlatformWebViewController(
      const PlatformWebViewControllerCreationParams(),
    );
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
      const PlatformNavigationDelegateCreationParams(),
    );
    unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
    unawaited(controller.setPlatformNavigationDelegate(delegate));

    await tester.pumpWidget(Builder(
      builder: (BuildContext context) {
        return PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context);
      },
    ));

    await controller.runJavaScript('window.open("$primaryUrl", "_blank")');
    await pageLoaded.future;
    final String? currentUrl = await controller.currentUrl();
    expect(currentUrl, primaryUrl);
  });

  testWidgets(
    'can open new window and go back',
    (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(primaryUrl)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      expect(controller.currentUrl(), completion(primaryUrl));
      await pageLoaded.future;
      pageLoaded = Completer<void>();

      await controller.runJavaScript('window.open("$secondaryUrl")');
      await pageLoaded.future;
      pageLoaded = Completer<void>();
      expect(controller.currentUrl(), completion(secondaryUrl));

      expect(controller.canGoBack(), completion(true));
      await controller.goBack();
      await pageLoaded.future;
      await expectLater(controller.currentUrl(), completion(primaryUrl));
    },
  );

  testWidgets(
    'JavaScript does not run in parent window',
    (WidgetTester tester) async {
      const String iframe = '''
        <!DOCTYPE html>
        <script>
          window.onload = () => {
            window.open(`javascript:
              var elem = document.createElement("p");
              elem.innerHTML = "<b>Executed JS in parent origin: " + window.location.origin + "</b>";
              document.body.append(elem);
            `);
          };
        </script>
      ''';
      final String iframeTestBase64 =
          base64Encode(const Utf8Encoder().convert(iframe));

      final String openWindowTest = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>XSS test</title>
        </head>
        <body>
          <iframe
            onload="window.iframeLoaded = true;"
            src="data:text/html;charset=utf-8;base64,$iframeTestBase64"></iframe>
        </body>
        </html>
      ''';
      final String openWindowTestBase64 =
          base64Encode(const Utf8Encoder().convert(openWindowTest));

      final Completer<void> pageLoadCompleter = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(
          delegate.setOnPageFinished((_) => pageLoadCompleter.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller.loadRequest(
        LoadRequestParams(
          uri: Uri.parse(
            'data:text/html;charset=utf-8;base64,$openWindowTestBase64',
          ),
        ),
      );

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoadCompleter.future;

      final bool iframeLoaded =
          await controller.runJavaScriptReturningResult('iframeLoaded') as bool;
      expect(iframeLoaded, true);

      final String elementText = await controller.runJavaScriptReturningResult(
        'document.querySelector("p") && document.querySelector("p").textContent',
      ) as String;
      expect(elementText, 'null');
    },
  );

  testWidgets(
    '`AndroidWebViewController` can be reused with a new `AndroidWebViewWidget`',
    (WidgetTester tester) async {
      Completer<void> pageLoaded = Completer<void>();

      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      final PlatformNavigationDelegate delegate = PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      );
      unawaited(delegate.setOnPageFinished((_) => pageLoaded.complete()));
      unawaited(controller.setPlatformNavigationDelegate(delegate));
      await controller
          .loadRequest(LoadRequestParams(uri: Uri.parse(primaryUrl)));

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await pageLoaded.future;

      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      pageLoaded = Completer<void>();
      await controller.loadRequest(
        LoadRequestParams(uri: Uri.parse(primaryUrl)),
      );
      await expectLater(
        pageLoaded.future,
        completes,
      );
    },
  );

  group('Logging', () {
    testWidgets('can receive console log messages',
        (WidgetTester tester) async {
      const String testPage = '''
          <!DOCTYPE html>
          <html>
          <head>
            <title>WebResourceError test</title>
          </head>
          <body onload="console.debug('Debug message')">
            <p>Test page</p>
          </body>
          </html>
         ''';

      final Completer<String> debugMessageReceived = Completer<String>();
      final PlatformWebViewController controller = PlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));

      await controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugMessageReceived
            .complete('${message.level.name}:${message.message}');
      });

      await controller.loadHtmlString(testPage);

      await tester.pumpWidget(Builder(
        builder: (BuildContext context) {
          return PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(controller: controller),
          ).build(context);
        },
      ));

      await expectLater(
          debugMessageReceived.future, completion('debug:Debug message'));
    });
  });
}

class ResizableWebView extends StatefulWidget {
  const ResizableWebView({
    super.key,
    required this.onResize,
    required this.onPageFinished,
  });

  final VoidCallback onResize;
  final VoidCallback onPageFinished;

  @override
  State<StatefulWidget> createState() => ResizableWebViewState();
}

class ResizableWebViewState extends State<ResizableWebView> {
  late final PlatformWebViewController controller = PlatformWebViewController(
    const PlatformWebViewControllerCreationParams(),
  )
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setPlatformNavigationDelegate(
      PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      )..setOnPageFinished((_) => widget.onPageFinished()),
    )
    ..addJavaScriptChannel(
      JavaScriptChannelParams(
        name: 'Resize',
        onMessageReceived: (_) {
          widget.onResize();
        },
      ),
    )
    ..loadRequest(
      LoadRequestParams(
        uri: Uri.parse(
          'data:text/html;charset=utf-8;base64,${base64Encode(const Utf8Encoder().convert(resizePage))}',
        ),
      ),
    );

  double webViewWidth = 200;
  double webViewHeight = 200;

  static const String resizePage = '''
        <!DOCTYPE html><html>
        <head><title>Resize test</title>
          <script type="text/javascript">
            function onResize() {
              Resize.postMessage("resize");
            }
            function onLoad() {
              window.onresize = onResize;
            }
          </script>
        </head>
        <body onload="onLoad();" bgColor="blue">
        </body>
        </html>
      ''';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: <Widget>[
          SizedBox(
            width: webViewWidth,
            height: webViewHeight,
            child: PlatformWebViewWidget(
              PlatformWebViewWidgetCreationParams(controller: controller),
            ).build(context),
          ),
          TextButton(
            key: const Key('resizeButton'),
            onPressed: () {
              setState(() {
                webViewWidth += 100.0;
                webViewHeight += 100.0;
              });
            },
            child: const Text('ResizeButton'),
          ),
        ],
      ),
    );
  }
}

class CopyableObjectWithCallback with Copyable {
  CopyableObjectWithCallback(this.callback);

  final VoidCallback callback;

  @override
  CopyableObjectWithCallback copy() {
    return CopyableObjectWithCallback(callback);
  }
}

class ClassWithCallbackClass {
  ClassWithCallbackClass() {
    callbackClass = CopyableObjectWithCallback(
      withWeakReferenceTo(
        this,
        (WeakReference<ClassWithCallbackClass> weakReference) {
          return () {
            // Weak reference to `this` in callback.
            // ignore: unnecessary_statements
            weakReference;
          };
        },
      ),
    );
  }

  late final CopyableObjectWithCallback callbackClass;
}
