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

#import "FWFObjectHostApi.h"
#import <objc/runtime.h>
#import "FWFDataConverters.h"
#import "FWFURLHostApi.h"

@interface FWFObjectFlutterApiImpl ()
// BinaryMessenger must be weak to prevent a circular reference with the host API it
// references.
@property(nonatomic, weak) id<FlutterBinaryMessenger> binaryMessenger;
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFObjectFlutterApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self initWithBinaryMessenger:binaryMessenger];
  if (self) {
    _binaryMessenger = binaryMessenger;
    _instanceManager = instanceManager;
  }
  return self;
}

- (long)identifierForObject:(NSObject *)instance {
  return [self.instanceManager identifierWithStrongReferenceForInstance:instance];
}

- (void)observeValueForObject:(NSObject *)instance
                      keyPath:(NSString *)keyPath
                       object:(NSObject *)object
                       change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                   completion:(void (^)(FlutterError *_Nullable))completion {
  NSMutableArray<FWFNSKeyValueChangeKeyEnumData *> *changeKeys = [NSMutableArray array];
  NSMutableArray<id> *changeValues = [NSMutableArray array];

  [change enumerateKeysAndObjectsUsingBlock:^(NSKeyValueChangeKey key, id value, BOOL *stop) {
    [changeKeys addObject:FWFNSKeyValueChangeKeyEnumDataFromNativeNSKeyValueChangeKey(key)];
    BOOL isIdentifier = NO;
    if ([self.instanceManager containsInstance:value]) {
      isIdentifier = YES;
    } else if (object_getClass(value) == [NSURL class]) {
      FWFURLFlutterApiImpl *flutterApi =
          [[FWFURLFlutterApiImpl alloc] initWithBinaryMessenger:self.binaryMessenger
                                                instanceManager:self.instanceManager];
      [flutterApi create:value
              completion:^(FlutterError *error) {
                NSAssert(!error, @"%@", error);
              }];
      isIdentifier = YES;
    }

    id returnValue = isIdentifier
                         ? @([self.instanceManager identifierWithStrongReferenceForInstance:value])
                         : value;
    [changeValues addObject:[FWFObjectOrIdentifier makeWithValue:returnValue
                                                    isIdentifier:isIdentifier]];
  }];

  NSInteger objectIdentifier =
      [self.instanceManager identifierWithStrongReferenceForInstance:object];
  [self observeValueForObjectWithIdentifier:[self identifierForObject:instance]
                                    keyPath:keyPath
                           objectIdentifier:objectIdentifier
                                 changeKeys:changeKeys
                               changeValues:changeValues
                                 completion:completion];
}
@end

@implementation FWFObject
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _objectApi = [[FWFObjectFlutterApiImpl alloc] initWithBinaryMessenger:binaryMessenger
                                                          instanceManager:instanceManager];
  }
  return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  [self.objectApi observeValueForObject:self
                                keyPath:keyPath
                                 object:object
                                 change:change
                             completion:^(FlutterError *error) {
                               NSAssert(!error, @"%@", error);
                             }];
}
@end

@interface FWFObjectHostApiImpl ()
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFObjectHostApiImpl
- (instancetype)initWithInstanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _instanceManager = instanceManager;
  }
  return self;
}

- (NSObject *)objectForIdentifier:(NSInteger)identifier {
  return (NSObject *)[self.instanceManager instanceForIdentifier:identifier];
}

- (void)addObserverForObjectWithIdentifier:(NSInteger)identifier
                        observerIdentifier:(NSInteger)observer
                                   keyPath:(nonnull NSString *)keyPath
                                   options:
                                       (nonnull NSArray<FWFNSKeyValueObservingOptionsEnumData *> *)
                                           options
                                     error:(FlutterError *_Nullable *_Nonnull)error {
  NSKeyValueObservingOptions optionsInt = 0;
  for (FWFNSKeyValueObservingOptionsEnumData *data in options) {
    optionsInt |= FWFNativeNSKeyValueObservingOptionsFromEnumData(data);
  }
  [[self objectForIdentifier:identifier] addObserver:[self objectForIdentifier:observer]
                                          forKeyPath:keyPath
                                             options:optionsInt
                                             context:nil];
}

- (void)removeObserverForObjectWithIdentifier:(NSInteger)identifier
                           observerIdentifier:(NSInteger)observer
                                      keyPath:(nonnull NSString *)keyPath
                                        error:(FlutterError *_Nullable *_Nonnull)error {
  [[self objectForIdentifier:identifier] removeObserver:[self objectForIdentifier:observer]
                                             forKeyPath:keyPath];
}

- (void)disposeObjectWithIdentifier:(NSInteger)identifier
                              error:(FlutterError *_Nullable *_Nonnull)error {
  [self.instanceManager removeInstanceWithIdentifier:identifier];
}
@end
