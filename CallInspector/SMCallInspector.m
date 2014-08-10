/**
 *  SMCallInspector.h
 *  ShareMerge
 *
 *  Created by huangxp on 2014-06-26.
 *
 *  呼叫侦听
 *
 *  Copyright (c) www.sharemerge.com All rights reserved.
 */

/** @file */    // Doxygen marker

#import "SMCallInspector.h"
#import <AudioToolbox/AudioToolbox.h>
#import "SMCallCenter.h"
#import "SMCall.h"
#import <UIKit/UIKit.h>

@interface SMCallInspector ()

@property (nonatomic, strong) SMCallCenter *callCenter;
@property (nonatomic, copy) NSString *incomingPhoneNumber;

@end

@implementation SMCallInspector

+ (instancetype)sharedInstance {
	static SMCallInspector *instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    instance = [[SMCallInspector alloc] init];
	});
	return instance;
}

- (id)init {
	self = [super init];
	if (self) {
	}
	return self;
}

#pragma mark - Call Inspection

- (void)startInspect {
	if (self.callCenter) {
		return;
	}

	self.callCenter = [[SMCallCenter alloc] init];

	__weak SMCallInspector *weakSelf = self;
	self.callCenter.callEventHandler = ^(SMCall *call) { [weakSelf handleCallEvent:call]; };
}

- (void)stopInspect {
	self.callCenter = nil;
}

//来电事件
- (void)handleCallEvent:(SMCall *)call {
	// 接通后震动一下
	if (call.callStatus == kCTCallStatusConnected) {
		[self vibrateDevice];
	}

	// 不是打进电话和接通以及拨出电话时候
	if (call.callStatus != kCTCallStatusCallIn && call.callStatus != kCTCallStatusConnected && call.callStatus != kCTCallStatusCallOut) {
		//这个会影响处理删除添加的数字联系人记录
		self.incomingPhoneNumber = nil;
		return;
	}

	if (self.incomingPhoneNumber) { //不为nil代表针对当前通话下面的操作走过一次了，不需要重新走过。
		return;
	}

	NSString *number = call.phoneNumber;
	self.incomingPhoneNumber = number;

	[self notifyMessage:@"" forPhoneNumber:number andTempRecordID:0];

	[self sendLocalNotification:self.incomingPhoneNumber];
}

#pragma mark - Notify Users
- (void)notifyMessage:(NSString *)text forPhoneNumber:(NSString *)phoneNumber andTempRecordID:(NSInteger)tempContactRecordID {
	// delay一下,1秒检查一次
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
	    if ([self.incomingPhoneNumber isEqualToString:phoneNumber]) {
	        // 下一轮提醒
	        [self notifyMessage:text forPhoneNumber:phoneNumber andTempRecordID:tempContactRecordID];
		}
	    else {
		}
	});
}

#pragma mark - other
- (void)sendLocalNotification:(NSString *)message {
	NSLog(@"%@", message);
	UILocalNotification *notification = [[UILocalNotification alloc] init];
	notification.alertAction = @"通话侦测";
	notification.alertBody = message;
	notification.soundName = UILocalNotificationDefaultSoundName;
	notification.applicationIconBadgeNumber = 0;
	notification.fireDate = [NSDate date];
	[notification setTimeZone:[NSTimeZone defaultTimeZone]];
//	[[UIApplication sharedApplication] scheduleLocalNotification:notification];
	[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

- (void)vibrateDevice {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

@end
