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

@import Flutter;
@import XCTest;
@import webview_flutter_wkwebview;

#import <OCMock/OCMock.h>

@interface FWFNavigationDelegateHostApiTests : XCTestCase
@end

@implementation FWFNavigationDelegateHostApiTests
/**
 * Creates a partially mocked FWFNavigationDelegate and adds it to instanceManager.
 *
 * @param instanceManager Instance manager to add the delegate to.
 * @param identifier Identifier for the delegate added to the instanceManager.
 *
 * @return A mock FWFNavigationDelegate.
 */
- (id)mockNavigationDelegateWithManager:(FWFInstanceManager *)instanceManager
                             identifier:(long)identifier {
  FWFNavigationDelegate *navigationDelegate = [[FWFNavigationDelegate alloc]
      initWithBinaryMessenger:OCMProtocolMock(@protocol(FlutterBinaryMessenger))
              instanceManager:instanceManager];

  [instanceManager addDartCreatedInstance:navigationDelegate withIdentifier:0];
  return OCMPartialMock(navigationDelegate);
}

/**
 * Creates a  mock FWFNavigationDelegateFlutterApiImpl with instanceManager.
 *
 * @param instanceManager Instance manager passed to the Flutter API.
 *
 * @return A mock FWFNavigationDelegateFlutterApiImpl.
 */
- (id)mockFlutterApiWithManager:(FWFInstanceManager *)instanceManager {
  FWFNavigationDelegateFlutterApiImpl *flutterAPI = [[FWFNavigationDelegateFlutterApiImpl alloc]
      initWithBinaryMessenger:OCMProtocolMock(@protocol(FlutterBinaryMessenger))
              instanceManager:instanceManager];
  return OCMPartialMock(flutterAPI);
}

- (void)testCreateWithIdentifier {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];
  FWFNavigationDelegateHostApiImpl *hostAPI = [[FWFNavigationDelegateHostApiImpl alloc]
      initWithBinaryMessenger:OCMProtocolMock(@protocol(FlutterBinaryMessenger))
              instanceManager:instanceManager];

  FlutterError *error;
  [hostAPI createWithIdentifier:0 error:&error];
  FWFNavigationDelegate *navigationDelegate =
      (FWFNavigationDelegate *)[instanceManager instanceForIdentifier:0];

  XCTAssertTrue([navigationDelegate conformsToProtocol:@protocol(WKNavigationDelegate)]);
  XCTAssertNil(error);
}

- (void)testDidFinishNavigation {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  OCMStub([mockWebView URL]).andReturn([NSURL URLWithString:@"https://flutter.dev/"]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  [mockDelegate webView:mockWebView didFinishNavigation:OCMClassMock([WKNavigation class])];
  OCMVerify([mockFlutterAPI didFinishNavigationForDelegateWithIdentifier:0
                                                       webViewIdentifier:1
                                                                     URL:@"https://flutter.dev/"
                                                              completion:OCMOCK_ANY]);
}

- (void)testDidStartProvisionalNavigation {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  OCMStub([mockWebView URL]).andReturn([NSURL URLWithString:@"https://flutter.dev/"]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  [mockDelegate webView:mockWebView
      didStartProvisionalNavigation:OCMClassMock([WKNavigation class])];
  OCMVerify([mockFlutterAPI
      didStartProvisionalNavigationForDelegateWithIdentifier:0
                                           webViewIdentifier:1
                                                         URL:@"https://flutter.dev/"
                                                  completion:OCMOCK_ANY]);
}

- (void)testDecidePolicyForNavigationAction {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  WKNavigationAction *mockNavigationAction = OCMClassMock([WKNavigationAction class]);
  OCMStub([mockNavigationAction request])
      .andReturn([NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.flutter.dev"]]);

  WKFrameInfo *mockFrameInfo = OCMClassMock([WKFrameInfo class]);
  OCMStub([mockFrameInfo isMainFrame]).andReturn(YES);
  OCMStub([mockNavigationAction targetFrame]).andReturn(mockFrameInfo);

  OCMStub([mockFlutterAPI
      decidePolicyForNavigationActionForDelegateWithIdentifier:0
                                             webViewIdentifier:1
                                              navigationAction:
                                                  [OCMArg isKindOfClass:[FWFWKNavigationActionData
                                                                            class]]
                                                    completion:
                                                        ([OCMArg
                                                            invokeBlockWithArgs:
                                                                [FWFWKNavigationActionPolicyEnumData
                                                                    makeWithValue:
                                                                        FWFWKNavigationActionPolicyEnumCancel],
                                                                [NSNull null], nil])]);

  WKNavigationActionPolicy __block callbackPolicy = -1;
  [mockDelegate webView:mockWebView
      decidePolicyForNavigationAction:mockNavigationAction
                      decisionHandler:^(WKNavigationActionPolicy policy) {
                        callbackPolicy = policy;
                      }];
  XCTAssertEqual(callbackPolicy, WKNavigationActionPolicyCancel);
}

- (void)testDidFailNavigation {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  [mockDelegate webView:mockWebView
      didFailNavigation:OCMClassMock([WKNavigation class])
              withError:[NSError errorWithDomain:@"domain" code:0 userInfo:nil]];
  OCMVerify([mockFlutterAPI
      didFailNavigationForDelegateWithIdentifier:0
                               webViewIdentifier:1
                                           error:[OCMArg isKindOfClass:[FWFNSErrorData class]]
                                      completion:OCMOCK_ANY]);
}

- (void)testDidFailProvisionalNavigation {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  [mockDelegate webView:mockWebView
      didFailProvisionalNavigation:OCMClassMock([WKNavigation class])
                         withError:[NSError errorWithDomain:@"domain" code:0 userInfo:nil]];
  OCMVerify([mockFlutterAPI
      didFailProvisionalNavigationForDelegateWithIdentifier:0
                                          webViewIdentifier:1
                                                      error:[OCMArg isKindOfClass:[FWFNSErrorData
                                                                                      class]]
                                                 completion:OCMOCK_ANY]);
}

- (void)testWebViewWebContentProcessDidTerminate {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  [mockDelegate webViewWebContentProcessDidTerminate:mockWebView];
  OCMVerify([mockFlutterAPI
      webViewWebContentProcessDidTerminateForDelegateWithIdentifier:0
                                                  webViewIdentifier:1
                                                         completion:OCMOCK_ANY]);
}

- (void)testDidReceiveAuthenticationChallenge {
  FWFInstanceManager *instanceManager = [[FWFInstanceManager alloc] init];

  FWFNavigationDelegate *mockDelegate = [self mockNavigationDelegateWithManager:instanceManager
                                                                     identifier:0];
  FWFNavigationDelegateFlutterApiImpl *mockFlutterAPI =
      [self mockFlutterApiWithManager:instanceManager];

  OCMStub([mockDelegate navigationDelegateAPI]).andReturn(mockFlutterAPI);

  WKWebView *mockWebView = OCMClassMock([WKWebView class]);
  [instanceManager addDartCreatedInstance:mockWebView withIdentifier:1];

  NSURLAuthenticationChallenge *mockChallenge = OCMClassMock([NSURLAuthenticationChallenge class]);
  NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:@"host"
                                                                                port:0
                                                                            protocol:nil
                                                                               realm:@"realm"
                                                                authenticationMethod:nil];
  OCMStub([mockChallenge protectionSpace]).andReturn(protectionSpace);
  [instanceManager addDartCreatedInstance:mockChallenge withIdentifier:2];

  NSURLCredential *credential = [NSURLCredential credentialWithUser:@"user"
                                                           password:@"password"
                                                        persistence:NSURLCredentialPersistenceNone];
  [instanceManager addDartCreatedInstance:credential withIdentifier:5];

  OCMStub([mockFlutterAPI
      didReceiveAuthenticationChallengeForDelegateWithIdentifier:0
                                               webViewIdentifier:1
                                             challengeIdentifier:2
                                                      completion:
                                                          ([OCMArg
                                                              invokeBlockWithArgs:
                                                                  [FWFAuthenticationChallengeResponse
                                                                       makeWithDisposition:
                                                                           FWFNSUrlSessionAuthChallengeDispositionCancelAuthenticationChallenge
                                                                      credentialIdentifier:@(5)],
                                                                  [NSNull null], nil])]);

  NSURLSessionAuthChallengeDisposition __block callbackDisposition = -1;
  NSURLCredential *__block callbackCredential;
  [mockDelegate webView:mockWebView
      didReceiveAuthenticationChallenge:mockChallenge
                      completionHandler:^(NSURLSessionAuthChallengeDisposition disposition,
                                          NSURLCredential *credential) {
                        callbackDisposition = disposition;
                        callbackCredential = credential;
                      }];

  XCTAssertEqual(callbackDisposition, NSURLSessionAuthChallengeCancelAuthenticationChallenge);
  XCTAssertEqualObjects(callbackCredential, credential);
}
@end
