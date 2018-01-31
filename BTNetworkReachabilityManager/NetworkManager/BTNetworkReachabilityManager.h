//
//  BTNetworkReachabilityManager.h
//  NetworkManager
//
//  Created by roylee on 2017/11/24.
//  Copyright © 2017年 bantang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Reachability/Reachability.h>

typedef NS_ENUM(NSInteger, BTNetworkReachabilityStatus) {
    BTNetworkReachabilityStatusUnknow           = 0,
    BTNetworkReachabilityStatusNotReachable     = 1,
    BTNetworkReachabilityStatusReachableViaWWAN = 2,
    BTNetworkReachabilityStatusReachableViaWiFi = 3,
};

typedef NS_ENUM(NSInteger, BTNetworkReachabilityOption) {
    BTNetworkReachabilityOptionAll            = 0,
    BTNetworkReachabilityOptionOnlyReachable  = 1,
    BTNetworkReachabilityOptionReachableAgain = 2,
};


@interface BTNetworkReachabilityObserver : NSObject

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly) SEL action;
@property (nonatomic, readonly) void(^block)(BTNetworkReachabilityObserver *proxy, BTNetworkReachabilityStatus status);

@end



typedef void (^BTNetworkReachabilityStatusBlock)(BTNetworkReachabilityObserver *observer, BTNetworkReachabilityStatus status);

@interface BTNetworkReachabilityManager : NSObject {
    Reachability *_reachability;
}
@property (nonatomic, readonly) Reachability *reachability;

/**
 The current network reachability status.
 */
@property (nonatomic, readonly) BTNetworkReachabilityStatus networkReachabilityStatus;

/**
 Whether or not the network is currently reachable.
 */
@property (readonly, nonatomic, getter=isReachable) BOOL reachable;


///--------------------------------------------------
/// @name Init methods, do not use method `-init`.
///--------------------------------------------------

/**
 Returns the shared network reachability manager.
 */
+ (instancetype)sharedManager;

/**
 Creates and returns a network reachability manager with the default socket address.
 
 @return An initialized network reachability manager, actively monitoring the default socket address.
 */
+ (instancetype)manager;



///--------------------------------------------------
/// @name Starting & Stopping Reachability Monitoring
///--------------------------------------------------

/**
 Starts monitoring for changes in network reachability status.
 */
- (void)startNotifier;

/**
 Stops monitoring for changes in network reachability status.
 */
- (void)stopNotifier;



///--------------------------------------------------
/// @name Add & remove Reachability Monitoring
///--------------------------------------------------

/**
 Add an observer to receive the changed network reachability status.
 
 If you won't call the method `removeNetworkStatusChangedObserver:` to remove the observer from
 the notify quene, the observer will be removed automatic when the observer was dealloc.
 
 @param observer A instance for recive changed network status.
 @param block A block object to be executed when the network availability changes.. This block has no return value and takes a single argument which represents the various reachability states from the device. And if you want to use the observer instance in the block, you can use the param `proxy` of this block to get the observer isntance from its property `target`, otherwise it may be call a retain cycle.
 */
- (void)addNetworkStatusChangedObserver:(id)observer callBack:(BTNetworkReachabilityStatusBlock)block;

/**
 Add an observer to receive the changed network reachability status, same as above.
 
 @param option An option for config the receive action, more see `BTNetworkReachabilityOption`.
 @param observer A instance for recive changed network status.
 @param block Same as above.
 */
- (void)addNetworkStatusChangedObserver:(id)observer option:(BTNetworkReachabilityOption)option callBackBlock:(BTNetworkReachabilityStatusBlock)block;

/**
 Add an observer to receive the changed network reachability status, same as above.
 
 @param observer A instance for recive changed network status.
 @param selector A selector to be executed when the network availability changes.. This block has no return value and takes a single argument which represents the various reachability states from the device.
 */
- (void)addNetworkStatusChangedObserver:(id)observer option:(BTNetworkReachabilityOption)option callBackSelector:(SEL)selector;

/**
 Sets an callback to be executed when the network availability changes.
 
 @param block Same as above.
 */
- (void)setReachabilityStatusChangeBlock:(void(^)(BTNetworkReachabilityStatus status))block;

/**
 Remove an observer from the notfiy quene.
 
 @param observer An object to be removed.
 */
- (void)removeNetworkStatusChangedObserver:(id)observer;

@end
