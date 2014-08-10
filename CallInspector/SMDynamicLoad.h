//
//  SMDynamicLoad.h
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMDynamicLoad : NSObject

+ (void *)loadSymbol:(NSString *)systemName;

@end
