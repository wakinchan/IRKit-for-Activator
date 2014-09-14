//
//  UIImage+IRKit.h
//  IRKit for Activator
//
//  Created by kinda on 10.08.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (IRKit)

- (UIImage *)makeThumbnailOfSize:(CGSize)size;
- (UIImage *)makeCornerRoundImage;

@end