//
//  UKMoosepionageSpyObject.m
//  Moosepionage
//
//  Created by Uli Kusterer on 18.03.07.
//  Copyright 2007 M. Uli Kusterer. All rights reserved.
//

#import "UKMoosepionageSpyObject.h"
#import "NSAppleEventDescriptor+AESend.h"


@implementation UKMoosepionageSpyObject

+(void)	load
{
	NSString*	bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if( [bundleID isEqualToString: @"com.ulikusterer.cocoamoose"] )
	{
		NSLog(@"UKMoosepionageSpyObject got loaded into %@, not installing notifications.", bundleID);
		return;
	}
	
	NSLog(@"UKMoosepionageSpyObject got loaded into %@", bundleID);
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowBroughtToFront:) name: NSWindowDidBecomeMainNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowWillBeginSheet:) name: NSWindowWillBeginSheetNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowDidResize:) name: NSWindowDidResizeNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowDidMiniaturize:) name: NSWindowDidMiniaturizeNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowDidDeminiaturize:) name: NSWindowDidDeminiaturizeNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(drawerDidOpen:) name: NSDrawerDidOpenNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(drawerWillClose:) name: NSDrawerWillCloseNotification object: nil];
}


+(void)	windowBroughtToFront: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" was activated.", [[notif object] title] );
	
	if( [[notif object] styleMask] & NSTexturedBackgroundWindowMask )
		[self haveMooseSpeakFromCategory: @"METAL WINDOW ACTIVATED" withFiller: [[notif object] title]];
	else
		[self haveMooseSpeakFromCategory: @"WINDOW ACTIVATED" withFiller: [[notif object] title]];
}


+(void)	windowWillBeginSheet: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" showed a sheet.", [[notif object] title] );
	
	[self haveMooseSpeakFromCategory: @"WINDOW SHOWED SHEET" withFiller: [[notif object] title]];
}


+(void)	windowDidResize: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" was resized.", [[notif object] title] );
	
	[self haveMooseSpeakFromCategory: @"WINDOW RESIZED" withFiller: [[notif object] title]];
}


+(void)	drawerDidOpen: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" opened a drawer.", [[[notif object] parentWindow] title] );
	
	[self haveMooseSpeakFromCategory: @"DRAWER OPENED" withFiller: [[[notif object] parentWindow] title]];
}


+(void)	drawerWillClose: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" closed a drawer.", [[[notif object] parentWindow] title] );
	
	[self haveMooseSpeakFromCategory: @"DRAWER CLOSED" withFiller: [[[notif object] parentWindow] title]];
}


+(void)	windowDidMiniaturize: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" was miniaturized.", [[notif object] title] );
	
	if( [[notif object] styleMask] & NSTexturedBackgroundWindowMask )
		[self haveMooseSpeakFromCategory: @"METAL WINDOW MINIATURIZED" withFiller: [[notif object] title]];
	else
		[self haveMooseSpeakFromCategory: @"WINDOW MINIATURIZED" withFiller: [[notif object] title]];
}


+(void)	windowWillDeminiaturize: (NSNotification*)notif
{
	NSLog( @"Window \"%@\" was deminiaturized.", [[notif object] title] );
	
	if( [[notif object] styleMask] & NSTexturedBackgroundWindowMask )
		[self haveMooseSpeakFromCategory: @"METAL WINDOW DEMINIATURIZED" withFiller: [[notif object] title]];
	else
		[self haveMooseSpeakFromCategory: @"WINDOW DEMINIATURIZED" withFiller: [[notif object] title]];
}


+(void)	haveMooseSpeakFromCategory: (NSString*)cat withFiller: (NSString*)fill
{
	if( !fill )
		return;
		
	NSAppleEventDescriptor	*	application = [NSAppleEventDescriptor descriptorWithDescriptorType: typeApplicationBundleID
														 data: [@"com.ulikusterer.cocoamoose" dataUsingEncoding:NSUTF8StringEncoding]];
	NSAppleEventDescriptor	*	theEvent = [NSAppleEventDescriptor appleEventWithEventClass: 'MOOS' eventID: 'TALK'
												targetDescriptor: application
												returnID: kAutoGenerateReturnID transactionID: kAnyTransactionID];
	NSAppleEventDescriptor	*	theFillString = [NSAppleEventDescriptor descriptorWithString: fill];
	NSAppleEventDescriptor	*	theCatString = [NSAppleEventDescriptor descriptorWithString: cat];
	
	[theEvent setParamDescriptor: theCatString forKeyword: 'theC'];
	[theEvent setParamDescriptor: theFillString forKeyword: 'theF'];

	[theEvent sendEvent];
}

@end
