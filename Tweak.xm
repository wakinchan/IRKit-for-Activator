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

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist"
#define IMAGE_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.images.plist"

@interface IRKitforActivator : NSObject <LAListener> {
    NSMutableArray *_md5s;
}
- (void)register;
- (NSArray *)getSignals;
- (NSArray *)getImages;
- (void)removeCurrentListeners;
- (void)sendSignal:(NSString *)signalName;
- (UIImage *)getSignalImage:(NSString *)listenerName;
- (NSString *)getSignalTitile:(NSString *)listenerName;
- (void)showBanner:(BOOL)success forListenerName:(NSString *)listenerName;
@end

static const char *bundleIdentifier = "jp.maaash.simpleremote";
static const char *prefixName = "com.kindadev.activator.irkit";
static IRKitforActivator *irkit = nil;

@implementation IRKitforActivator
+ (void)load
{
    irkit = [[IRKitforActivator alloc] init];
    [irkit register];

    __weak IRKitforActivator *weakSelf = irkit;
    [OBJCIPC registerIncomingMessageFromAppHandlerForMessageName:@"IRKitSubstrate_Activator_UpdateListeners" handler:^NSDictionary *(NSDictionary *dict) {
        [weakSelf removeCurrentListeners];
        [weakSelf register];
        return nil;
    }];
}

- (void)register
{
    NSArray *signals = [self getSignals];
    _md5s = [NSMutableArray array];
    for (unsigned int i = 0; i < [signals count]; i++) {
        NSString *name = [NSString stringWithFormat:@"%s_%@", prefixName, [signals[i][@"name"] md5]];
        _md5s[i] = name;
        if ([LASharedActivator isRunningInsideSpringBoard]) {
            [LASharedActivator registerListener:self forName:name];
        }
    }
}

- (void)dealloc
{
    for (NSString *name in _md5s) {
        if ([LASharedActivator hasListenerWithName:name]) {
            [LASharedActivator unregisterListenerWithName:name];
        }
    }
}

- (NSArray *)getSignals
{
    return [NSArray arrayWithContentsOfFile:PREFS_PATH];
}

- (NSArray *)getImages
{
    return [NSArray arrayWithContentsOfFile:IMAGE_PREFS_PATH];
}

- (void)removeCurrentListeners
{
    if (![LASharedActivator isRunningInsideSpringBoard]) {
        return;
    }
    for (NSString *name in _md5s) {
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
    bulletin.sectionID = [NSString stringWithUTF8String:bundleIdentifier];
    [(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:2];
}

- (void)sendSignal:(NSString *)signalName
{
    NSDictionary *dict = @{ @"action": @"send_signal", @"md5" : [signalName substringFromIndex:29] };
    [OBJCIPC sendMessageToAppWithIdentifier:[NSString stringWithUTF8String:bundleIdentifier] messageName:@"IRKitSimple_Activator" dictionary:dict replyHandler:^(NSDictionary *reply) {
        BOOL success = [reply[@"success"] boolValue];
        [self showBanner:success forListenerName:signalName];
    }];
}

- (NSString *)getSignalTitile:(NSString *)listenerName
{
    NSString *title = @"";
    NSArray *signals = [self getSignals];
    for (unsigned int i = 0; i < [signals count]; i++) {
        if ([listenerName isEqualToString:_md5s[i]]) {
            title = signals[i][@"name"];
        }
    }
    return title;
}

- (UIImage *)getSignalImage:(NSString *)listenerName
{
    NSData *data = nil;
    NSArray *signals = [self getSignals];
    NSArray *images = [self getImages];
    for (unsigned int i = 0; i < [signals count]; i++) {
        if ([listenerName isEqualToString:_md5s[i]]) {
            data = images[i];
        }
    }
    return [[UIImage alloc] initWithData:data];
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
