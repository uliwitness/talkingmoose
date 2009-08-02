//
//  iPhroxyAppDelegate.m
//  iPhroxy
//
//  Created by Uli Kusterer on 17.11.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import "iPhroxyAppDelegate.h"
#import "iPhroxyViewController.h"

@implementation iPhroxyAppDelegate

@synthesize window;
@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	// Override point for customization after app launch	
    [window addSubview:viewController.view];
	[window makeKeyAndVisible];
}


- (void)dealloc {
    [viewController release];
	[window release];
	[super dealloc];
}


@end
