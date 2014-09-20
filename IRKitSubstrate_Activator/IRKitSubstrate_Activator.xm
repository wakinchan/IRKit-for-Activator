//
//  IRKitSubstrate_Activator.xm
//  IRKit for Activator
//
//  Created by kinda on 10.08.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

%config(generator=internal)

#import <objcipc/objcipc.h>
#import "../Headers.h"
#import "../NSString+Hashes.h"
#import "../UIImage+IRKit.h"

#define SIGNALS_DIRECTORY [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/IRLauncher/"]

static NSString * const kPreferencePath = @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist";
static NSString * const kImagePreferencePath = @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.images.plist";

@interface SSSettingsViewController : UITableViewController <UIActionSheetDelegate>
- (void)exportIRKitSettings;
- (void)exportOSXLauncherSettings;
@end

%hook SSSettingsViewController
- (void)viewDidLoad
{
    %orig;
    UIButton* exportBtn = [UIButton buttonWithType:101]; 
    [exportBtn addTarget:self action:@selector(handleExportTapped:) forControlEvents:UIControlEventTouchUpInside];
    [exportBtn setTitle:@"Export" forState:UIControlStateNormal];
    UIBarButtonItem* exportItem = [[UIBarButtonItem alloc] initWithCustomView:exportBtn];
    self.navigationItem.rightBarButtonItem = exportItem;
}

%new
- (void)handleExportTapped:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@"Export settings:"
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:@"for Activator", @"for IRLauncher (OSX)", nil];
    [actionSheet showInView:self.view];
}

%new
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0: [self exportIRKitSettings];       break;
        case 1: [self exportOSXLauncherSettings]; break;
        default: break;
    }
}

%new
- (void)exportIRKitSettings
{
    IRSignals *signals = [[%c(IRSignals) alloc] init];
    [signals loadFromStandardUserDefaultsKey:@"signals"];
    
    NSMutableArray *data = [NSMutableArray array];
    NSMutableArray *images = [NSMutableArray array];
    NSMutableArray *md5Lists = [NSMutableArray array];
    for (unsigned int i = 0; i < [signals countOfSignals]; i++) {
        IRSignal *signal =  [signals objectInSignalsAtIndex:i];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict = [[signal asDictionary] mutableCopy];
        data[i] = dict;

        md5Lists[i] = [data[i][@"name"] md5];
        NSString *type = data[i][@"custom"][@"type"];

        UIImage *image = [UIImage new];
        if ([type isEqualToString:@"preset"]) {
            NSString *name = data[i][@"custom"][@"name"];
            image = [UIImage imageNamed:[NSString stringWithFormat:@"btn_icon_120_%@", name]];
            
        } else if ([type isEqualToString:@"album"]) {
            NSString *dir = data[i][@"custom"][@"dir"];
            if ([dir hasPrefix:@"/var/mobile/Applications/"]) {
                dir = [[dir componentsSeparatedByString:@"/"] lastObject];
            }
            NSString *path = [NSString stringWithFormat:@"%@/%@/120.png", [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"], dir];
            image = [[UIImage imageWithContentsOfFile:path] makeCornerRoundImage];
        }
        images[i] = [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
    }
    [data writeToFile:kPreferencePath atomically:YES];
    [images writeToFile:kImagePreferencePath atomically:YES];
    
    [OBJCIPC sendMessageToSpringBoardWithMessageName:@"IRKitSubstrate_Activator_UpdateListeners" dictionary:nil replyHandler:nil];
    [[[UIAlertView alloc] initWithTitle:@"Export!" message:@"Output complete the data to be used to IRKit for Activator." delegate:nil cancelButtonTitle:@"Yep!" otherButtonTitles:nil] show];
}

// https://github.com/irkit/osx-launcher/blob/master/IRLauncher/ILFileStore.m
%new
- (void)exportOSXLauncherSettings
{
    IRSignals *signals = [[%c(IRSignals) alloc] init];
    [signals loadFromStandardUserDefaultsKey:@"signals"];

    for (unsigned int i = 0; i < [signals countOfSignals]; i++) {
        IRSignal *signal =  [signals objectInSignalsAtIndex:i];

        NSError *error = nil;

        NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString: @"/\\?%*|\"<>"];
        NSString *safename = [[signal.name componentsSeparatedByCharactersInSet: illegalFileNameCharacters] componentsJoinedByString: @""];

        NSData *json = [NSJSONSerialization dataWithJSONObject:[signal asDictionary] options:NSJSONWritingPrettyPrinted error:&error];
        if (error) {
            NSLog( @"failed with error: %@", error );
        }

        BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:SIGNALS_DIRECTORY
                                                 withIntermediateDirectories:YES
                                                                  attributes:nil
                                                                       error:&error];
        if (!created) {
            NSLog( @"createDirectoryAtPath:... failed with error: %@", error );
        }

        NSString *basename = [NSString stringWithFormat: @"%@.json", safename];
        NSString *file     = [SIGNALS_DIRECTORY stringByAppendingPathComponent: basename];

        // doesn't overwrite file
        BOOL success = [json writeToURL:[NSURL fileURLWithPath: file]
                                options:NSDataWritingAtomic
                                  error:&error];
        if (!success) {
            NSLog( @"doesn't overwrite file:... %@", file );
        }
    }

    [[[UIAlertView alloc] initWithTitle:@"Export!" message:@"Output complete the data to be used to IRLauncher. Please copy json files and use on your Mac.\n\n/var/mobile/Applications/Simple.app/Documents/IRLauncher/*.json -> Your Mac ~/.irkit.d/signals/" delegate:nil cancelButtonTitle:@"Yep!" otherButtonTitles:nil] show];
}
%end

static inline __attribute__((constructor)) void init()
{
    @autoreleasepool {
        [OBJCIPC registerIncomingMessageFromSpringBoardHandlerForMessageName:@"IRKitSimple_Activator" handler:^NSDictionary *(NSDictionary *dict) {
            NSString *action = dict[@"action"];
            if ([action isEqualToString:@"send_signal"]) {
                IRSignals *signals = [[%c(IRSignals) alloc] init];
                [signals loadFromStandardUserDefaultsKey:@"signals"];

                int index = -1;
                NSMutableArray *asDictionary = [NSMutableArray array];
                for (unsigned int i = 0; i < [signals countOfSignals]; i++) {
                    IRSignal *signal =  [signals objectInSignalsAtIndex:i];
                    asDictionary[i] = [signal asDictionary];
                    if ([dict[@"md5"] isEqualToString:[asDictionary[i][@"name"] md5]]) {
                        index = i;
                    }
                }
                
                if (index == -1) {
                    return @{ @"success": @(NO) };
                }
                IRSignal *signal =  [signals objectInSignalsAtIndex:index];

                __block BOOL isSendFailed = NO;
                [signal sendWithCompletion:^(NSError *error) {
                    if (error != nil) {
                        isSendFailed = YES;
                        NSLog( @"sent with error: %@", error );
                        
                    }
                }];
                if (isSendFailed) {
                    return @{ @"success": @(NO) };
                }

                return @{ @"success": @(YES) };
            }
            
            return nil;
        }];
    }
}
