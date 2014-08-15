//
//  IRKitSubstrate_Activator.xm
//  IRKit for Activator
//
//  Created by kinda on 15.04.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

%config(generator=internal)

#import <objcipc/objcipc.h>
#import "../Headers.h"
#import "../NSString+Hashes.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist"
#define IMAGE_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.images.plist"
#define MD5_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.md5.plist"
#define SIGNALS_DIRECTORY [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/IRLauncher/"]
//@"/Library/Application Support/"

@interface SSSettingsViewController : UITableViewController <UIActionSheetDelegate>
- (void)exportIRKitSettings;
- (void)exportOSXLauncherSettings;
@end

static inline UIImage * MakeCornerRoundImage(UIImage *image)
{
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, 120, 120);
    imageLayer.contents = (id)image.CGImage;
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = 25.0f;

    UIGraphicsBeginImageContext(imageLayer.frame.size);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return roundedImage;
}

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
    IRSignals *_signals = [[%c(IRSignals) alloc] init];
    [_signals loadFromStandardUserDefaultsKey:@"signals"];
    
    NSMutableArray *asDictionary = [NSMutableArray array];
    NSMutableArray *images = [NSMutableArray array];
    NSMutableArray *md5Lists = [NSMutableArray array];
    for (unsigned int i = 0; i < [_signals countOfSignals]; i++) {
        IRSignal *_signal =  [_signals objectInSignalsAtIndex:i];
        asDictionary[i] = [_signal asDictionary];
        md5Lists[i] = [asDictionary[i][@"name"] md5];
        NSString *type = asDictionary[i][@"custom"][@"type"];

        UIImage *image = [UIImage new];
        if ([type isEqualToString:@"preset"]) {
            NSString *name = asDictionary[i][@"custom"][@"name"];
            image = [UIImage imageNamed:[NSString stringWithFormat:@"btn_icon_120_%@", name]];
            
        } else if ([type isEqualToString:@"album"]) {
            NSString *dir = asDictionary[i][@"custom"][@"dir"];
            if ([dir hasPrefix:@"/var/mobile/Applications/"]) {
                dir = [[dir componentsSeparatedByString:@"/"] lastObject];
            }
            NSString *path = [NSString stringWithFormat:@"%@/%@/120.png", [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"], dir];
            image = MakeCornerRoundImage([UIImage imageWithContentsOfFile:path]);
        }
        images[i] = [[[NSData alloc] initWithData:UIImagePNGRepresentation(image)] autorelease];;
    }

    [asDictionary writeToFile:PREFS_PATH atomically:YES];
    [images writeToFile:IMAGE_PREFS_PATH atomically:YES];
    [md5Lists writeToFile:MD5_PREFS_PATH atomically:YES];

    [[[UIAlertView alloc] initWithTitle:@"Export!" message:@"Output complete the data to be used to IRKit for Activator." delegate:nil cancelButtonTitle:@"Yep!" otherButtonTitles:nil] show];
}

// https://github.com/irkit/osx-launcher/blob/master/IRLauncher/ILFileStore.m
%new
- (void)exportOSXLauncherSettings
{
    IRSignals *_signals = [[%c(IRSignals) alloc] init];
    [_signals loadFromStandardUserDefaultsKey:@"signals"];

    for (unsigned int i = 0; i < [_signals countOfSignals]; i++) {
        IRSignal *_signal =  [_signals objectInSignalsAtIndex:i];

        NSError **error = nil;

        NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString: @"/\\?%*|\"<>"];
        NSString *safename = [[_signal.name componentsSeparatedByCharactersInSet: illegalFileNameCharacters] componentsJoinedByString: @""];

        NSData *json = [NSJSONSerialization dataWithJSONObject:[_signal asDictionary] options:NSJSONWritingPrettyPrinted error:error];
        if (*error) {
            NSLog( @"failed with error: %@", *error );
        }

        BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:SIGNALS_DIRECTORY
                                                 withIntermediateDirectories:YES
                                                                  attributes:nil
                                                                       error:error];
        if (!created) {
            NSLog( @"createDirectoryAtPath:... failed with error: %@", *error );
        }

        NSString *basename = [NSString stringWithFormat: @"%@.json", safename];
        NSString *file     = [SIGNALS_DIRECTORY stringByAppendingPathComponent: basename];

        // doesn't overwrite file
        BOOL success = [json writeToURL:[NSURL fileURLWithPath: file]
                                options:NSDataWritingAtomic
                                  error:error];
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
                IRSignals *_signals = [[%c(IRSignals) alloc] init];
                [_signals loadFromStandardUserDefaultsKey:@"signals"];

                int index = -1;
                NSMutableArray *asDictionary = [NSMutableArray array];
                for (unsigned int i = 0; i < [_signals countOfSignals]; i++) {
                    IRSignal *_signal =  [_signals objectInSignalsAtIndex:i];
                    asDictionary[i] = [_signal asDictionary];
                    if ([dict[@"md5"] isEqualToString:[asDictionary[i][@"name"] md5]]) {
                        index = i;
                    }
                }
                NSLog(@"%s: success index: %d", __func__, index);
                if (index == -1) {
                    return @{ @"success": @(NO) };
                }
                IRSignal *_signal =  [_signals objectInSignalsAtIndex:index];

                [_signal sendWithCompletion:^(NSError *error) {
                    if (!error) {
                        NSLog( @"sent with error: %@", error );
                    }
                }];
                return @{ @"success": @(YES) };
            }
            
            return nil;
        }];
    }
}