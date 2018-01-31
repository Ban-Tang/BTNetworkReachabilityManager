//
//  BTNetworkReachabilityManager.m
//  NetworkManager
//
//  Created by roylee on 2017/11/24.
//  Copyright © 2017年 bantang. All rights reserved.
//

#import "BTNetworkReachabilityManager.h"
#import <objc/runtime.h>

static char kNetworkObserverProxy;

@interface BTNetworkReachabilityObserver ()

@property (nonatomic, assign) BTNetworkReachabilityStatus lastStatus;
@property (nonatomic, assign) BTNetworkReachabilityOption option;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) void(^block)(BTNetworkReachabilityObserver *observer, BTNetworkReachabilityStatus status);
@property (nonatomic, copy) void(^deallocBlock)(BTNetworkReachabilityObserver *observer);

@end

@implementation BTNetworkReachabilityObserver

- (instancetype)initWithTarget:(id)target networkStatus:(BTNetworkReachabilityStatus)status {
    self = [super init];
    if (self) {
        _target = target;
        _lastStatus = status;
    }
    return self;
}

- (void)dealloc {
    if (_deallocBlock) {
        _deallocBlock(self);
        _deallocBlock = nil;
    }
    _block = nil;
}
@end




@interface BTNetworkReachabilityManager () {
    NSMapTable *_networkObserversMap;
}
@property (nonatomic, readwrite, assign) BTNetworkReachabilityStatus networkReachabilityStatus;
@property (nonatomic, copy) void(^networkReachabilityStatusBlock)(BTNetworkReachabilityStatus status);

@end

@implementation BTNetworkReachabilityManager

BTNetworkReachabilityStatus BTTransformedNetworkStatus(NetworkStatus status) {
    return (BTNetworkReachabilityStatus)status;
}

NSString *NetworkObserverMapKey(BTNetworkReachabilityObserver *observer) {
    return [NSString stringWithFormat:@"network_%p",observer];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static BTNetworkReachabilityManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [self manager];
    });
    return manager;
}

+ (instancetype)manager {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    struct sockaddr_in6 address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
#else
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
#endif
    return [self managerForAddress:&address];
}

+ (instancetype)managerForAddress:(const void *)address {
    BTNetworkReachabilityManager *manager = [[BTNetworkReachabilityManager alloc] initWithReachability:[Reachability reachabilityWithAddress:(const struct sockaddr_in *)address]];
    return manager;
}

- (instancetype)initWithReachability:(Reachability *)reachability {
    self = [super init];
    if (self) {
        self.networkReachabilityStatus = BTNetworkReachabilityStatusUnknow;
        _reachability = reachability;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChanged:) name:kReachabilityChangedNotification object:nil];
    }
    return self;
}

- (NSMapTable *)lazyNetworkObserversMap {
    if (_networkObserversMap == nil) {
        _networkObserversMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
    }
    return _networkObserversMap;
}

#pragma mark -

- (BOOL)isReachable {
    return _reachability.currentReachabilityStatus != NotReachable;
}

- (void)addNetworkStatusChangedObserver:(id)observer callBack:(BTNetworkReachabilityStatusBlock)block {
    [self addNetworkStatusChangedObserver:observer option:0 callBackBlock:block];
}

- (void)addNetworkStatusChangedObserver:(id)observer option:(BTNetworkReachabilityOption)option callBackBlock:(BTNetworkReachabilityStatusBlock)block {
    [self addNetworkStatusChangedObserver:observer option:option callBack:block selector:NULL];
}

- (void)addNetworkStatusChangedObserver:(id)observer option:(BTNetworkReachabilityOption)option callBackSelector:(SEL)selector {
    [self addNetworkStatusChangedObserver:observer option:option callBack:nil selector:selector];
}

- (void)addNetworkStatusChangedObserver:(id)observer option:(BTNetworkReachabilityOption)option callBack:(BTNetworkReachabilityStatusBlock)block selector:(SEL)selector {
    NSParameterAssert(observer);
    NSParameterAssert(block);
    
    BTNetworkReachabilityObserver *proxy = objc_getAssociatedObject(observer, &kNetworkObserverProxy);
    if (proxy) {
        return;
    }
    
    proxy = [[BTNetworkReachabilityObserver alloc] initWithTarget:observer networkStatus:self.networkReachabilityStatus];
    proxy.option = option;
    proxy.block = block;
    proxy.action = selector;
    proxy.deallocBlock = ^(BTNetworkReachabilityObserver *_observer) {
        if (_observer && self) {
            [self->_networkObserversMap removeObjectForKey:NetworkObserverMapKey(_observer)];
            [self stopNotifierIfNeed];
        }
    };
    objc_setAssociatedObject(observer, &kNetworkObserverProxy, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.lazyNetworkObserversMap setObject:proxy forKey:NetworkObserverMapKey(proxy)];
    [self startNotifier];
}

- (void)setReachabilityStatusChangeBlock:(void(^)(BTNetworkReachabilityStatus status))block {
#if DEBUG
    if (_networkReachabilityStatusBlock) {
        NSLog(@"[ BTNetworkReachabilityManager ] The old net work reachability status change block will be reset");
    }
#endif
    self.networkReachabilityStatusBlock = block;
}

- (void)removeNetworkStatusChangedObserver:(id)observer {
    if (observer) {
        objc_setAssociatedObject(observer, &kNetworkObserverProxy, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)startNotifier {
    [_reachability startNotifier];
}

- (void)stopNotifier {
    [_reachability stopNotifier];
}

- (void)stopNotifierIfNeed {
    if ([_networkObserversMap count] == 0) {
        [_reachability stopNotifier];
    }
}

- (BTNetworkReachabilityStatus)networkReachabilityStatus {
    return BTTransformedNetworkStatus(_reachability.currentReachabilityStatus);
}

#pragma mark - Observer

- (void)networkStatusChanged:(NSNotification *)notification {
    Reachability *reachability = notification.object;
    // Filter the incorrect reachability.
    // Because some one may use the same notification key `kReachabilityChangedNotification`, so
    // the call back will be invoked at wrong time.
    if (reachability == nil) return;
    if (reachability != _reachability) return;
    
    BTNetworkReachabilityStatus status = BTTransformedNetworkStatus(reachability.currentReachabilityStatus);
    self.networkReachabilityStatus = status;
    
    if (_networkReachabilityStatusBlock) {
        _networkReachabilityStatusBlock(status);
    }
    
    for (BTNetworkReachabilityObserver *observer in _networkObserversMap.objectEnumerator.allObjects) {
        if (!observer.target) continue;
        
        switch (observer.option) {
            case BTNetworkReachabilityOptionOnlyReachable:
                if (status > 0) {
                    [self invokeCallBackToObserver:observer status:status];
                }
                break;
            case BTNetworkReachabilityOptionReachableAgain:
                if (observer.lastStatus <= 0 && status > 0) {
                    [self invokeCallBackToObserver:observer status:status];
                }
                break;
            case BTNetworkReachabilityOptionAll:
            default:
                [self invokeCallBackToObserver:observer status:status];
                break;
        }
        observer.lastStatus = status;
    }
}

- (void)invokeCallBackToObserver:(BTNetworkReachabilityObserver *)observer status:(BTNetworkReachabilityStatus)status {
    if (observer.action) {
        if ([observer.target respondsToSelector:observer.action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [observer.target performSelector:observer.action];
#pragma clang diagnostic pop
        }
    }else if (observer.block) {
        observer.block(observer, status);
    }
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"]) {
        return [NSSet setWithObject:@"networkReachabilityStatus"];
    }
    
    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end
