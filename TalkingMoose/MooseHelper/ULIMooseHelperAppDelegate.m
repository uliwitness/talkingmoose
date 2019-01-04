//
//  AppDelegate.m
//  MooseHelper
//
//  Created by Uli Kusterer on 04.01.19.
//  Copyright © 2019 The Void Software. All rights reserved.
//

#pragma mark Headers

#import "ULIMooseHelperAppDelegate.h"
#import "UKRecordedSpeechChannel.h"
#import "UKMooseDragAreaView.h"
#import "UKPhraseDatabase.h"
#import "UKMooseController.h"
#import "UKMooseDragAreaView.h"
#import "UKIdleTimer.h"
#import "UKSpeechSettingsView.h"
#import "UKHelperMacros.h"
#import "UKBorderlessWindow.h"
#import "UKCrashReporter.h"
#import "UKGroupFile.h"
#import "NSImage+NiceScaling.h"


#define UKUserAnimationsPath    "/Library/Application Support/Moose/Animations"
#define UKUserPhrasesPath       "/Library/Application Support/Moose/Phrases"
#define MINIMUM_MOOSE_SIZE		48


#pragma mark -

@interface ULIMooseHelperAppDelegate ()
{
	NSMutableArray*							mooseControllers;		// List of all available moose controllers.
	IBOutlet NSImageView*					imageView;				// Image view where current moose is displayed.
	IBOutlet NSView*						windowWidgets;			// Zoom box and grow box that we unhide when mouse enters our window.
	IBOutlet UKPhraseDatabase*				phraseDB;				// All phrases.
	UKMooseController*						currentMoose;			// Moose controller currently in use.
	NSSpeechSynthesizer*					speechSynth;			// The synthesizer the current moose is lip-syncing with.
	UKIdleTimer*							phraseTimer;			// Timer that calls us whenever a new phrase should be spoken.
	int										mooseDisableCount;		// If zero, moose may speak, if > 0, moose should stay quiet.
	BOOL									terminateWhenFinished;  // Set to YES to quit after "goodbye" speech has finished.
	IBOutlet NSTextView*					speechBubbleView;		// Display text being spoken here.
	BOOL									showSpokenString;		// Display text being spoken?
	int										mooseVisibleCount;      // Visible-counter for showMoose/hideMoose. Moose window is hidden only when this becomes 0.
	NSTimer*								clockTimer;             // Timer that's set to fire on full/half hours.
	float									scaleFactor;            // By how much the current moose animation window should be enlarged/made smaller.
	NSView*									windowWidgetsSuperview;	// View to reinsert windowWidgets in again to show it on 10.2.
	BOOL									speakOnVolumeMount;
	BOOL									speakOnAppLaunchQuit;
	BOOL									speakOnAppChange;
	IBOutlet UKMooseDragAreaView*			dragArea;
	BOOL									didSetDragAreaCursor;
	UKRecordedSpeechChannel*				recSpeechSynth;
	BOOL									isSilenced;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation ULIMooseHelperAppDelegate

- (id)init {
	self = [super init];
	if( self )
	{
		srand((unsigned int)time(NULL));
		
		phraseTimer = [[UKIdleTimer alloc] initWithTimeInterval: 30];
		[phraseTimer setDelegate: self];
		mooseControllers = [[NSMutableArray alloc] init];

		// Speech channel:
		speechSynth = [[NSSpeechSynthesizer alloc] init];
		NSDictionary*   settings = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKSpeechChannelSettings"];
		if( settings )
		{
			//UKLog(@"Loading Speech settings from Prefs.");
			[speechSynth setSettingsDictionary: settings];
		}
		else
			; //UKLog(@"No Speech settings in Prefs.");
		
		[speechSynth startSpeakingString: @""]; // Make sure everything's loaded and ready.
		
		recSpeechSynth = [[UKRecordedSpeechChannel alloc] init];

		// Start listening for interesting user actions:
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

		// Set up a timer to fire every half hour for clock announcements:
		clockTimer = [[NSTimer scheduledTimerWithTimeInterval: 60 * 30
													   target: self selector: @selector(halfHourElapsed:)
													 userInfo: [NSDictionary dictionary] repeats: YES] retain];
		[self updateClockTimerFireTime: clockTimer];
		
		[self setScaleFactor: 1];	// Make sure Moose doesn't start out 0x0 pixels large.
	}
	return self;

}


-(void) dealloc
{
	DESTROY(recSpeechSynth);
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
	
	DESTROY(clockTimer);
	DESTROY(phraseTimer);
	DESTROY(speechSynth);
	
	[super dealloc];
}


-(void) awakeFromNib
{
	UKCrashReporterCheckForCrash();
	
	// Set up our moose window:
	NSWindow*   mooseWindow = [imageView window];
	
	[mooseWindow setBackgroundColor: [NSColor clearColor]];
	[mooseWindow setOpaque: NO];
	[((UKBorderlessWindow*)mooseWindow) setConstrainRect: YES];
	[mooseWindow setLevel: kCGOverlayWindowLevel];
	[mooseWindow setHidesOnDeactivate: NO];
	[mooseWindow setCanHide: NO];
	if( [mooseWindow respondsToSelector: @selector(setCollectionBehavior:)] )
		[(id)mooseWindow setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
	
	// Get window scale factor from Prefs:
	float savedScaleFactor = [[NSUserDefaults standardUserDefaults] floatForKey: @"UKMooseScaleFactor"];
	if( savedScaleFactor <= 0 )
		savedScaleFactor = 1;
	
	[self loadMooseControllers];
	[self setScaleFactor: savedScaleFactor];
	
	// Load settings from user defaults:
	[self setUpSpeechBubbleWindow];
	
	// Hide widgets on 10.2:
	[windowWidgets setHidden: YES];
}


-(void)	setScaleFactor: (float)sf
{
	scaleFactor = sf;
	
	NSWindow    *wd = [imageView window];
	NSRect      oldBox = [wd frame];
	NSSize      imgSize = [[currentMoose image] size];
	
	imgSize.width *= sf;
	imgSize.height *= sf;
	
	oldBox.origin.y -= imgSize.height -oldBox.size.height;
	oldBox.size = imgSize;
	
	[wd setFrame: oldBox display: YES];
	[currentMoose setGlobalFrame: oldBox];
}


-(float)	scaleFactor
{
	return scaleFactor;
}


-(void)	loadMooseControllers
{
	NSString*   currAnim = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKCurrentMooseAnimationPath"];
	
	// Load built-in animations and those in the two library folders:
	[self loadAnimationsInFolder: @"~" UKUserAnimationsPath];
	[self loadAnimationsInFolder: @"" UKUserAnimationsPath];
	[self loadAnimationsInFolder: [[NSBundle mainBundle] pathForResource: @"Animations" ofType: nil]];
	
	// Activate the animation the prefs indicate we last used, or a default one if the one in prefs not found:
	NSEnumerator*       enny = [mooseControllers objectEnumerator];
	UKMooseController*  aMoose;
	int                 x = 0, currMooseIndex = 0, defaultMooseIndex = 0;
	BOOL				foundMoose = NO;
	NSString*			defaultMoose = NSLocalizedString(@"DEFAULT_ANIMATION",@"Default Animation's name");
	
	while( (aMoose = [enny nextObject]) )
	{
		if( [[aMoose filePath] isEqualToString: currAnim] )
		{
			currMooseIndex = x;
			foundMoose = YES;
			break;
		}
		if( [[aMoose name] isEqualToString: defaultMoose] )
			defaultMooseIndex = x;
		x++;
	}
	
	if( !foundMoose )	// Moose in prefs doesn't exist? Use default!
		currMooseIndex = defaultMooseIndex;
	
	currentMoose = mooseControllers[currMooseIndex];
}


// -----------------------------------------------------------------------------
//	Set up all those properties our window for displaying phrase text needs:
// -----------------------------------------------------------------------------

-(void)		setUpSpeechBubbleWindow
{
	//UKLog(@"About to set up.");
	UKBorderlessWindow*		speechBubbleWindow = (UKBorderlessWindow*) [speechBubbleView window];
	
	[speechBubbleWindow setBackgroundColor: [NSColor clearColor]];
	[speechBubbleWindow setOpaque: NO];
	[speechBubbleWindow setHasShadow: YES];
	[speechBubbleWindow setConstrainRect: YES];
	[speechBubbleWindow setLevel: kCGOverlayWindowLevel];
	[speechBubbleWindow setHidesOnDeactivate: NO];
	[speechBubbleWindow setCanHide: NO];
	[speechBubbleView setTextContainerInset: NSMakeSize(4,6)];
	//UKLog(@"Finished.");
}


-(void) applicationDidFinishLaunching: (NSNotification*)notif
{
	// Force update of Moose, even when we can't say "hello":
	[self mooseControllerAnimationDidChange: currentMoose];
	
	// Position Moose window:
	NSString*	animPos = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseAnimPosition"];
	if( animPos )
	{
		//UKLog(@"didFinishLaunching: Moose position will be set to: %@",animPos);
		[(UKBorderlessWindow*)[imageView window] setConstrainRect: YES];
		NSRect		mooseBox, oldMooseBox;
		mooseBox.origin = NSPointFromString( animPos );
		mooseBox.size = [[imageView window] frame].size;
		oldMooseBox = mooseBox;
		mooseBox = [[imageView window] constrainFrameRect: mooseBox toScreen: [[imageView window] screen]];
		//UKLog(@"didFinishLaunching: Constraining %@ to %@",NSStringFromRect( oldMooseBox ),NSStringFromRect( mooseBox ));
		[[imageView window] setFrameOrigin: mooseBox.origin];
	}
	
	// Say hello to the user:
	[self speakPhraseFromGroup: @"HELLO"];
	
#if 0
	int	*	crashy = 0;
	(*crashy) = 1;
#endif
}


-(NSApplicationTerminateReply)  applicationShouldTerminate:(NSApplication *)sender
{
	if( mooseDisableCount == 0 /*![excludeApps appInListMatches] && ![excludeApps screenSaverRunning]*/ )
	{
		terminateWhenFinished = YES;	// This causes didFinishSpeaking: to call replyToApplicationShouldTerminate.
		if( [speechSynth isSpeaking] || [recSpeechSynth isSpeaking] || [self speakPhraseFromGroup: @"GOODBYE"] )
			return NSTerminateLater;
		else
			return NSTerminateNow;	// No speech output busy, and we couldn't speak a "Goodbye" phrase. Just quit quietly, and right away.
	}
	else
	{
		return NSTerminateNow;
	}
}


-(void) applicationWillTerminate: (NSNotification*)notif
{
	NSString*		moosePosString = NSStringFromPoint( [[imageView window] frame].origin );
	//UKLog( @"applicationWillTerminate: Saving position: %@", moosePosString );
	[[NSUserDefaults standardUserDefaults] setObject: moosePosString forKey: @"UKMooseAnimPosition"];
	[[NSUserDefaults standardUserDefaults] setObject: [speechSynth settingsDictionary] forKey: @"UKSpeechChannelSettings"];
	[[NSUserDefaults standardUserDefaults] setFloat: [self scaleFactor] forKey: @"UKMooseScaleFactor"];
}


-(void) loadAnimationsInFolder: (NSString*)folder
{
	NSString*			animFolder = [folder stringByExpandingTildeInPath];
	NSEnumerator*		enny = [[[NSFileManager defaultManager] directoryContentsAtPath: animFolder] objectEnumerator];
	NSString*			currPath = nil;
	
	while( (currPath = [enny nextObject]) )
	{
		if( [currPath characterAtIndex:0] == '.' )
			continue;
		if( ![[currPath pathExtension] isEqualToString: @"nose"] )
			continue;
		
		currPath = [animFolder stringByAppendingPathComponent: currPath];
		
		NS_DURING
		[self loadAnimationAtPath: currPath andReload: NO];
		NS_HANDLER
		NSLog( @"Error: %@", localException );
		NS_ENDHANDLER
	}
}


-(UKMooseController*) loadAnimationAtPath: (NSString*)animationPath andReload: (BOOL)reloadList
{
	UKMooseController* newController = [[[UKMooseController alloc] initWithAnimationFile: animationPath] autorelease];
	[mooseControllers addObject: newController];
	
	return newController;
}


-(void) setMooseSilenced: (BOOL)doSilence
{
	if( isSilenced != doSilence )
		[self silenceMoose: self];
}


-(BOOL) mooseSilenced
{
	return isSilenced;
}


-(void) updateClockTimerFireTime: (NSTimer*)timer
{
	NSCalendarDate* calDate = [NSDate distantFuture];
	NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
	
	if( [ud boolForKey: @"UKMooseSpeakTime"] )
	{
		int             year;
		unsigned int	month, day, hour, minute, second;
		NSTimeZone*     zone;
		calDate = [NSCalendarDate calendarDate];
		
		year = [calDate yearOfCommonEra];
		month = [calDate monthOfYear];
		day = [calDate dayOfMonth];
		hour = [calDate hourOfDay];
		minute = [calDate minuteOfHour];
		second = [calDate secondOfMinute];
		zone = [calDate timeZone];
		
		unsigned int    randNum = (unsigned int) rand();
		int             minAdd = (randNum & 0x00000007),		// Low 3 bits: 0...7
		secAdd = (randNum & 0x00000070) >> 4;	// 3 bits: 0...7
		
		if( minute >= 30 || ![ud boolForKey: @"UKMooseSpeakTimeOnHalfHours"] )
		{
			minute = 0;
			hour++;
			
			if( hour >= 24 )
			{
				hour = 0;
				
				// Add 1 day to the date:
				calDate = [NSCalendarDate dateWithYear: year month: month day: day
												  hour: hour minute: minute second: second timeZone: zone];
				calDate = [calDate dateByAddingYears: 0 months: 0 days: 1 hours: 0 minutes: 0 seconds: 0];
				
				year = [calDate yearOfCommonEra];
				month = [calDate monthOfYear];
				day = [calDate dayOfMonth];
				hour = [calDate hourOfDay];
				minute = [calDate minuteOfHour];
				second = [calDate secondOfMinute];
				zone = [calDate timeZone];
			}
		}
		else
			minute = 30;
		
		if( [ud boolForKey: @"UKMooseSpeakTimeAnallyRetentive"] )
			second = 0;
		
		calDate = [NSCalendarDate dateWithYear: year month: month day: day
										  hour: hour minute: minute second: second timeZone: zone];
		
		if( ![ud boolForKey: @"UKMooseSpeakTimeAnallyRetentive"] )
			calDate = [calDate dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: minAdd seconds: secAdd];
	}
	else
		calDate = [NSCalendarDate distantFuture];
	
	[timer setFireDate: calDate];
	//UKLog( @"Actual fire time: %@", [timer fireDate] );
}


-(void) halfHourElapsed: (NSTimer*)timer
{
	NS_DURING
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	
	if( !speechSynth )
		[NSException raise: @"UKHalfHourElapsedNoChannel" format: @"Speech channel is NIL in halfHourElapsed:"];
	
	if( ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
	{
		NSString*			timeFmtStr = @"%I:%M";
		if( !timeFmtStr )
			[NSException raise: @"UKHalfHourElapsedNoTimeFmtStr" format: @"Time Format String is NIL in halfHourElapsed:"];
		NSDateFormatter*    form = [[[NSDateFormatter alloc] initWithDateFormat: timeFmtStr allowNaturalLanguage: NO] autorelease];
		if( !form )
			[NSException raise: @"UKHalfHourElapsedNoDateFrm" format: @"Date Formatter is NIL in halfHourElapsed:"];
		
		NSString*			timeStr = [form stringForObjectValue: [NSDate date]];
		if( !timeStr )
			[NSException raise: @"UKHalfHourElapsedNoTimeStr" format: @"Time String is NIL in halfHourElapsed:"];
		[self speakPhraseFromGroup: @"TIME ANNOUNCEMENT" withFillerString: timeStr];
		
		//UKLog( @"Speaking time: %@", timeStr );
	}
	[self updateClockTimerFireTime: timer];
	
	[pool release];
	NS_HANDLER
	NSLog(@"Error during time announcement: %@", localException);
	NS_ENDHANDLER
}


-(IBAction)	interruptMoose: (id)sender
{
	[speechSynth stopSpeaking];
	[recSpeechSynth stopSpeaking];
	// Reset visible count to make sure it goes away.
	mooseVisibleCount = 1;
	[self hideMoose];
}


// Called by click on moose image:
-(IBAction) mooseAnimationWindowClicked: (id)sender
{
	BOOL        dragInstead = NO;
	
	NSEvent *currEvent = [NSApplication.sharedApplication nextEventMatchingMask: NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp untilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5] inMode: NSEventTrackingRunLoopMode dequeue: NO];
	if (currEvent.type != NSEventTypeLeftMouseDragged) {
		dragInstead = YES;
	}
	
	if( dragInstead )
	{
		[self dragMooseAnimationWindow: sender];   // Call title bar drag method instead.
		return;
	}
	
	[self interruptMoose: self];
}


-(IBAction) resizeMoose: (id)sender
{
	NSWindow    *wd = [imageView window];
	NSSize      imgSize = [[imageView image] size],
	mooseSize = [currentMoose size];
	NSRect      oldBox = [wd frame],
	newBox = [wd frame];
	NSEvent*    currEvt = nil;
	
	//UKLog(@"About to call showMoose");
	[self showMoose];
	[wd setContentAspectRatio: mooseSize];
	
	while( YES )
	{
		currEvt = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
									 untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		if( currEvt && [currEvt type] == NSLeftMouseUp )
			break;
		
		oldBox.size.width += [currEvt deltaX];
		oldBox.origin.y = oldBox.origin.y +oldBox.size.height -[currEvt deltaY];
		oldBox.size.height = oldBox.size.height +[currEvt deltaY];
		
		NSSize		newSize = [NSImage scaledSize: imgSize toFitSize: oldBox.size];
		if( newSize.width < MINIMUM_MOOSE_SIZE || newSize.height < MINIMUM_MOOSE_SIZE )
			newSize = [NSImage scaledSize: imgSize toFitSize: NSMakeSize( MINIMUM_MOOSE_SIZE, MINIMUM_MOOSE_SIZE )];
		newBox.size.width = newSize.width;
		newBox.origin.y = newBox.origin.y +newBox.size.height -newSize.height;
		newBox.size.height = newSize.height;
		
		[wd setFrame: newBox display: YES];
		[currentMoose setGlobalFrame: newBox];
	}
	
	[wd setContentAspectRatio: NSMakeSize( 1, 1 )];
	[self setScaleFactor: newBox.size.width / mooseSize.width];
	
	[self pinWidgetsBoxToBotRight];
	[self hideMoose];
}


-(IBAction) zoomMoose: (id)sender
{
	[self setScaleFactor: 1];
}


// Called by click in window's "title bar" drag area:
-(IBAction) dragMooseAnimationWindow: (id)sender
{
	NSPoint		mousePos = [NSEvent mouseLocation];
	NSPoint		posDiff = [[imageView window] frame].origin;
	NSEvent*	evt = nil;
	
	posDiff.x -= mousePos.x;
	posDiff.y -= mousePos.y;
	
	//UKLog(@"About to call showMoose");
	[self showMoose];
	
	[[NSCursor closedHandCursor] push];
	
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
	
	[[NSCursor closedHandCursor] pop];
	
	[self hideMoose];
}


-(void) timerBeginsIdling: (id)sender
{
	[self speakOnePhrase: sender];
}


-(void) timerContinuesIdling: (id)sender
{
	[self speakOnePhrase: sender];
}


-(BOOL) speakOnePhrase: (id)sender
{
	return [self speakPhraseFromGroup: @"PAUSE"];
}


-(BOOL) speakPhraseFromGroup: (NSString*)group
{
	return [self speakPhraseFromGroup: group withFillerString: nil];
}


// Speaks the next phrase from the specified group, optionally replacing any "%s" placeholders
//	in that string with a filler string. Used to e.g. allow the Moose to say the name of a disk ejected.
-(BOOL) speakPhraseFromGroup: (NSString*)group withFillerString: (NSString*)fill
{
	if( mooseDisableCount == 0
	   && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] /*&& ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning]*/ )
	{
		NSString*		currPhrase = [phraseDB randomPhraseFromGroup: group];
		if( !currPhrase )
			return NO;
		
		NSRange			strRange = [currPhrase rangeOfString: @"%s"];
		
		if( fill && (strRange.location != NSNotFound) )
		{
			currPhrase = [[currPhrase mutableCopy] autorelease];
			[(NSMutableString*)currPhrase replaceCharactersInRange: strRange withString: fill];
			[phraseDB setMostRecentPhrase: currPhrase];	// We changed the string, so tell phrase DB about the string we actually spoke, with the placeholder filled.
		}
		
		NSDictionary*	cmdDict = UKGroupFileExtractCommandFromPhrase( currPhrase );
		if( !cmdDict )
		{
			NSDictionary*	voiceAttrs = [NSSpeechSynthesizer attributesForVoice: [speechSynth voice]];
			BOOL	voiceCantDoPhonemes = [self voiceCantProvidePhonemesJudgingByAttributes: voiceAttrs];
			
			[currentMoose setSimulateMissingPhonemes: voiceCantDoPhonemes];
			
			if( voiceCantDoPhonemes )
				[currentMoose speechStartedWithoutPhonemes];
			
			[speechSynth startSpeakingString: currPhrase];
			[self showSpeechBubbleWithString: currPhrase];
		}
		else
		{
			NSString*	methodName = [NSString stringWithFormat: @"embeddedPhraseCommand%@:", [cmdDict objectForKey: UKGroupFileCommandNameKey]];
			SEL			methodSelector = NSSelectorFromString( methodName );
			if( [self respondsToSelector: methodSelector] )
				[self performSelector: methodSelector withObject: [cmdDict objectForKey: UKGroupFileCommandArgsKey]];
			else
				return NO;
		}
		
		return YES;
	}
	else
		return NO;
}


-(void)	embeddedPhraseCommandSOUNDFILE: (NSArray*)args
{
	if( [args count] >= 1 )
	{
		NSString*	fPath = [[NSBundle mainBundle] pathForSoundResource: [args objectAtIndex: 0]];
		[recSpeechSynth startSpeakingSoundFileAtPath: fPath];
	}
}


-(BOOL)	voiceCantProvidePhonemesJudgingByAttributes: (NSDictionary*)voiceAttrs
{
	BOOL	voiceCantDoPhonemes = NO;
	NSString*phonemes = [speechSynth phonemesFromText: @"Texas"];
	if( [phonemes length] == 0 )
		return YES;
	
	return voiceCantDoPhonemes;
}


-(void) speakString: (NSString*)currPhrase
{
	if( mooseDisableCount == 0 /*&& ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning]*/ )
	{
		NSDictionary*	voiceAttrs = [NSSpeechSynthesizer attributesForVoice: [speechSynth voice]];
		BOOL	voiceCantDoPhonemes = [self voiceCantProvidePhonemesJudgingByAttributes: voiceAttrs];
		[currentMoose setSimulateMissingPhonemes: voiceCantDoPhonemes];
		
		if( voiceCantDoPhonemes )
			[currentMoose speechStartedWithoutPhonemes];
		
		[speechSynth startSpeakingString: currPhrase];
		[self showSpeechBubbleWithString: currPhrase];
		//UKLog(@"Speaking: %@", currPhrase);
	}
}

-(void) showSpeechBubbleWithString: (NSString*)currPhrase
{
	if( showSpokenString )
	{
		//UKLog(@"About to position.");
		NSWindow*		bubbleWin = [speechBubbleView window];
		NSWindow*		mooseWin = [imageView window];
		NSRect			mooseFrame = [mooseWin frame];
		NSRect			bubbleFrame = [bubbleWin frame];
		//NSDictionary*   attrs = [NSDictionary dictionaryWithObjectsAndKeys: [[NSColor whiteColor] colorWithAlphaComponent: 0.8], NSBackgroundColorAttributeName, nil];
		
		[mooseWin removeChildWindow: bubbleWin];
		
		[speechBubbleView setString: [NSSpeechSynthesizer prettifyString: currPhrase]];
		//[[speechBubbleView textStorage] setAttributes: attrs range: NSMakeRange(0,[currPhrase length])];
		[speechBubbleView setAlignment: NSCenterTextAlignment];
		
		[speechBubbleView setMinSize: NSMakeSize(16,16)];
		[speechBubbleView setMaxSize: NSMakeSize(300,10000)];
		[speechBubbleView sizeToFit];
		
		// Position bubble to right of Moose:
		bubbleFrame.size = [speechBubbleView frame].size;
		bubbleFrame.origin = NSMakePoint(mooseFrame.origin.x +mooseFrame.size.width +8,
										 mooseFrame.origin.y -(bubbleFrame.size.height /2) +(mooseFrame.size.height /2));
		
		// Check whether text fits on screen, if not, try left side:
		NSRect		visibleBubbleFrame = [bubbleWin constrainFrameRect: bubbleFrame toScreen: [mooseWin screen]];
		if( visibleBubbleFrame.origin.x != bubbleFrame.origin.x
		   || visibleBubbleFrame.origin.y != bubbleFrame.origin.y )
		{
			NSRect newBubbleFrame = bubbleFrame;
			newBubbleFrame.origin = NSMakePoint(mooseFrame.origin.x -8 -bubbleFrame.size.width,
												mooseFrame.origin.y -(bubbleFrame.size.height /2) +(mooseFrame.size.height /2));
			
			visibleBubbleFrame = [bubbleWin constrainFrameRect: newBubbleFrame toScreen: [[imageView window] screen]];
			if( visibleBubbleFrame.origin.x != newBubbleFrame.origin.x
			   || visibleBubbleFrame.origin.y != newBubbleFrame.origin.y )		// Left side still not onscreen? Fallback: Just go back to original frame rect, even though it may be on top of Moose.
				bubbleFrame = [bubbleWin constrainFrameRect: bubbleFrame toScreen: [[imageView window] screen]];
			else
				bubbleFrame = visibleBubbleFrame;
		}
		else
			bubbleFrame = visibleBubbleFrame;
		
		// Actually assign frame we found and display Moose:
		[bubbleWin setFrame: bubbleFrame display: YES];
		/*if( fadeInOut )
		 [bubbleWin fadeInWithDuration: 0.5];
		 else
		 [bubbleWin orderFrontRegardless];*/
		//UKLog(@"Positioned at %@ for moose frame %@.",NSStringFromRect( bubbleFrame ),NSStringFromRect( mooseFrame ));
		
		[mooseWin addChildWindow: bubbleWin ordered: NSWindowAbove];
	}
	else
		;//UKLog(@"showSpokenString == false");
}


-(void) repeatLastPhrase: (id)sender
{
	if( mooseDisableCount == 0 )
	{
		NSString*   currPhrase = [phraseDB mostRecentPhrase];
		if( !currPhrase )
			return;
		
		NSDictionary*	voiceAttrs = [NSSpeechSynthesizer attributesForVoice: [speechSynth voice]];
		BOOL	voiceCantDoPhonemes = [self voiceCantProvidePhonemesJudgingByAttributes: voiceAttrs];
		
		[currentMoose setSimulateMissingPhonemes: voiceCantDoPhonemes];
		
		if( voiceCantDoPhonemes )
			[currentMoose speechStartedWithoutPhonemes];
		
		[speechSynth startSpeakingString: currPhrase];
		if( showSpokenString )
		{
			[speechBubbleView setString: currPhrase];
			[[speechBubbleView window] fadeInWithDuration: 0.5];
		}
	}
}


-(void) silenceMoose: (id)sender
{
	if( isSilenced )
		mooseDisableCount--;
	else
		mooseDisableCount++;
	
	isSilenced = !isSilenced;
	[self interruptMoose: self];
}


-(void) mooseControllerDidChange
{
	//UKLog(@"mooseControllerDidChange");
	
	NSWindow*		mooseWindow = [imageView window];
	
#ifdef TRYTOKEEPPOSITION
	NSRect		oldWBox = [mooseWindow frame];
	oldWBox.origin = [mooseWindow convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	NSRect		wBox = oldWBox;
	wBox.size = [currentMoose size];
	wBox.origin.y += oldWBox.size.height;	// These two pin it to upper left.
	wBox.origin.y -= wBox.size.height;
	//UKLog(@"mooseControllerDidChange (1): Old: %@ New: %@", NSStringFromRect([mooseWindow frame]), NSStringFromRect(wBox));
	[mooseWindow setFrame: wBox display: YES];
	[currentMoose setGlobalFrame: wBox];
#else
	NSSize      wdSize = [currentMoose size];
	//UKLog(@"mooseControllerDidChange: currentMoose: %@",currentMoose);
	//[self setScaleFactor: 1.0];
	//[mooseWindow setContentSize: wdSize];
	NSRect		wdBox;
	wdBox.origin = [mooseWindow frame].origin;
	wdBox.size = wdSize;
	wdBox = [mooseWindow constrainFrameRect: wdBox toScreen: [mooseWindow screen]];
	//UKLog(@"mooseControllerDidChange (2): Old: %@ New: %@", NSStringFromRect([mooseWindow frame]), NSStringFromRect(wdBox));
	[mooseWindow setFrame: wdBox display: YES];
	[currentMoose setGlobalFrame: wdBox];
#endif
	
	[currentMoose setDelegate: self];
	[speechSynth setDelegate: currentMoose];
	[recSpeechSynth setDelegate: currentMoose];
	[[NSUserDefaults standardUserDefaults] setObject: [currentMoose filePath] forKey: @"UKCurrentMooseAnimationPath"];
	
	// Make sure widgets are in lower right:
	[self pinWidgetsBoxToBotRight];
	//[currentMoose setDontIdleAnimate: NO];
	
	[self mooseControllerAnimationDidChange: currentMoose];
	
	//UKLog(@"Moose controller changed to \"%@\".", [currentMoose filePath]);
}


-(void)	pinWidgetsBoxToBotRight
{
	NSRect	widgetsBox = [windowWidgets frame],
	widgetsOwnerBox = [windowWidgetsSuperview frame];
	
	widgetsBox.origin.x = widgetsOwnerBox.size.width -widgetsBox.size.width;
	widgetsBox.origin.y = 0;
	[windowWidgets setFrameOrigin: widgetsBox.origin];
}


-(void) mooseControllerSpeechStart: (UKMooseController*)mc
{
	NSRect		wBox = [[imageView window] frame];
	wBox.origin = [[imageView window] convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	[currentMoose setGlobalFrame: wBox];
	
	//UKLog(@"About to call showMoose");
	[self showMoose];
}


-(void) mooseControllerAnimationDidChange: (UKMooseController*)mc
{
	NSImage*		currImg = [mc image];
	NSImage*		iconImg = [currImg scaledImageToFitSize: NSMakeSize(128,128)];
	NSWindow*		mooseWin = [imageView window];
	
	[NSApp setApplicationIconImage: iconImg];
	if( [mooseWin isVisible] )
	{
		[imageView setImage: currImg];
		//UKLog(@"Moose image changed.");
		//[mooseWin invalidateShadow];
		
		// Show/hide the window widgets if mouse is (not) in window:
		BOOL    hideWidgets = !NSPointInRect( [NSEvent mouseLocation], [mooseWin frame] );
		if( hideWidgets != [windowWidgets isHidden] )
			[windowWidgets setHidden: hideWidgets];
	}
	
	//UKLog(@"mooseControllerAnimationDidChange:");
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
	[self hideMoose];
	
	if( terminateWhenFinished )
	{
		[NSApp replyToApplicationShouldTerminate: YES];
		//UKLog(@"finished speaking, resuming quit.");
	}
	
	//UKLog(@"finished.");
}


-(void)	speakPhraseOnMainThreadFromGroup: (NSString*)grp withFillerString:(NSString*)fill
{
	// Filler must be last, may be NIL!
	NSDictionary*	vals = [[NSDictionary alloc] initWithObjectsAndKeys: grp, @"Group", fill, @"Filler", nil];
	
	[self performSelectorOnMainThread:@selector(speakPhraseFromDictionary:) withObject:vals waitUntilDone: YES];
	
	[vals release];
}


// Keys in dictionary: "Group" (required) and "Filler" (optional):
-(void)	speakPhraseFromDictionary: (NSDictionary*)dict
{
	[self speakPhraseFromGroup: [dict objectForKey: @"Group"] withFillerString: [dict objectForKey: @"Filler"]];
}


-(void) volumeMountNotification:(NSNotification*)notif
{
	if( speakOnVolumeMount )
	{
		NSString*		volName = [[[notif userInfo] objectForKey: @"NSDevicePath"] lastPathComponent];
		[self speakPhraseOnMainThreadFromGroup: @"INSERT DISK" withFillerString: volName];
	}
}


-(void) volumeUnmountNotification:(NSNotification*)notif
{
	if( speakOnVolumeMount )
	{
		NSString*		volName = [[[notif userInfo] objectForKey: @"NSDevicePath"] lastPathComponent];
		[self speakPhraseOnMainThreadFromGroup: @"EJECT DISK" withFillerString: volName];
	}
}


-(void) applicationLaunchNotification:(NSNotification*)notif
{
	if( speakOnAppLaunchQuit )
	{
		NSString*		appName = [[[[notif userInfo] objectForKey: @"NSApplicationName"] retain] autorelease];
		
		if( ![appName isEqualToString: @"ScreenSaverEngine"]
		   && ![appName isEqualToString: @"ScreenSaverEngin"] )
			[self speakPhraseOnMainThreadFromGroup: @"LAUNCH APPLICATION" withFillerString: appName];
	}
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) applicationTerminationNotification:(NSNotification*)notif
{
	if( speakOnAppLaunchQuit )
	{
		NSString*		appName = [[[[notif userInfo] objectForKey: @"NSApplicationName"] retain] autorelease];
		if( ![appName isEqualToString: @"ScreenSaverEngine"]
		   && ![appName isEqualToString: @"ScreenSaverEngin"] )
			[self speakPhraseOnMainThreadFromGroup: @"QUIT APPLICATION" withFillerString: appName];
	}
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) applicationSwitchNotification:(NSNotification*)notif
{
	//UKLog(@"applicationSwitchNotification");
	if( speakOnAppChange )
	{
		// Don't speak if we're switching to this app, so the two methods bwlow get their shot:
		NSDictionary*	activeAppDict = [[NSWorkspace sharedWorkspace] activeApplication];
		if( ![[activeAppDict objectForKey: @"NSApplicationPath"] isEqualToString: [[NSBundle mainBundle] bundlePath]] )
		{
			NSString*		appName = [[[activeAppDict objectForKey: @"NSApplicationName"] retain] autorelease];
			[self speakPhraseOnMainThreadFromGroup: @"CHANGE APPLICATION" withFillerString: appName];
		}
	}
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) fastUserSwitchedInNotification:(NSNotification*)notif
{
	mooseDisableCount--;
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseOnMainThreadFromGroup: @"USER SWITCHED IN" withFillerString: nil];
}


-(void) fastUserSwitchedOutNotification:(NSNotification*)notif
{
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseOnMainThreadFromGroup: @"USER SWITCHED OUT" withFillerString: nil];
	mooseDisableCount++;
}


-(void)     hideMoose
{
	mooseVisibleCount--;
	
	//UKLog( @"Hiding Moose (%d)", mooseVisibleCount );
	
	if( mooseVisibleCount < 0 )
		mooseVisibleCount = 0;
	
	if( mooseVisibleCount == 0 )
	{
		//[currentMoose setDontIdleAnimate: NO];
		//UKLog( @"\tHit zero. Fading out." );
		[[imageView window] fadeOutWithDuration: 0.5];
		[[speechBubbleView window] fadeOutWithDuration: 0.5];
	}
}


-(void)     showMoose
{
	NSWindow*		mooseWin = [imageView window];
	
	mooseVisibleCount++;
	
	//UKLog( @"Showing Moose (%d)", mooseVisibleCount );
	//UKLogBacktrace();
	
	if( mooseVisibleCount < 0 )
		mooseVisibleCount = 0;
	
	if( mooseVisibleCount == 1 )
	{
		// Make sure it's onscreen:
		NSRect		oldMooseFrame = [mooseWin frame],
		mooseFrame = oldMooseFrame;
		mooseFrame = [mooseWin constrainFrameRect: mooseFrame toScreen: [mooseWin screen]];
		if( mooseFrame.origin.x != oldMooseFrame.origin.x || mooseFrame.origin.y != oldMooseFrame.origin.y
		   || mooseFrame.size.width != oldMooseFrame.size.width || mooseFrame.size.height != oldMooseFrame.size.height )
		{
			//UKLog(@"constraining moose rect %@ to %@", NSStringFromRect( oldMooseFrame ), NSStringFromRect( mooseFrame ));
			[mooseWin setFrame: mooseFrame display: YES];
		}
		else
			;//UKLog(@"no need to constrain rect %@.",NSStringFromRect( mooseFrame ));
		
		// Now actually show the Moose window:
		//UKLog( @"\tHit 1. Fading in." );
		[mooseWin fadeInWithDuration: 0.5];
		if( showSpokenString )
			[[speechBubbleView window] fadeInWithDuration: 0.5];
		//[currentMoose setDontIdleAnimate: NO];
		[self pinWidgetsBoxToBotRight];
	}
	else
		;//UKLog(@"Not 1, leaving window untouched.");
	[mooseWin invalidateShadow];
}

@end
