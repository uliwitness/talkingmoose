//
//  UKConvertAnimationAppDelegate.h
//  ConvertAnimation
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface UKConvertAnimationAppDelegate : NSObject
{
	IBOutlet NSImageView*			imageView;
	IBOutlet NSProgressIndicator*   progress;
	IBOutlet NSTextField*			status;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;

@end
