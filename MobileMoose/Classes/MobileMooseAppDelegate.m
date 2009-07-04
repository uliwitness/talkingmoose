//
//  MobileMooseAppDelegate.m
//  MobileMoose
//
//  Created by Uli Kusterer on 12.07.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import "MobileMooseAppDelegate.h"
#import "MobileMooseViewController.h"

@implementation MobileMooseAppDelegate

@synthesize window;
@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {	
	
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
