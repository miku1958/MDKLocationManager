//
//  MDKLocationManager.h
//
//  Created by mikun on 2018/2/25.
//  Copyright © 2018年 MDK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>



typedef NS_ENUM(NSInteger, MDKLocationKeepType) {
	MDKLocationKeepTypeAllways        =0,
	MDKLocationKeepTypeOnlyOnce        =1,
};

typedef void(^MDKLocationActionBlock)(CLLocation* _Nonnull location);


@interface MDKLocationManager : NSObject
///action(CLLocation)
+ (void)addTarget:(nullable id)target action:(SEL _Nonnull )action forType:(MDKLocationKeepType)type;
+ (void)addActionBlock:(MDKLocationActionBlock _Nullable )action forType:(MDKLocationKeepType)type;
+ (void)startWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy;
+ (void)stop;
+ (void)requestAlwaysAuthorizationAndBackgroundUpdates:(BOOL)allowsBackgroundLocationUpdates;





@end
