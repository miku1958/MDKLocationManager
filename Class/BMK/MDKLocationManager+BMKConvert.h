//
//  MDKLocationManager+BMKConvert.h
//  MDKLocationManager
//
//  Created by mikun on 2018/5/7.
//  Copyright © 2018年 mdk. All rights reserved.
//
#if __has_include("MDKLocationManager.h")
#import "MDKLocationManager.h"
#else
#import <MDKLocationManager/MDKLocationManager.h>
#endif


#if __has_include(<BaiduMapAPI_Utils/BMKGeometry.h>)
#define canUseBaiduSDK 1
#endif

@interface MDKLocationManager (BMKConvert)
#ifdef canUseBaiduSDK
	/// 将原始GPS坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeGPSCoordinateToBaidu:(CLLocationCoordinate2D)coordinate;

	/// 将google坐标，51地图坐标，mapabc坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeCOMMONCoordinateToBaidu:(CLLocationCoordinate2D)coordinate;

	/// 将百度坐标转换为火星坐标
+ (CLLocationCoordinate2D)changeBaiduCoordinateToCOMMON:(CLLocationCoordinate2D)coordinate;
#endif
@end
