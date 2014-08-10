//
//  IRKitSubstrate_Activator.xm
//  IRKit for Activator
//
//  Created by kinda on 15.04.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

#import <objcipc/objcipc.h>
#import "../Headers.h"
#import "../NSString+Hashes.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.plist"
#define IMAGE_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.image.plist"
#define MD5_PREFS_PATH @"/var/mobile/Library/Preferences/com.kindadev.activator.irkit.md5.plist"

@interface SSSettingsViewController : UITableViewController
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
    [exportBtn addTarget:self action:@selector(exportIRKitSettings:) forControlEvents:UIControlEventTouchUpInside];
    [exportBtn setTitle:@"Export" forState:UIControlStateNormal];
    UIBarButtonItem* exportItem = [[UIBarButtonItem alloc] initWithCustomView:exportBtn];
    self.navigationItem.rightBarButtonItem = exportItem;
}

%new
- (void)exportIRKitSettings:(id)sender
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

        UIImage *image = [UIImage new];
        NSString *type = asDictionary[i][@"custom"][@"type"];
        if ([type isEqualToString:@"preset"]) {
            NSString *name = asDictionary[i][@"custom"][@"name"];
            image = [UIImage imageNamed:[NSString stringWithFormat:@"btn_icon_120_%@", name]];
            
        } else if ([type isEqualToString:@"album"]) {
            NSString *dir = asDictionary[i][@"custom"][@"dir"];
            NSString *path = [NSString stringWithFormat:@"%@/120.png", dir];
            image = MakeCornerRoundImage([UIImage imageWithContentsOfFile:path]);
        }
        NSData *data = [[[NSData alloc] initWithData:UIImagePNGRepresentation(image)] autorelease];
        images[i] = data;
    }

    [asDictionary writeToFile:PREFS_PATH atomically:YES];
    [images writeToFile:IMAGE_PREFS_PATH atomically:YES]; // xxx: do not use.
    [md5Lists writeToFile:MD5_PREFS_PATH atomically:YES];

    [[[UIAlertView alloc] initWithTitle:@"Export `IRKit for Activator` settings." message:nil delegate:nil cancelButtonTitle:@"success." otherButtonTitles:nil] show];
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
                    NSString *md5 = [asDictionary[i][@"name"] md5];
                    if ([dict[@"md5"] isEqualToString:md5]) {
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