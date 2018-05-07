//
//  MDKLocationManager+BMKConvert.m
//  MDKLocationManager
//
//  Created by mikun on 2018/5/7.
//  Copyright © 2018年 mdk. All rights reserved.
//

#import "MDKLocationManager+BMKConvert.h"

@implementation MDKLocationManager (BMKConvert)
#ifdef canUseBaiduSDK
	//MARK:	以下代码来自http://blog.csdn.net/jiisd/article/details/48712473
	/// 将原始GPS坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeGPSCoordinateToBaidu:(CLLocationCoordinate2D)coordinate {
	NSDictionary *base64dic = BMKConvertBaiduCoorFrom(coordinate,BMK_COORDTYPE_GPS);
	CLLocationCoordinate2D coordinateOfBaidu = BMKCoorDictionaryDecode(base64dic);
	//    NSLog(@"x=%lf,y=%lf",coordinate.latitude,coordinate.longitude);
	//     NSLog(@"x=%lf,y=%lf",coordinateOfBaidu.latitude,coordinateOfBaidu.longitude);
	return coordinateOfBaidu;
}

	/// 将google坐标，51地图坐标，mapabc坐标转换为百度坐标
+ (CLLocationCoordinate2D)changeCOMMONCoordinateToBaidu:(CLLocationCoordinate2D)coordinate {
	NSDictionary *base64dic = BMKConvertBaiduCoorFrom(coordinate,BMK_COORDTYPE_COMMON);
	CLLocationCoordinate2D coordinateOfBaidu = BMKCoorDictionaryDecode(base64dic);
	//    NSLog(@"x=%lf,y=%lf",coordinate.latitude,coordinate.longitude);
	//     NSLog(@"x=%lf,y=%lf",coordinateOfBaidu.latitude,coordinateOfBaidu.longitude);
	return coordinateOfBaidu;
}

	/// 将百度坐标转换为火星坐标
+ (CLLocationCoordinate2D)changeBaiduCoordinateToCOMMON:(CLLocationCoordinate2D)coordinate {
	double PI = 3.14159265358979324 * 3000.0 / 180.0;
	double longitude = coordinate.longitude - 0.0065;
	double latitude = coordinate.latitude - 0.006;
	double parameter = sqrt(longitude * longitude + latitude * latitude) - 0.00002 * sin(latitude * PI);
	double theta = atan2(latitude, longitude) - 0.000003 * cos(longitude * PI);
	double COMMON_longitude = parameter * cos(theta);
	double COMMON_latitude = parameter * sin(theta);
	CLLocationCoordinate2D  COMMON_Coordinate = CLLocationCoordinate2DMake(COMMON_latitude, COMMON_longitude);
	return COMMON_Coordinate;
}

#endif
@end
