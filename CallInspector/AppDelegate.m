//
//  AppDelegate.m
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import "AppDelegate.h"
#import "SMCallInspector.h"
#import <termios.h>
#import <time.h>
#import <sys/ioctl.h>

//UCS2编码支持
@implementation NSString (UCS2Encoding)

- (NSString *)ucs2EncodingString {
	NSMutableString *result = [NSMutableString string];
	for (int i = 0; i < [self length]; i++) {
		unichar unic = [self characterAtIndex:i];
		[result appendFormat:@"%04hX", unic];
	}
	return [NSString stringWithString:result];
}

- (NSString *)ucs2DecodingString {
	NSUInteger length = [self length] / 4;
	unichar *buf = malloc(sizeof(unichar) * length);
	const char *scanString = [self UTF8String];
	for (int i = 0; i < length; i++) {
		sscanf(scanString + i * 4, "%04hX", buf + i);
	}
	return [[NSString alloc] initWithCharacters:buf length:length];
}

- (NSString *)hexSwipString {
	unichar *oldBuf = malloc([self length] * sizeof(unichar));
	unichar *newBuf = malloc([self length] * sizeof(unichar));
	[self getCharacters:oldBuf range:NSMakeRange(0, [self length])];
	for (int i = 0; i < [self length]; i += 2) {
		newBuf[i] = oldBuf[i + 1];
		newBuf[i + 1] = oldBuf[i];
	}
	NSString *result = [NSString stringWithCharacters:newBuf length:[self length]];
	free(oldBuf);
	free(newBuf);
	return result;
}

@end

NSString *PDUEncodeSendingSMS(NSString *phone, NSString *text) {
	NSMutableString *string = [NSMutableString stringWithString:@"001100"];
	[string appendFormat:@"%02X", (int)[phone length]];
	if ([phone length] % 2 != 0) {
		phone = [phone stringByAppendingString:@"F"];
	}
	[string appendFormat:@"81%@", [phone hexSwipString]];
	[string appendString:@"0008AA"];
	NSString *ucs2Text = [text ucs2EncodingString];
	[string appendFormat:@"%02x%@", (int)[ucs2Text length] / 2, ucs2Text];
	return [NSString stringWithString:string];
}

NSString *sendATCommand(NSFileHandle *baseBand, NSString *atCommand) {
	NSLog(@"SEND AT: %@", atCommand);
	[baseBand writeData:[atCommand dataUsingEncoding:NSASCIIStringEncoding]];
	NSMutableString *result = [NSMutableString string];
	NSData *resultData = [baseBand availableData];
	while ([resultData length]) {
		[result appendString:[[NSString alloc] initWithData:resultData encoding:NSASCIIStringEncoding]];
		if ([result hasSuffix:@"OK\r\n"] || [result hasSuffix:@"ERROR\r\n"]) {
			NSLog(@"RESULT: %@", result);
			return [NSString stringWithString:result];
		}
		else {
			resultData = [baseBand availableData];
		}
	}
	return nil;
}

//添加SIM卡联系人
BOOL addNewSIMContact(NSFileHandle *baseband, NSString *name, NSString *phone) {
	NSString *result = sendATCommand(baseband, [NSString stringWithFormat:@"AT+CPBW=,\"%@\",,\"%@\"\r", phone, [name ucs2EncodingString]]);
	if ([result hasSuffix:@"OK\r\n"]) {
		return YES;
	}
	else {
		return NO;
	}
}

BOOL sendSMSWithPDUMode(NSFileHandle *baseband, NSString *phone, NSString *text) {
	NSString *pduString = PDUEncodeSendingSMS(phone, text);
	NSString *result = sendATCommand(baseband, [NSString stringWithFormat:@"AT+CMGS=%d\r", (int)[pduString length] / 2 - 1]);
	result = sendATCommand(baseband, [NSString stringWithFormat:@"%@\x1A", pduString]);
	if ([result hasSuffix:@"OK\r\n"]) {
		return YES;
	}
	else {
		return NO;
	}
}

//读取所有SIM卡联系人
NSArray *readAllSIMContacts(NSFileHandle *baseband) {
	NSString *result = sendATCommand(baseband, @"AT+CPBR=?\r");
	if (![result hasSuffix:@"OK\r\n"]) {
		return nil;
	}
	int max = 0;
	sscanf([result UTF8String], "%*[^+]+CPBR: (%*d-%d)", &max);
	result = sendATCommand(baseband, [NSString stringWithFormat:@"AT+CPBR=1,%d\r", max]);
	NSMutableArray *records = [NSMutableArray array];
	NSScanner *scanner = [NSScanner scannerWithString:result];
	[scanner scanUpToString:@"+CPBR:" intoString:NULL];
	while ([scanner scanString:@"+CPBR:" intoString:NULL]) {
		NSString *phone = nil;
		NSString *name = nil;
		[scanner scanInt:NULL];
		[scanner scanString:@",\"" intoString:NULL];
		[scanner scanUpToString:@"\"" intoString:&phone];
		[scanner scanString:@"\"," intoString:NULL];
		[scanner scanInt:NULL];
		[scanner scanString:@",\"" intoString:NULL];
		[scanner scanUpToString:@"\"" intoString:&name];
		[scanner scanUpToString:@"+CPBR:" intoString:NULL];
		if ([phone length] > 0 && [name length] > 0) {
			[records addObject:@{ @"name":[name ucs2DecodingString], @"phone":phone }];
		}
	}
	return [NSArray arrayWithArray:records];
}

@interface AppDelegate ()

@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@property (strong, nonatomic) dispatch_block_t expirationHandler;
@property (assign, nonatomic) BOOL jobExpired;
@property (assign, nonatomic) BOOL background;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Override point for customization after application launch.

	UIApplication *app = [UIApplication sharedApplication];
	[app setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

	self.expirationHandler = ^{
		[app endBackgroundTask:self.bgTask];
		self.bgTask = UIBackgroundTaskInvalid;
		self.bgTask = [app beginBackgroundTaskWithExpirationHandler:_expirationHandler];
		NSLog(@"Expired");
		self.jobExpired = YES;
		while (self.jobExpired) {
			// spin while we wait for the task to actually end.
			[NSThread sleepForTimeInterval:1];
		}
		// Restart the background task so we can run forever.
		[self startBackgroundTask];
	};
	self.bgTask = [app beginBackgroundTaskWithExpirationHandler:_expirationHandler];


	[application cancelAllLocalNotifications];
	[application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil]];

	[[SMCallInspector sharedInstance] startInspect]; //开始监听来电事件

//    Class UIAlertManager = NSClassFromString(@"_UIAlertManager");
//    UIAlertView *alertView = [UIAlertManager performSelector:@selector(topMostAlert)];

//	NSFileManager *fileManager = [NSFileManager defaultManager];
//	NSDirectoryEnumerator *dirnum = [[NSFileManager defaultManager] enumeratorAtPath:@"/private/"];
//	NSString *nextItem = [NSString string];
//	while ((nextItem = [dirnum nextObject])) {
//		if ([[nextItem pathExtension] isEqualToString:@"db"] ||
//		    [[nextItem pathExtension] isEqualToString:@"sqlitedb"]) {
//			if ([fileManager isReadableFileAtPath:nextItem]) {
//				NSLog(@"%@", nextItem);
//			}
//		}
//	}


	{ // 使用基带操作 - 只能越狱的机器
		NSString *cc = @"简体中文";

		NSLog(@"%@", [cc ucs2EncodingString]);
		NSLog(@"%@", [[cc ucs2EncodingString] ucs2DecodingString]);


		NSFileHandle *baseband = [NSFileHandle fileHandleForUpdatingAtPath:@"/dev/dlci.spi-baseband.extra_0"];
		if (baseband == nil) {
			NSLog(@"Can't open baseband.");
		}

		int fd = [baseband fileDescriptor];

		ioctl(fd, TIOCEXCL);
		fcntl(fd, F_SETFL, 0);

		static struct termios term;

		tcgetattr(fd, &term);

		cfmakeraw(&term);
		cfsetspeed(&term, 115200);
		term.c_cflag = CS8 | CLOCAL | CREAD;
		term.c_iflag = 0;
		term.c_oflag = 0;
		term.c_lflag = 0;
		term.c_cc[VMIN] = 0;
		term.c_cc[VTIME] = 0;
		tcsetattr(fd, TCSANOW, &term);

		//设置环境
		NSString *result = sendATCommand(baseband, @"AT+CPBS=\"SM\"\r");
		result = sendATCommand(baseband, @"AT+CSCS=\"UCS2\"\r");
		result = sendATCommand(baseband, @"ATE0\r");

		//添加数个联系人
//        addNewSIMContact(baseband, @"测试一", @"13111111111");
//        addNewSIMContact(baseband, @"测试二", @"13122222222");
//        addNewSIMContact(baseband, @"测试三", @"13111113333");
//        addNewSIMContact(baseband, @"测试四", @"13111114444");

		//获取所有联系人
		NSArray *allContacts = readAllSIMContacts(baseband);
		NSLog(@"%@", allContacts);

		sendSMSWithPDUMode(baseband, @"10010", @"测试");
	}

	return YES;
}

- (void)startBackgroundTask {
	NSLog(@"Restarting task");
	// Start the long-running task.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	    // When the job expires it still keeps running since we never exited it. Thus have the expiration handler
	    // set a flag that the job expired and use that to exit the while loop and end the task.
	    while (self.background && !self.jobExpired) {
	        { // 做背景操作
			}
	        [NSThread sleepForTimeInterval:1];
		}

	    self.jobExpired = NO;
	});
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

	self.background = NO;
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
