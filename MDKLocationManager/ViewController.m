//
//  ViewController.m
//  MDKLocationManager
//
//  Created by mikun on 2018/4/28.
//  Copyright © 2018年 mdk. All rights reserved.
//

#import "ViewController.h"
#import "MDKLocationManager.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	[MDKLocationManager addActionBlock:^(CLLocation *location) {
		NSLog(@"fromActionBlock:%@",location);
	} forType:MDKLocationKeepTypeOnlyOnce];

	[MDKLocationManager addTarget:self action:@selector(updateLocation:) forType:MDKLocationKeepTypeAllways];
}

- (IBAction)locationAction:(id)sender {
	[MDKLocationManager startWithDesiredAccuracy:kCLLocationAccuracyBest];
}
- (void)updateLocation:(CLLocation *)location{
	NSLog(@"fromUpdateAction:%@",location);
}


@end
