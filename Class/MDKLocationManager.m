//
//  MDKLocationManager.m
//
//  Created by mikun on 2018/2/25.
//  Copyright © 2018年 MDK. All rights reserved.
//

#import "MDKLocationManager.h"
#if __has_include(<BaiduMapAPI_Utils/BMKGeometry.h>)
#import <BaiduMapAPI_Utils/BMKGeometry.h>
#endif
#import "MDKTenOpenTool.h"

NSString * const MDKLocationManagerNeverShowAlert = @"BCLocationManagerNeverShowAlert";

typedef NSDictionary<id(^)(void) , SEL(^)(void)> MDKLocTargetActDic;
typedef NSMutableSet<MDKLocTargetActDic*> MDKLocTargetActSet;

@interface MDKLocationManager()<CLLocationManagerDelegate>
@property (nonatomic,strong)CLLocationManager *locManager;



@property (nonatomic,strong)CLLocation *currentLocation;
@property (nonatomic,strong)NSMutableDictionary<NSNumber *, MDKLocTargetActSet *> *type_targetActionDic;
@end

@implementation MDKLocationManager

+ (MDKLocationManager *)share{
	static MDKLocationManager *strongInstance ;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		strongInstance = [[self alloc] init];
		strongInstance.type_targetActionDic = @{}.mutableCopy;
	});
	return strongInstance;
}
+ (void)requestAlwaysAuthorizationAndBackgroundUpdates:(BOOL)allowsBackgroundLocationUpdates{
	[self.share.locManager requestAlwaysAuthorization];
	if (UIDevice.currentDevice.systemVersion.doubleValue >9.0) {
		self.share.locManager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates;
	}
}


+ (void)startWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self startWithDesiredAccuracy_inMainQ:desiredAccuracy];//回到主线程做这件事
	});
}
+ (void)startWithDesiredAccuracy_inMainQ:(CLLocationAccuracy)desiredAccuracy{



	if (!self.share.locManager) {
		self.share.locManager = [[CLLocationManager alloc]init];
		self.share.locManager.delegate = self.share;
		self.share.locManager.distanceFilter = 10;
	}
	
	if (![CLLocationManager locationServicesEnabled]) {
		[self locationServicesDisableMsg];
		return;
	}
	
	CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
	switch (status) {
		case kCLAuthorizationStatusDenied:
			[self showDeniedMsg];
			return;
		case kCLAuthorizationStatusNotDetermined:
		case kCLAuthorizationStatusRestricted:
			[self.share.locManager requestWhenInUseAuthorization];
			break;
		default:
			break;
	}
	if (self.share.locManager.desiredAccuracy <= desiredAccuracy) {
		if (self.share.currentLocation) {
			[self.share locationManager:self.share.locManager didUpdateLocations:@[self.share.currentLocation]];
			if (!self.share.type_targetActionDic[@(MDKLocationKeepTypeAllways)].count) {
				return;
			}
		}
	}

	if (self.share.getTargetCount<=1) {//没有多余的触发对象,
		[self.share.locManager setDesiredAccuracy:desiredAccuracy];
	}else if(desiredAccuracy<self.share.locManager.desiredAccuracy){//有多个触发器,可以提升精度
		[self.share.locManager setDesiredAccuracy:desiredAccuracy];
	}
	[self.share.locManager startUpdatingLocation];

}
- (NSInteger)getTargetCount{
	__block NSInteger count = 0;
	[_type_targetActionDic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, MDKLocTargetActSet * obj, BOOL *stop) {
		count += obj.count;
	}];
	return count;
}

+ (void)stop{
	[self.share.locManager stopUpdatingLocation];
}
+ (void)addTarget:(nullable id)target action:(SEL)action forType:(MDKLocationKeepType)type{
	if (!target || !action) { return; }
	__block BOOL cancel = NO;

	[self.share.type_targetActionDic[@(type)] enumerateObjectsUsingBlock:^(NSDictionary<id (^)(void),SEL (^)(void)> *dic, BOOL *stop1) {
		[dic enumerateKeysAndObjectsUsingBlock:^(id(^_target)(void) , SEL(^_action)(void), BOOL *stop2) {
			if (target == _target()) {
				if (action == _action()) {
					cancel = YES;
					*stop1 = YES;
					*stop2 = YES;
				}
			}
		}];
	}];
	if (cancel) { return; }
	__weak id weakObjcet = target;
	
	NSNumber *key = @(type);
	MDKLocTargetActSet *set = self.share.type_targetActionDic[key];
	if (!set) {
		set = [[MDKLocTargetActSet alloc]init];
		[self.share.type_targetActionDic setObject:set forKey:key];
	}
	NSDictionary *newDIc = @{^{ return weakObjcet; }:^{ return action; }};

	
	[set addObject:newDIc];
	
}
+(void)addActionBlock:(MDKLocationActionBlock)action forType:(MDKLocationKeepType)type{
	if (!action) { return; }


	NSNumber *key = @(type);
	MDKLocTargetActSet *set = self.share.type_targetActionDic[key];
	if (!set) {
		set = [[MDKLocTargetActSet alloc]init];
		[self.share.type_targetActionDic setObject:set forKey:key];
	}
	NSDictionary *newDIc = @{^{ return [[self alloc] init]; }:[action copy]};

	[set addObject:newDIc];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
	if (!_type_targetActionDic[@(MDKLocationKeepTypeAllways)].count) {
		[self.class stop];
	}
	_currentLocation = locations.lastObject;

	[_type_targetActionDic enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, MDKLocTargetActSet *set, BOOL * stop) {
		MDKLocationKeepType type = key.integerValue;
		[set enumerateObjectsUsingBlock:^(NSDictionary<id (^)(void),SEL (^)(void)> *dic, BOOL *stop) {
			[dic enumerateKeysAndObjectsUsingBlock:^(id(^target)(void) , SEL(^action)(void), BOOL *stop) {
				if (!target()) {
					[set removeObject:dic];
					return ;
				}
				if ([target() isKindOfClass:[self class]]) {
					MDKLocationActionBlock actionBlock = (id)action;
					actionBlock(_currentLocation);
				}else{
					[self notiTarget:target() runAction:action()];
				}
			}];
		}];
		
		switch (type) {
			case MDKLocationKeepTypeOnlyOnce:
				[set removeAllObjects];
				break;
			default: break;
		}
	}];
}
- (void)notiTarget:(nullable id)target runAction:(SEL)action{
	if ([target respondsToSelector:action]) {
		[target performSelector:action withObject:_currentLocation];
	}
}

+ (void)removeTarget:(nullable id)target action:(SEL)action{
	if (!target) { return; }
	[self.share.type_targetActionDic enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSMutableSet<NSDictionary<id (^)(void),SEL (^)(void)> *> *set, BOOL *stop1) {
		[set enumerateObjectsUsingBlock:^(NSDictionary<id (^)(void),SEL (^)(void)> *dic, BOOL *stop2) {
			[dic enumerateKeysAndObjectsUsingBlock:^(id(^_target)(void) , SEL(^_action)(void), BOOL *stop3) {
				if (target == _target()) {
					if ([target isKindOfClass:[self class]]) {
						[set removeObject:dic];
					}else{
						if (!action || action == _action()) {
							[set removeObject:dic];
						}
					}
				}
			}];
		}];
	}];
}

+ (void)locationServicesDisableMsg{

	[self showSettingMsg:@"请打开手机的定位功能"];
}
+ (void)showDeniedMsg{
	[self showSettingMsg:@"请打开定位权限"];
}
+ (void)showSettingMsg:(NSString *)msg{

	if ([NSUserDefaults.standardUserDefaults boolForKey:MDKLocationManagerNeverShowAlert]) { return; }

	UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"定位失败" message:msg preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *confirmAct = [UIAlertAction actionWithTitle:@"到设置去打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[MDKTenOpenTool openLocation];
	}];
	[alertVC addAction:confirmAct];

	UIAlertAction *cancelAct = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
	[alertVC addAction:cancelAct];

	UIAlertAction *neverShowAct = [UIAlertAction actionWithTitle:@"不再提示定位问题" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[NSUserDefaults.standardUserDefaults setBool:YES forKey:MDKLocationManagerNeverShowAlert];
	}];
	[alertVC addAction:neverShowAct];

	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertVC animated:YES completion:nil];
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
	[self handelError:error FromlocationManager:manager];
}
-(void)didFailToLocateUserWithError:(NSError *)error{
	[self handelError:error FromlocationManager:nil];
}
-(void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error{
	[self handelError:error FromlocationManager:manager];
}
-(void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error{
	[self handelError:error FromlocationManager:manager];
}
-(void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error{
	[self handelError:error FromlocationManager:manager];
}
- (void)handelError:(NSError *)error FromlocationManager:(CLLocationManager *)manager{

}


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
