//
//  UKMooseAppDelegate.m
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKMooseAppDelegate.h"
#import "UKMooseController.h"
#import "UKPhraseDatabase.h"
#import "NSImageNiceScaling.h"
#import "UKSpeechSettingsView.h"
#import "UKSpeechSynthesizer.h"
#import "UKIdleTimer.h"
#import "UKBorderlessWindow.h"
#import "NSArray+Color.h"
#import "PTHotKey.h"
#import "PTKeyComboPanel.h"
#import "RemoveLoginItem.h"


@implementation UKMooseAppDelegate

-(id) init
{
	self = [super init];
	if( self )
	{
		srand(time(NULL));
		
		phraseTimer = [[UKIdleTimer alloc] initWithTimeInterval: 30];
		[phraseTimer setDelegate: self];
		mooseControllers = [[NSMutableArray alloc] init];
		speechSynth = [[UKSpeechSynthesizer alloc] init];
		
		NSDictionary*   settings = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKSpeechChannelSettings"];
		if( settings )
			[speechSynth setSettingsDictionary: settings];
	
		[speechSynth startSpeakingString: @""]; // Make sure everything's loaded and ready.
		
		speakNowHotkey = [[PTHotKey alloc] initWithName: @"Speak Now" target: self action: @selector(speakOnePhrase:) addToCenter: YES];
		repeatLastPhraseHotkey = [[PTHotKey alloc] initWithName: @"Repeat Last Phrase" target: self action: @selector(repeatLastPhrase:) addToCenter: YES];
		silenceMooseHotkey = [[PTHotKey alloc] initWithName: @"Silence, Moose!" target: self action: @selector(silenceMoose:) addToCenter: YES];

		NSNotificationCenter*   nc = [[NSWorkspace sharedWorkspace] notificationCenter];
		[nc addObserver: self selector:@selector(volumeMountNotification:)
				name: NSWorkspaceDidMountNotification object: nil];
		[nc addObserver: self selector:@selector(volumeUnmountNotification:)
				name: NSWorkspaceWillUnmountNotification object: nil];
		[nc addObserver: self selector:@selector(applicationLaunchNotification:)
				name: NSWorkspaceDidLaunchApplicationNotification object: nil];
		[nc addObserver: self selector:@selector(applicationTerminationNotification:)
				name: NSWorkspaceDidTerminateApplicationNotification object: nil];
		[nc addObserver: self selector:@selector(fastUserSwitchedInNotification:)
				name: NSWorkspaceSessionDidBecomeActiveNotification object: nil];
		[nc addObserver: self selector:@selector(fastUserSwitchedOutNotification:)
				name: NSWorkspaceSessionDidResignActiveNotification object: nil];
	}
	
	return self;
}

-(void) dealloc
{
	[speakNowHotkey release];
	[repeatLastPhraseHotkey release];
	[silenceMooseHotkey release];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
	
	[phraseTimer release];
	[mooseControllers release];
	[speechSynth release];
	
	[super dealloc];
}


-(void) awakeFromNib
{
	NSWindow*   mooseWindow = [imageView window];
	int			currMooseRow = 0, theRow;
	
	[mooseWindow setBackgroundColor: [NSColor clearColor]];
	[mooseWindow setOpaque: NO];
	[((UKBorderlessWindow*)mooseWindow) setConstrainRect: YES];
	[mooseWindow setLevel: NSFloatingWindowLevel];
	[mooseWindow setHidesOnDeactivate: NO];
	
	[speakNowHKField setStringValue: [speakNowHotkey stringValue]];
	[repeatLastPhraseHKField setStringValue: [repeatLastPhraseHotkey stringValue]];
	[silenceMooseHKField setStringValue: [silenceMooseHotkey stringValue]];
	
	NSString*		bundlePath = [[NSBundle mainBundle] bundlePath];
	
	if( GetLoginItemIndex( kCurrentUser, [bundlePath fileSystemRepresentation] ) != -1 )
		[launchAtLoginSwitch setState: YES];
	
	theRow = [self loadAnimationsInFolder: [[NSBundle mainBundle] pathForResource: @"Animations" ofType: nil]];
	if( theRow != 0 )
		currMooseRow = theRow;
	theRow = [self loadAnimationsInFolder: @"/Library/Application Support/Moose/Animations"];
	if( theRow != 0 )
		currMooseRow = theRow;
	theRow = [self loadAnimationsInFolder: @"~/Library/Application Support/Moose/Animations"];
	if( theRow != 0 )
		currMooseRow = theRow;

	[speechSets setSpeechSynthesizer: speechSynth];
	[mooseList reloadData];
	[mooseList selectRow: currMooseRow byExtendingSelection: NO];
	
	NSString*   bgImageName = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndImage"];
	if( bgImageName != nil )
		[imagePopup selectItemWithTitle: bgImageName];
	[self backgroundImageDidChange: self];
	
	NSColor*	theColor = [[[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndStartColor"] colorValue];
	if( theColor != nil )
		[startColor setColor: theColor];
	[self takeStartColorFrom: startColor];

	theColor = [[[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndEndColor"] colorValue];
	if( theColor != nil )
		[endColor setColor: theColor];
	[self takeEndColorFrom: endColor];
	
	NSNumber* delay = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseSpeechDelay"];
	if( delay != nil )
		[speechDelaySlider setDoubleValue: [delay doubleValue]];
	[self takeSpeechDelayFrom: speechDelaySlider];
	
	
	NSNumber*   num = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMoosePanelVisible"];
	if( !num || [num boolValue] )
		[[mooseList window] makeKeyAndOrderFront: self];
	
	NSNumber*   sspks = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseShowSpokenString"];
	showSpokenString = (sspks && [sspks boolValue]);
	[showSpokenStringSwitch setState: showSpokenString];
	
	NSWindow*		speechBubbleWindow = [speechBubbleView window];
	[speechBubbleWindow setBackgroundColor: [NSColor clearColor]];
	[speechBubbleWindow setOpaque: NO];
	[speechBubbleWindow setConstrainRect: YES];
	[speechBubbleWindow setLevel: NSFloatingWindowLevel];
	[speechBubbleWindow setHidesOnDeactivate: NO];
}


-(void) applicationDidFinishLaunching: (NSNotification*)notif
{
	[self speakPhraseFromGroup: @"HELLO"];
}


-(NSApplicationTerminateReply)  applicationShouldTerminate:(NSApplication *)sender
{
	if( mooseDisableCount == 0 )
	{
		[self speakPhraseFromGroup: @"GOODBYE"];
		terminateWhenFinished = YES;
		
		return NSTerminateLater;
	}
	else
		return NSTerminateNow;
}


-(void) applicationWillTerminate: (NSNotification*)notif
{
	[[NSUserDefaults standardUserDefaults] setObject: [speechSynth settingsDictionary] forKey: @"UKSpeechChannelSettings"];
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: [[mooseList window] isVisible]] forKey: @"UKMoosePanelVisible"];
}


-(int) loadAnimationsInFolder: (NSString*)folder
{
	NSString*			currAnimPath = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKCurrentMooseAnimationPath"];
	NSString*			animFolder = [folder stringByExpandingTildeInPath];
	NSEnumerator*		enny = [[[NSFileManager defaultManager] directoryContentsAtPath: animFolder] objectEnumerator];
	NSString*			currPath = nil;
	UKMooseController*  newController = nil;
	int					x = [mooseControllers count], currMooseRow = 0;
	
	while( (currPath = [enny nextObject]) )
	{
		if( [currPath characterAtIndex:0] == '.' )
			continue;
		if( ![[currPath pathExtension] isEqualToString: @"nose"] )
			continue;
		
		currPath = [animFolder stringByAppendingPathComponent: currPath];
		
		newController = [[[UKMooseController alloc] initWithAnimationFile: currPath] autorelease];
		[mooseControllers addObject: newController];
		
		if( !currentMoose || [currAnimPath isEqualToString: currPath] )
		{
			currentMoose = newController;
			currMooseRow = x;
			if( currAnimPath == nil )
				[[NSUserDefaults standardUserDefaults] setObject: currPath forKey: @"UKCurrentMooseAnimationPath"];
		}
		
		x++;
	}
	
	return currMooseRow;
}


-(void) timerBeginsIdling: (id)sender
{
	[self speakOnePhrase: sender];
}


-(void) timerContinuesIdling: (id)sender
{
	[self speakOnePhrase: sender];
}


-(void) mooseImageClicked: (id)sender
{
	NSPoint		mousePos = [NSEvent mouseLocation];
	NSPoint		posDiff = [[imageView window] frame].origin;
	NSEvent*	evt = nil;
	
	posDiff.x -= mousePos.x;
	posDiff.y -= mousePos.y;
	
	while( true )
	{
		evt = [NSApp nextEventMatchingMask: (NSLeftMouseUpMask | NSLeftMouseDraggedMask)
				untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode
				dequeue:YES];
		if( !evt )
			continue;
		
		if( [evt type] == NSLeftMouseUp )
			break;
		
		mousePos = [NSEvent mouseLocation];
		mousePos.x += posDiff.x;
		mousePos.y += posDiff.y;
		
		[[imageView window] setFrameOrigin: mousePos];
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [mooseControllers count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [[mooseControllers objectAtIndex: row] valueForKey: [tableColumn identifier]];
}


- (void)tableViewSelectionDidChange: (NSNotification *)notification
{
	[currentMoose setDelegate: nil];
	
	currentMoose = [mooseControllers objectAtIndex: [mooseList selectedRow]];
	
	[self mooseControllerDidChange];
}


-(void) takeStartColorFrom: (id)sender
{
	NSEnumerator*		enny = [mooseControllers objectEnumerator];
	NSString*			imgName = [imagePopup titleOfSelectedItem];
	NSColor*			theCol = [sender color];
	UKMooseController*  mc = nil;
	
	while( (mc = [enny nextObject]) )
	{
		[mc setStartColor: theCol];
		[mc setBackgroundImage: imgName];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSArray arrayWithColor: theCol] forKey: @"UKMooseBkgndStartColor"];
}


-(void) takeEndColorFrom: (id)sender
{
	NSEnumerator*		enny = [mooseControllers objectEnumerator];
	NSString*			imgName = [imagePopup titleOfSelectedItem];
	NSColor*			theCol = [sender color];
	UKMooseController*  mc = nil;
	
	while( (mc = [enny nextObject]) )
	{
		[mc setEndColor: theCol];
		[mc setBackgroundImage: imgName];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSArray arrayWithColor: theCol] forKey: @"UKMooseBkgndEndColor"];
}


-(void) speakOnePhrase: (id)sender
{
	[self speakPhraseFromGroup: @"PAUSE"];
}


-(void) speakPhraseFromGroup: (NSString*)group
{
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] )
	{
		NSString*		currPhrase = [phraseDB randomPhraseFromGroup: group];
		[speechSynth startSpeakingString: currPhrase];
		if( showSpokenString )
		{
			NSWindow*		bubbleWin = [speechBubbleView window];
			NSWindow*		mooseWin = [imageView window];
			NSRect			mooseFrame = [mooseWin frame];
			NSRect			bubbleFrame = [bubbleWin frame];
			//NSDictionary*   attrs = [NSDictionary dictionaryWithObjectsAndKeys: [[NSColor whiteColor] colorWithAlphaComponent: 0.8], NSBackgroundColorAttributeName, nil];
			
			[speechBubbleView setString: [UKSpeechSynthesizer prettifyString: currPhrase]];
			//[[speechBubbleView textStorage] setAttributes: attrs range: NSMakeRange(0,[currPhrase length])];
			[speechBubbleView setAlignment: NSCenterTextAlignment];
			
			[speechBubbleView setMinSize: NSMakeSize(16,16)];
			[speechBubbleView setMaxSize: NSMakeSize(300,1000)];
			[speechBubbleView sizeToFit];
			bubbleFrame.size = [speechBubbleView frame].size;
			bubbleFrame.origin = NSMakePoint(mooseFrame.origin.x +mooseFrame.size.width +8,
											mooseFrame.origin.y -(bubbleFrame.size.height /2) +(mooseFrame.size.height /2));
			
			[bubbleWin setFrame: bubbleFrame display: NO];
			[bubbleWin orderFront: nil];
		}
	}
}


-(void) repeatLastPhrase: (id)sender
{
	if( mooseDisableCount == 0 )
	{
		NSString*   currPhrase = [phraseDB mostRecentPhrase];
		[speechSynth startSpeakingString: currPhrase];
		if( showSpokenString )
		{
			[speechBubbleView setString: currPhrase];
			[[speechBubbleView window] orderFront: nil];
		}
	}
}


-(void) silenceMoose: (id)sender
{
	static BOOL		isSilenced = NO;
	
	if( isSilenced )
		mooseDisableCount--;
	else
		mooseDisableCount++;
	
	isSilenced = !isSilenced;
	[shutUpSwitch setState: isSilenced];
	[speechSynth stopSpeaking];
}


-(void) changeSpeakOnePhraseHotkey: (id)sender
{
	[[PTKeyComboPanel sharedPanel] runModalForHotKey: speakNowHotkey];
	[speakNowHotkey writeToStandardDefaults];
	[speakNowHKField setStringValue: [speakNowHotkey stringValue]];
}


-(void) changeRepeatLastPhraseHotkey: (id)sender
{
	[[PTKeyComboPanel sharedPanel] runModalForHotKey: repeatLastPhraseHotkey];
	[repeatLastPhraseHotkey writeToStandardDefaults];
	[repeatLastPhraseHKField setStringValue: [repeatLastPhraseHotkey stringValue]];
}


-(void) changeSilenceMooseHotkey: (id)sender
{
	[[PTKeyComboPanel sharedPanel] runModalForHotKey: silenceMooseHotkey];
	[silenceMooseHotkey writeToStandardDefaults];
	[silenceMooseHKField setStringValue: [silenceMooseHotkey stringValue]];
}


-(void) takeSpeechDelayFrom: (id)sender
{
	double		theVal = [sender doubleValue];
	
	[phraseTimer release];
	phraseTimer = [[UKIdleTimer alloc] initWithTimeInterval: theVal];
	[phraseTimer setDelegate: self];
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithDouble: theVal] forKey: @"UKMooseSpeechDelay"];
	
	[speechDelayField setStringValue: [NSString stringWithFormat: @"Every %d min.", ((int)trunc(theVal /60.0))]];
}


-(void) takeLaunchAtLoginBoolFrom: (id)sender
{
	NSString*		bundlePath = [[NSBundle mainBundle] bundlePath];
	
	if( GetLoginItemIndex( kCurrentUser, [bundlePath fileSystemRepresentation] ) == -1 )
		AddLoginItemWithPropertiesToUser( kCurrentUser, [bundlePath fileSystemRepresentation], kDoNotHideOnLaunch );
	else
		RemoveLoginItem( kCurrentUser, [bundlePath fileSystemRepresentation] );
}


-(void) takeShowSpokenStringBoolFrom: (id)sender
{
	showSpokenString = [sender state];
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: showSpokenString] forKey: @"UKMooseShowSpokenString"];
}


-(void) backgroundImageDidChange: (id)sender
{
	NSEnumerator*		enny = [mooseControllers objectEnumerator];
	UKMooseController*  mc = nil;
	NSString*			imgName = [imagePopup titleOfSelectedItem];
	
	while( (mc = [enny nextObject]) )
		[mc setBackgroundImage: imgName];
	
	[[NSUserDefaults standardUserDefaults] setObject: imgName forKey: @"UKMooseBkgndImage"];
}


-(void) mooseControllerDidChange
{
	#ifdef TRYTOKEEPPOSITION
	NSRect		oldWBox = [[imageView window] frame];
	oldWBox.origin = [[imageView window] convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	NSRect		wBox = oldWBox;
	wBox.size = [currentMoose size];
	wBox.origin.y += oldWBox.size.height;	// These two pin it to upper left.
	wBox.origin.y -= wBox.size.height;
	[[imageView window] setFrame: wBox display: NO];
	[currentMoose setGlobalFrame: wBox];
	#else
	[[imageView window] setContentSize: [currentMoose size]];
	[currentMoose setGlobalFrame: [[imageView window] frame]];
	#endif
	
	[currentMoose setDelegate: self];
	[speechSynth setDelegate: currentMoose];
	[[NSUserDefaults standardUserDefaults] setObject: [currentMoose filePath] forKey: @"UKCurrentMooseAnimationPath"];
	
	NSString*   bgImageName = [[[imagePopup titleOfSelectedItem] retain] autorelease];
	[imagePopup removeAllItems];
	[imagePopup addItemsWithTitles: [currentMoose backgroundImages]];
	[imagePopup selectItemWithTitle: bgImageName];
	
	[self mooseControllerAnimationDidChange: nil];
}


-(void) mooseControllerSpeechStart: (UKMooseController*)mc
{
	NSRect		wBox = [[imageView window] frame];
	wBox.origin = [[imageView window] convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	[currentMoose setGlobalFrame: wBox];

	[[imageView window] orderFront: nil];
}


-(void) mooseControllerAnimationDidChange: (UKMooseController*)mc
{
	NSImage*		currImg = [mc image];
	NSImage*		iconImg = [currImg scaledImageToFitSize: NSMakeSize(128,128)];
	
	if( [[imageView window] isVisible] )
		[imageView setImage: currImg];
	[NSApp setApplicationIconImage: iconImg];
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
	[[imageView window] orderOut: nil];
	[[speechBubbleView window] orderOut: nil];
	
	if( terminateWhenFinished )
		[NSApp replyToApplicationShouldTerminate: YES];
}

-(void) volumeMountNotification:(NSNotification*)notif
{
	[self speakPhraseFromGroup: @"INSERT DISK"];
}


-(void) volumeUnmountNotification:(NSNotification*)notif
{
	[self speakPhraseFromGroup: @"EJECT DISK"];
}


-(void) applicationLaunchNotification:(NSNotification*)notif
{
	[self speakPhraseFromGroup: @"LAUNCH APPLICATION"];
}


-(void) applicationTerminationNotification:(NSNotification*)notif
{
	[self speakPhraseFromGroup: @"QUIT APPLICATION"];
}


-(void) fastUserSwitchedInNotification:(NSNotification*)notif
{
	mooseDisableCount--;
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] )
		[self speakPhraseFromGroup: @"USER SWITCHED IN"];
}


-(void) fastUserSwitchedOutNotification:(NSNotification*)notif
{
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] )
		[self speakPhraseFromGroup: @"USER SWITCHED OUT"];
	mooseDisableCount++;
}


@end
