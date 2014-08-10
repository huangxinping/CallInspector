//
//  SMCall.h
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreTelephony;

// private API
typedef NS_ENUM (short, CTCallStatus) {
	kCTCallStatusConnected = 1, //已接通
	kCTCallStatusCallOut = 3, //拨出去
	kCTCallStatusCallIn = 4, //打进来
	kCTCallStatusHungUp = 5 //挂断
};

@interface SMCall : NSObject

@property (nonatomic, assign) CTCallStatus callStatus;
@property (nonatomic, copy) NSString *phoneNumber;

@property (nonatomic, strong) CTCall *internalCall; //真实的系统CTCall

@end
