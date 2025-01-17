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

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:webview_flutter_android/src/android_webview.dart';
import 'package:webview_flutter_android/src/instance_manager.dart';

import 'instance_manager_test.mocks.dart';
import 'test_android_webview.g.dart';

@GenerateMocks(<Type>[TestInstanceManagerHostApi])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstanceManager', () {
    test('addHostCreatedInstance', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);

      expect(instanceManager.getIdentifier(object), 0);
      expect(
        instanceManager.getInstanceWithWeakReference(0),
        object,
      );
    });

    test('addHostCreatedInstance prevents already used objects and ids', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);

      expect(
        () => instanceManager.addHostCreatedInstance(object, 0),
        throwsAssertionError,
      );

      expect(
        () => instanceManager.addHostCreatedInstance(CopyableObject(), 0),
        throwsAssertionError,
      );
    });

    test('addFlutterCreatedInstance', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addDartCreatedInstance(object);

      final int? instanceId = instanceManager.getIdentifier(object);
      expect(instanceId, isNotNull);
      expect(
        instanceManager.getInstanceWithWeakReference(instanceId!),
        object,
      );
    });

    test('removeWeakReference', () {
      final CopyableObject object = CopyableObject();

      int? weakInstanceId;
      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (int instanceId) {
        weakInstanceId = instanceId;
      });

      instanceManager.addHostCreatedInstance(object, 0);

      expect(instanceManager.removeWeakReference(object), 0);
      expect(
        instanceManager.getInstanceWithWeakReference(0),
        isA<CopyableObject>(),
      );
      expect(weakInstanceId, 0);
    });

    test('removeWeakReference removes only weak reference', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);

      expect(instanceManager.removeWeakReference(object), 0);
      final CopyableObject copy = instanceManager.getInstanceWithWeakReference(
        0,
      )!;
      expect(identical(object, copy), isFalse);
    });

    test('removeStrongReference', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);
      instanceManager.removeWeakReference(object);
      expect(instanceManager.remove(0), isA<CopyableObject>());
      expect(instanceManager.containsIdentifier(0), isFalse);
    });

    test('removeStrongReference removes only strong reference', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);
      expect(instanceManager.remove(0), isA<CopyableObject>());
      expect(
        instanceManager.getInstanceWithWeakReference(0),
        object,
      );
    });

    test('getInstance can add a new weak reference', () {
      final CopyableObject object = CopyableObject();

      final InstanceManager instanceManager =
          InstanceManager(onWeakReferenceRemoved: (_) {});

      instanceManager.addHostCreatedInstance(object, 0);
      instanceManager.removeWeakReference(object);

      final CopyableObject newWeakCopy =
          instanceManager.getInstanceWithWeakReference(
        0,
      )!;
      expect(identical(object, newWeakCopy), isFalse);
    });

    test('globalInstanceManager clears native `InstanceManager`', () {
      final MockTestInstanceManagerHostApi mockApi =
          MockTestInstanceManagerHostApi();
      TestInstanceManagerHostApi.setup(mockApi);

      // Calls method to clear the native InstanceManager.
      // ignore: unnecessary_statements
      JavaObject.globalInstanceManager;

      verify(mockApi.clear());

      TestInstanceManagerHostApi.setup(null);
    });
  });
}

class CopyableObject with Copyable {
  @override
  Copyable copy() {
    return CopyableObject();
  }
}
