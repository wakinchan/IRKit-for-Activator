//
//  Tweak.xm
//  IRKit for Activator
//
//  Created by kinda on 10.08.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

%config(generator=internal)

#import <libactivator/libactivator.h>
#import <objcipc/objcipc.h>
#import "Headers.h"
#import "UIImage+IRKit.h"
#import "NSString+Hashes.h"
#import "BulletinBoard.h"

@interface IRKitforActivator : NSObject <LAListener> {
}
@property (strong, nonatomic) NSMutableArray *md5s;
- (void)registerListeners;
- (NSArray *)getSignals;
- (NSArray *)getImages;
- (void)removeCurrentListeners;
- (void)sendSignal:(NSString *)signalName;
- (UIImage *)getSignalImage:(NSString *)listenerName;
- (NSString *)getSignalTitile:(NSString *)listenerName;
- (void)showBanner:(BOOL)success forListenerName:(NSString *)listenerName;
@end

static NSString * const kPreferencePath = @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist";
static NSString * const kImagePreferencePath = @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.images.plist";
static NSString * const kBundleIdentifier = @"jp.maaash.simpleremote";
static NSString * const kPrefixName = @"com.kindadev.activator.irkit";
static IRKitforActivator *irkit = nil;
static BOOL isOperationNotPermitted = NO;

@implementation IRKitforActivator
+ (void)load
{
    @autoreleasepool {
        irkit = [[self alloc] init];
        [irkit registerListeners];

        __weak IRKitforActivator *weakSelf = irkit;
        [OBJCIPC registerIncomingMessageFromAppHandlerForMessageName:@"IRKitSubstrate_Activator_UpdateListeners" handler:^NSDictionary *(NSDictionary *dict) {
            [weakSelf removeCurrentListeners];
            [weakSelf registerListeners];
            return nil;
        }];
    }
}

- (void)registerListeners
{
    NSArray *signals = [self getSignals];
    NSLog(@"%s] signals: %@", __func__, signals);
    self.md5s = [NSMutableArray array];
    for (unsigned int i = 0; i < [signals count]; i++) {
        NSString *name = [NSString stringWithFormat:@"%@_%@", kPrefixName, [signals[i][@"name"] md5]];
        self.md5s[i] = name;
        if ([LASharedActivator isRunningInsideSpringBoard]) {
            [LASharedActivator registerListener:self forName:name];
        }
    }
}

- (NSArray *)getSignals
{
    NSArray *signals = [NSArray arrayWithContentsOfFile:kPreferencePath];
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:kPreferencePath];
    if (isExist && !signals) {
        isOperationNotPermitted = YES;
    }
    return signals;
}

- (NSArray *)getImages
{
    return [NSArray arrayWithContentsOfFile:kImagePreferencePath];
}

- (void)removeCurrentListeners
{
    if (![LASharedActivator isRunningInsideSpringBoard]) {
        return;
    }
    for (NSString *name in self.md5s) {
        if ([LASharedActivator hasListenerWithName:name]) {
            [LASharedActivator unregisterListenerWithName:name];
        }
    }
}

- (void)showBanner:(BOOL)success forListenerName:(NSString *)listenerName
{
    BBBulletinRequest *bulletin = [[%c(BBBulletinRequest) alloc] init];
    bulletin.title = [self getSignalTitile:listenerName];
    bulletin.message = success ? @"send successfully!" : @"send failed!"; 
    bulletin.sectionID = kBundleIdentifier;
    [(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:1];
}

- (void)sendSignal:(NSString *)signalName
{
    NSDictionary *dict = @{ @"action": @"send_signal", @"md5" : [signalName substringFromIndex:29] };
    [OBJCIPC sendMessageToAppWithIdentifier:kBundleIdentifier messageName:@"IRKitSimple_Activator" dictionary:dict replyHandler:^(NSDictionary *reply) {
        BOOL success = [reply[@"success"] boolValue];
        [self showBanner:success forListenerName:signalName];
    }];
}

- (NSString *)getSignalTitile:(NSString *)listenerName
{
    NSArray *signals = [self getSignals];
    for (unsigned int i = 0; i < [signals count]; i++) {
        if ([listenerName isEqualToString:self.md5s[i]]) {
            return signals[i][@"name"];
        }
    }
    return @"un-defined title";
}

- (UIImage *)getSignalImage:(NSString *)listenerName
{
    NSArray *signals = [self getSignals];
    NSArray *images = [self getImages];
    for (unsigned int i = 0; i < [signals count]; i++) {
        if ([listenerName isEqualToString:self.md5s[i]]) {
            return [[UIImage alloc] initWithData:images[i]];
        }
    }
    return nil;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
    [self sendSignal:listenerName];
    [event setHandled:YES]; 
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
    return @"IRKit for Activator";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
    return [self getSignalTitile:listenerName];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
    return @"Activator action to send a signal to IRKit.";
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
    return @[@"springboard", @"lockscreen", @"application"];
}

- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    return [[self getSignalImage:listenerName] makeThumbnailOfSize:CGSizeMake(18*scale,18*scale)];
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    return [[self getSignalImage:listenerName] makeThumbnailOfSize:CGSizeMake(18*scale,18*scale)];
}
@end

%hook SBLockScreenManager
- (BOOL)attemptUnlockWithPasscode:(id)passcode
{
    BOOL success = %orig;
    if (isOperationNotPermitted && success) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"%s] IRKitforActivator updateListeners", __func__);
            [irkit removeCurrentListeners];
            [irkit registerListeners];
            isOperationNotPermitted = NO;
        });
    }
    return success;
}
%end
