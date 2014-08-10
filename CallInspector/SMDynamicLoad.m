//
//  SMDynamicLoad.m
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import "SMDynamicLoad.h"
#import <dlfcn.h>

@implementation SMDynamicLoad

+ (void *)loadSymbol:(NSString *)systemName {
	return dlsym(RTLD_SELF, [systemName UTF8String]);
}

@end
