//
//  MDKLocationManager.h
//
//  Created by mikun on 2018/2/25.
//  Copyright © 2018年 MDK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#if __has_include(<BaiduMapAPI_Utils/BMKGeometry.h>)
#define canUseBaiduSDK 1
#endif

typedef NS_ENUM(NSInteger, MDKLocationKeepType) {
	MDKLocationKeepTypeAllways        =0,
	MDKLocationKeepTypeOnlyOnce        =1,
};

typedef void(^MDKLocationActionBlock)(CLLocation*location);


@interface MDKLocationManager : NSObject
///action(CLLocation)
+ (void)addTarget:(nullable id)target action:(SEL)action forType:(MDKLocationKeepType)type;
+ (void)addActionBlock:(MDKLocationActionBlock)action forType:(MDKLocationKeepType)type;
+ (void)startWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy;
+ (void)stop;
+ (void)requestAlwaysAuthorizationAndBackgroundUpdates:(BOOL)allowsBackgroundLocationUpdates;




#ifdef canUseBaiduSDK
/// 将原始GPS坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeGPSCoordinateToBaidu:(CLLocationCoordinate2D)coordinate;

/// 将google坐标，51地图坐标，mapabc坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeCOMMONCoordinateToBaidu:(CLLocationCoordinate2D)coordinate;

/// 将百度坐标转换为火星坐标
+ (CLLocationCoordinate2D)changeBaiduCoordinateToCOMMON:(CLLocationCoordinate2D)coordinate;
#endif
@end
