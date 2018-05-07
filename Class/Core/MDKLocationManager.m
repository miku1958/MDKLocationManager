//
//  MDKLocationManager.m
//
//  Created by mikun on 2018/2/25.
//  Copyright © 2018年 MDK. All rights reserved.
//

#import "MDKLocationManager.h"

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
	if (@available(iOS 9.0, *)) {
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
	if (self.share.locManager.desiredAccuracy <= desiredAccuracy && self.share.currentLocation) {
		[self.share locationManager:self.share.locManager didUpdateLocations:@[self.share.currentLocation]];
		if (!self.share.type_targetActionDic[@(MDKLocationKeepTypeAllways)].count) {
			return;
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
			if (target == _target() && action == _action()) {
				cancel = YES;
				*stop1 = YES;
				*stop2 = YES;
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
		if (type == MDKLocationKeepTypeOnlyOnce) {
			[set removeAllObjects];
		}

	}];
}
- (void)notiTarget:(nullable id)target runAction:(SEL)action{
	if ([target respondsToSelector:action]) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"  //去除复写私有方法的警告

		[target performSelector:action withObject:_currentLocation];

#pragma clang diagnostic pop
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



@end
