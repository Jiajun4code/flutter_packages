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

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class InstanceManagerTest {
  @Test
  public void addDartCreatedInstance() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    final Object object = new Object();
    instanceManager.addDartCreatedInstance(object, 0);

    assertEquals(object, instanceManager.getInstance(0));
    assertEquals((Long) 0L, instanceManager.getIdentifierForStrongReference(object));
    assertTrue(instanceManager.containsInstance(object));

    instanceManager.stopFinalizationListener();
  }

  @Test
  public void addHostCreatedInstance() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    final Object object = new Object();
    long identifier = instanceManager.addHostCreatedInstance(object);

    assertNotNull(instanceManager.getInstance(identifier));
    assertEquals(object, instanceManager.getInstance(identifier));
    assertTrue(instanceManager.containsInstance(object));

    instanceManager.stopFinalizationListener();
  }

  @Test
  public void remove() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    Object object = new Object();
    instanceManager.addDartCreatedInstance(object, 0);

    assertEquals(object, instanceManager.remove(0));

    // To allow for object to be garbage collected.
    //noinspection UnusedAssignment
    object = null;

    Runtime.getRuntime().gc();

    assertNull(instanceManager.getInstance(0));

    instanceManager.stopFinalizationListener();
  }

  @Test
  public void clear() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    final Object instance = new Object();

    instanceManager.addDartCreatedInstance(instance, 0);
    assertTrue(instanceManager.containsInstance(instance));

    instanceManager.clear();
    assertFalse(instanceManager.containsInstance(instance));

    instanceManager.stopFinalizationListener();
  }

  @Test
  public void canAddSameObjectWithAddDartCreatedInstance() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    final Object instance = new Object();

    instanceManager.addDartCreatedInstance(instance, 0);
    instanceManager.addDartCreatedInstance(instance, 1);

    assertTrue(instanceManager.containsInstance(instance));

    assertEquals(instanceManager.getInstance(0), instance);
    assertEquals(instanceManager.getInstance(1), instance);

    instanceManager.stopFinalizationListener();
  }

  @Test(expected = IllegalArgumentException.class)
  public void cannotAddSameObjectsWithAddHostCreatedInstance() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    final Object instance = new Object();

    instanceManager.addHostCreatedInstance(instance);
    instanceManager.addHostCreatedInstance(instance);

    instanceManager.stopFinalizationListener();
  }

  @Test(expected = IllegalArgumentException.class)
  public void cannotUseIdentifierLessThanZero() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    instanceManager.addDartCreatedInstance(new Object(), -1);

    instanceManager.stopFinalizationListener();
  }

  @Test(expected = IllegalArgumentException.class)
  public void identifiersMustBeUnique() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});

    instanceManager.addDartCreatedInstance(new Object(), 0);
    instanceManager.addDartCreatedInstance(new Object(), 0);

    instanceManager.stopFinalizationListener();
  }

  @Test
  public void managerIsUsableWhileListenerHasStopped() {
    final InstanceManager instanceManager = InstanceManager.create(identifier -> {});
    instanceManager.stopFinalizationListener();

    final Object instance = new Object();
    final long identifier = 0;

    instanceManager.addDartCreatedInstance(instance, identifier);
    assertEquals(instanceManager.getInstance(identifier), instance);
    assertEquals(instanceManager.getIdentifierForStrongReference(instance), (Long) identifier);
    assertTrue(instanceManager.containsInstance(instance));
  }
}
