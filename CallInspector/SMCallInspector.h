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

#import <Foundation/Foundation.h>

@interface SMCallInspector : NSObject

+ (instancetype)sharedInstance;

/**
 *  开始侦听来电
 */
- (void)startInspect;

// 停止侦听来电
- (void)stopInspect;

@end
