//
//  SMCallCenter.m
//  CallInspector
//
//  Created by huangxinping on 6/26/14.
//  Copyright (c) 2014 ShareMerge. All rights reserved.
//

#import "SMCallCenter.h"
#import "SMDynamicLoad.h"


//extern "C" CFNotificationCenterRef CTTelephonyCenterGetDefault(void); // 获得 TelephonyCenter (电话消息中心) 的引用
//extern "C" void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
//extern "C" void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object);
//extern "C" NSString *CTCallCopyAddress(void *, CTCall *call); //获得来电号码
//extern "C" void CTCallDisconnect(CTCall *call); // 挂断电话
//extern "C" void CTCallAnswer(CTCall *call); // 接电话
//extern "C" void CTCallAddressBlocked(CTCall *call);
//extern "C" int CTCallGetStatus(CTCall *call); // 获得电话状态　拨出电话时为３，有呼入电话时为４，挂断电话时为５
//extern "C" int CTCallGetGetRowIDOfLastInsert(void); // 获得最近一条电话记录在电话记录数据库中的位置



@interface NSString (decrypt)

- (NSString *)wcEncryptString;
- (NSString *)wcDecryptString;

@end

@implementation NSString (decrypt)

- (NSString *)wcRot13 {
	const char *source = [self cStringUsingEncoding:NSASCIIStringEncoding];
	char *dest = (char *)malloc((self.length + 1) * sizeof(char));
	if (!dest) {
		return nil;
	}

	NSUInteger i = 0;
	for (; i < self.length; i++) {
		char c = source[i];
		if (c >= 'A' && c <= 'Z') {
			c = (c - 'A' + 13) % 26 + 'A';
		}
		else if (c >= 'a' && c <= 'z') {
			c = (c - 'a' + 13) % 26 + 'a';
		}
		dest[i] = c;
	}
	dest[i] = '\0';

	NSString *result = [[NSString alloc] initWithCString:dest encoding:NSASCIIStringEncoding];
	free(dest);

	return result;
}

- (NSString *)wcEncryptString {
	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	NSString *base64 = [data base64EncodedStringWithOptions:0];
	return [base64 wcRot13];
}

- (NSString *)wcDecryptString {
	NSString *rot13 = [self wcRot13];
	NSData *data = [[NSData alloc] initWithBase64EncodedString:rot13 options:0];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

// encrypted string's
#define ENCSTR_kCTCallStatusChangeNotification  [@"n0AHD2SfoSA0LKE1p0AbLJ5aMH5iqTyznJAuqTyiot==" wcDecryptString]
#define ENCSTR_kCTCall                          [@"n0AHD2SfoN==" wcDecryptString]
#define ENCSTR_kCTCallStatus                    [@"n0AHD2SfoSA0LKE1pj==" wcDecryptString]
#define ENCSTR_CTTelephonyCenterGetDefault      [@"D1EHMJkypTuioayQMJ50MKWUMKERMJMuqJk0" wcDecryptString]
#define ENCSTR_CTTelephonyCenterAddObserver     [@"D1EHMJkypTuioayQMJ50MKWOMTECLaAypaMypt==" wcDecryptString]
#define ENCSTR_CTTelephonyCenterRemoveObserver  [@"D1EHMJkypTuioayQMJ50MKWFMJ1iqzICLaAypaMypt==" wcDecryptString]
#define ENCSTR_CTCallCopyAddress                [@"D1EQLJkfD29jrHSxMUWyp3Z=" wcDecryptString]
#define ENCSTR_CTCallDisconnect                 [@"D1EQLJkfETymL29hozIwqN==" wcDecryptString]

// private API
//extern NSString *CTCallCopyAddress(void*, CTCall *);
typedef NSString *(*PF_CTCallCopyAddress)(void *, CTCall *);

//extern void CTCallDisconnect(CTCall *);
typedef void (*PF_CTCallDisconnect)(CTCall *);

//extern CFNotificationCenterRef CTTelephonyCenterGetDefault();
typedef CFNotificationCenterRef (*PF_CTTelephonyCenterGetDefault)();

//extern void CTTelephonyCenterAddObserver(CFNotificationCenterRef center,
//                                         const void *observer,
//                                         CFNotificationCallback callBack,
//                                         CFStringRef name,
//                                         const void *object,
//                                         CFNotificationSuspensionBehavior suspensionBehavior);
typedef void (*PF_CTTelephonyCenterAddObserver)(CFNotificationCenterRef          center,
                                                const void *                     observer,
                                                CFNotificationCallback           callBack,
                                                CFStringRef                      name,
                                                const void *                     object,
                                                CFNotificationSuspensionBehavior suspensionBehavior);

//extern void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center,
//                                            const void *observer,
//                                            CFStringRef name,
//                                            const void *object);
typedef void (*PF_CTTelephonyCenterRemoveObserver)(CFNotificationCenterRef center,
                                                   const void *            observer,
                                                   CFStringRef             name,
                                                   const void *            object);

@interface SMCallCenter ()

- (void)handleCall:(CTCall *)call withStatus:(CTCallStatus)status;

@end

@implementation SMCallCenter

- (id)init {
	self = [super init];
	if (self) {
		[self registerCallHandler];
	}
	return self;
}

- (void)dealloc {
	[self deregisterCallHandler];
}

//注册监听事件
- (void)registerCallHandler {
	static PF_CTTelephonyCenterAddObserver AddObserver;
	static PF_CTTelephonyCenterGetDefault GetCenter;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    AddObserver = [SMDynamicLoad loadSymbol:ENCSTR_CTTelephonyCenterAddObserver];
	    GetCenter = [SMDynamicLoad loadSymbol:ENCSTR_CTTelephonyCenterGetDefault];
	});

	AddObserver(GetCenter(),
	            (__bridge void *)self,
	            &callHandler,
//	            (__bridge CFStringRef)(ENCSTR_kCTCallStatusChangeNotification),
	            NULL,
	            NULL,
	            CFNotificationSuspensionBehaviorHold);
}

//注销
- (void)deregisterCallHandler {
	static PF_CTTelephonyCenterRemoveObserver RemoveObserver;
	static PF_CTTelephonyCenterGetDefault GetCenter;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    RemoveObserver = [SMDynamicLoad loadSymbol:ENCSTR_CTTelephonyCenterRemoveObserver];
	    GetCenter = [SMDynamicLoad loadSymbol:ENCSTR_CTTelephonyCenterGetDefault];
	});

	RemoveObserver(GetCenter(),
	               (__bridge void *)self,
//	               (__bridge CFStringRef)(ENCSTR_kCTCallStatusChangeNotification),
	               NULL,
	               NULL);
}

static void callHandler(CFNotificationCenterRef center,
                        void *                  observer,
                        CFStringRef             name,
                        const void *            object,
                        CFDictionaryRef         userInfo) {
	if (!observer) {
		return;
	}

	NSLog(@"。。。。%@", name);

//	NSDictionary *info = (__bridge NSDictionary *)(userInfo);
//	CTCall *call = (CTCall *)info[ENCSTR_kCTCall];
//	CTCallStatus status = (CTCallStatus)[info[ENCSTR_kCTCallStatus] shortValue];
//
//	NSLog(@"%d", status);
//
//	SMCallCenter *smCenter = (__bridge SMCallCenter *)observer;
//	[smCenter handleCall:call withStatus:status];
}

- (void)handleCall:(CTCall *)call withStatus:(CTCallStatus)status {
	static PF_CTCallCopyAddress CopyAddress;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    CopyAddress = [SMDynamicLoad loadSymbol:ENCSTR_CTCallCopyAddress];
	});

	if (!self.callEventHandler || !call) {
		return;
	}

	//整理出WCCall
	SMCall *smcall = [[SMCall alloc] init];
	smcall.phoneNumber = CopyAddress(NULL, call);
	smcall.callStatus = status;
	smcall.internalCall = call;

	self.callEventHandler(smcall);
}

- (void)disconnectCall:(SMCall *)call {
	static PF_CTCallDisconnect Disconnect;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    Disconnect = [SMDynamicLoad loadSymbol:ENCSTR_CTCallDisconnect];
	});

	CTCall *ctCall = call.internalCall;
	if (!ctCall) {
		return;
	}

	Disconnect(ctCall);
}

@end
