//
//  UIImage+IRKit.m
//  IRKit for Activator
//
//  Created by kinda on 10.08.2014.
//  Copyright (c) 2014 kinda. All rights reserved.
//

@implementation UIImage (IRKit)

- (UIImage *) makeThumbnailOfSize:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    // draw scaled image into thumbnail context
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newThumbnail = UIGraphicsGetImageFromCurrentImageContext();        
    // pop the context
    UIGraphicsEndImageContext();
    
    return newThumbnail;
}

@end