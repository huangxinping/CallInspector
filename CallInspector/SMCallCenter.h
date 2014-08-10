//
//  SMCallCenter.h
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMCall.h"

@interface SMCallCenter : NSObject

// 监听来电事件
@property (nonatomic, copy) void (^callEventHandler)(SMCall *call);

// 挂断电话
- (void)disconnectCall:(SMCall *)call;

@end
