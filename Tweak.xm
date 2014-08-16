//
//  Tweak.xm
//  IRKit for Activator
//
//  Created by kinda on 15.04.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

%config(generator=internal)

#import <libactivator/libactivator.h>
#import <objcipc/objcipc.h>
#import "Headers.h"
#import "NSString+Hashes.h"
#import "UIImage+IRKit.h"
#import "NSString+Hashes.h"
#import "BulletinBoard.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist"
#define IMAGE_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.images.plist"
#define BundleIdentifier @"jp.maaash.simpleremote"

@interface IRKitforActivator : NSObject <LAListener> {
    NSArray *_dictionary;
    NSMutableArray *_md5Lists;
}
- (void)register;
- (void)getSignals;
- (void)removeCurrentListeners;
- (void)sendSignal:(NSString *)signalName;
- (UIImage *)getSignalImage:(NSString *)listenerName;
- (NSString *)getSignalTitile:(NSString *)listenerName;
@end

static NSString *prefixName = @"com.kindadev.activator.irkit";
static IRKitforActivator *irkit = nil;

@implementation IRKitforActivator
+ (void)load
{
    irkit = [[self alloc] init];
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
    [self getSignals];
    _md5Lists = [NSMutableArray array];
    for (unsigned int i = 0; i < [_dictionary count]; i++) {
        NSString *name = [NSString stringWithFormat:@"%@_%@", prefixName, [_dictionary[i][@"name"] md5]];
        _md5Lists[i] = name;
        if ([LASharedActivator isRunningInsideSpringBoard]) {
            [LASharedActivator registerListener:irkit forName:name];
        }
    }
}

- (void)getSignals
{
    NSArray *dictionary = [[NSArray alloc] initWithContentsOfFile:PREFS_PATH];
    _dictionary = [dictionary copy];
}

- (void)removeCurrentListeners
{
    if (![LASharedActivator isRunningInsideSpringBoard])
        return;
    for (NSString *name in _md5Lists) {
        if ([LASharedActivator hasListenerWithName:name]) {
            [LASharedActivator unregisterListenerWithName:name];
        }
    }
}

- (void)showBanner:(BOOL)success listenerName:(NSString *)listenerName
{
    BBBulletinRequest *bulletin = [[%c(BBBulletinRequest) alloc] init];
    bulletin.title     = [self getSignalTitile:listenerName];
    bulletin.message   = success ? @"send successfully!" : @"send failed!"; 
    bulletin.sectionID = BundleIdentifier;
    [(SBBulletinBannerController *)[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:2];
}

- (void)sendSignal:(NSString *)signalName
{
    NSDictionary *dict = @{ @"action": @"send_signal", @"md5" : [signalName substringFromIndex:29] };
    [OBJCIPC sendMessageToAppWithIdentifier:BundleIdentifier messageName:@"IRKitSimple_Activator" dictionary:dict replyHandler:^(NSDictionary *reply) {
        BOOL success = [reply[@"success"] boolValue];
        [self showBanner:success listenerName:signalName];
    }];
}

- (NSString *)getSignalTitile:(NSString *)listenerName
{
    NSString *title = @"";
    for (unsigned int i = 0; i < [_dictionary count]; i++) {
        if ([listenerName isEqualToString:_md5Lists[i]]) {
            title = _dictionary[i][@"name"];
        }
    }
    return title;
}

- (UIImage *)getSignalImage:(NSString *)listenerName
{
    NSData *data = nil;
    NSArray *images = [[NSArray alloc] initWithContentsOfFile:IMAGE_PREFS_PATH];
    for (unsigned int i = 0; i < [_dictionary count]; i++) {
        if ([listenerName isEqualToString:_md5Lists[i]]) {
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

