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
//#import "NSWindow+Fade.h"
#import "UKApplicationListController.h"
#import "ULIMooseServiceProtocol.h"


#define UKMainApplicationID		@"com.thevoidsoftware.talkingmoose.macosx"
#define STRINGIFY2(n)			@"" #n
#define STRINGIFY(n)			STRINGIFY2(n)
#define UKUserAnimationsPath    "/Library/Application Support/Moose/Animations"
#define UKUserPhrasesPath      	"/Library/Application Support/Moose/Phrases"
#define MINIMUM_MOOSE_SIZE		48


#pragma mark -

@interface ULIMooseHelperAppDelegate () <NSXPCListenerDelegate, ULIMooseServiceProtocol>
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
	IBOutlet ULIApplicationList*			excludeApps;			// List of apps that cause the Moose to go quiet.
	NSView*									windowWidgetsSuperview;	// View to reinsert windowWidgets in again to show it on 10.2.
	BOOL									speakOnVolumeMount;
	BOOL									speakOnAppLaunchQuit;
	BOOL									speakOnAppChange;
	IBOutlet UKMooseDragAreaView*			dragArea;
	BOOL									didSetDragAreaCursor;
	UKRecordedSpeechChannel*				recSpeechSynth;
	BOOL									isSilenced;
	NSTimeInterval							speechDelay;
	NSTimeInterval							lastSpeakTime;
	
    NSUserDefaults							*_sharedDefaults;
	
	NSXPCListener 							*_xpcListener;
}

@property (weak) IBOutlet NSWindow *window;

@property (strong) id<NSObject> appNapDeactivatingActivity;

@end

@implementation ULIMooseHelperAppDelegate

- (id)init {
	self = [super init];
	if( self )
	{
		srand((unsigned int)time(NULL));

		mooseControllers = [[NSMutableArray alloc] init];
		_sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName: STRINGIFY(UKApplicationGroupID)];
		//UKLog(@"%@: %@ %@", STRINGIFY(UKApplicationGroupID), _sharedDefaults, _sharedDefaults.dictionaryRepresentation);
		speechSynth = [[NSSpeechSynthesizer alloc] init];
		recSpeechSynth = [[UKRecordedSpeechChannel alloc] init];
		
		[self reloadSettings];

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
		[nc addObserver: self selector:@selector(applicationSwitchNotification:)
				   name: NSWorkspaceDidActivateApplicationNotification object: nil];
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
	DESTROY(_xpcListener);
	
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
	
	ProcessSerialNumber myPSN = { 0, kCurrentProcess };
	TransformProcessType( &myPSN, kProcessTransformToUIElementApplication );
	
	// Set up our moose window:
	NSWindow*   mooseWindow = [imageView window];
	
	[mooseWindow setBackgroundColor: [NSColor clearColor]];
	[mooseWindow setOpaque: NO];
	[((UKBorderlessWindow*)mooseWindow) setConstrainRect: YES];
	[((UKBorderlessWindow*)mooseWindow) setCanBecomeKeyWindow: YES];
	[((UKBorderlessWindow*)mooseWindow) setCanBecomeMainWindow: YES];
	[mooseWindow setLevel: kCGOverlayWindowLevel];
	[mooseWindow setHidesOnDeactivate: NO];
	[mooseWindow setCanHide: NO];
	[mooseWindow setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorFullScreenDisallowsTiling];
	[mooseWindow setAnimationBehavior: NSWindowAnimationBehaviorNone];
	[mooseWindow setAlphaValue: 1.0];

	// Get window scale factor from Prefs:
	float savedScaleFactor = [_sharedDefaults floatForKey: @"UKMooseScaleFactor"];
	if( savedScaleFactor <= 0 )
		savedScaleFactor = 1;
	
	[self loadMooseControllers];
	[self setScaleFactor: savedScaleFactor];
	
	// Load settings from user defaults:
	[self setUpSpeechBubbleWindow];
	
	// Hide widgets on 10.2:
	[windowWidgets setHidden: YES];
	
	[self startXPCService];
}


#pragma mark - XPC -

-(void) startXPCService
{
	UKLog(@"Starting xpcServiceThread");
	
	// Set up the one NSXPCListener for this service. It will handle all incoming connections.
	NSString *serviceName = NSBundle.mainBundle.bundleIdentifier;
	_xpcListener = [[NSXPCListener alloc] initWithMachServiceName: serviceName];
	_xpcListener.delegate = self;
	
	// Resuming the serviceListener starts this service. This method does not return.
	[_xpcListener resume];
	
	UKLog(@"Service %@ started with listener: [%@]", serviceName, _xpcListener);
}


- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
	// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
	
	// Configure the connection.
	// First, set the interface that the exported object implements.
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ULIMooseServiceProtocol)];
	
	// Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
	id<ULIMooseServiceProtocol> exportedObject = (id<ULIMooseServiceProtocol>)NSApplication.sharedApplication.delegate;
	newConnection.exportedObject = exportedObject;
	
	// Resuming the connection allows the system to deliver more incoming messages.
	[newConnection resume];
	
	// Returning YES from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call -invalidate on the connection and return NO.
	return YES;
}


-(void)	reloadSettings
{
	// Delay:
	NSNumber* delay = [_sharedDefaults objectForKey: @"UKMooseSpeechDelay"];
	if( delay != nil ) {
		speechDelay = [delay doubleValue];
	} else {
		speechDelay = 30.0;
	}
	
	NSNumber*   sspks = [_sharedDefaults objectForKey: @"UKMooseShowSpokenString"];
	UKLog(@"%@", sspks);
	showSpokenString = (sspks && [sspks boolValue]);
	
	NSNumber*   sovms = [_sharedDefaults objectForKey: @"UKMooseSpeakOnVolumeMount"];
	UKLog(@"%@", sovms);
	speakOnVolumeMount = sovms == nil || [sovms boolValue]; // Defaults to on.
	
	NSNumber*   soalqs = [_sharedDefaults objectForKey: @"UKMooseSpeakOnAppLaunchQuit"];
	UKLog(@"%@", soalqs);
	speakOnAppLaunchQuit = soalqs == nil || [soalqs boolValue]; // Defaults to on.
	
	NSNumber*   soacs = [_sharedDefaults objectForKey: @"UKMooseSpeakOnAppChange"];
	UKLog(@"%@", soacs);
	speakOnAppChange = soacs == nil || [soacs boolValue]; // Defaults to on.
	
	if (phraseTimer) {
		[phraseTimer release];
	}
	phraseTimer = [[UKIdleTimer alloc] initWithTimeInterval: speechDelay];
	[phraseTimer setDelegate: self];
	
	
	// Speech channel:
	NSDictionary*   settings = [_sharedDefaults objectForKey: @"UKSpeechChannelSettings"];
	UKLog(@"%@", settings);
	if( settings )
	{
		//UKLog(@"Loading Speech settings from Prefs.");
		[speechSynth setSettingsDictionary: settings];
	}
	else
		; //UKLog(@"No Speech settings in Prefs.");
}


-(void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls
{
	for (NSURL *currURL in urls) {
		UKLog(@"URL: %@", currURL);
		if ([currURL.scheme caseInsensitiveCompare: @"x-moose"] == NSOrderedSame) {
			UKLog(@"scheme match");
			if ([currURL.host caseInsensitiveCompare: @"settings"] == NSOrderedSame) {
				UKLog(@"settings");
				if ([currURL.path caseInsensitiveCompare: @"/reload"] == NSOrderedSame) {
					UKLog(@"reload");
					[self activateMooseController];
					[self reloadSettings];
				} else {
					UKLog(@"\"%@\"", currURL.path);
				}
			} else if ([currURL.host caseInsensitiveCompare: @"speak"] == NSOrderedSame) {
				NSString *msg = @"";
				if ([msg hasPrefix:@"/"]) {
					msg = [msg substringFromIndex: 1];
				}
				[self speakString: msg];
			} else if ([currURL.host caseInsensitiveCompare: @"speak-group"] == NSOrderedSame) {
				NSString *msg = @"";
				if ([msg hasPrefix:@"/"]) {
					msg = [msg substringFromIndex: 1];
				}
				[self speakPhraseFromGroup: msg withFillerString: @""];
			} else {
				UKLog(@"\"%@\" | \"%@\"", currURL.host, currURL.path);
			}
		} else {
			UKLog(@"Unknown scheme \"%@\"", currURL.scheme);
		}
	}
}


#pragma mark - Properties -


-(void)	setScaleFactor: (float)sf
{
	scaleFactor = sf;
	UKLog(@"scaleFactor: %f", scaleFactor);
	
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
	// Load built-in animations and those in the two library folders:
	[self loadAnimationsInFolder: @"~" UKUserAnimationsPath];
	[self loadAnimationsInFolder: @"" UKUserAnimationsPath];
	[self loadAnimationsInFolder: [[NSBundle mainBundle] pathForResource: @"Animations" ofType: nil]];
	
	[self activateMooseController];
}


-(void)	activateMooseController
{
	if (currentMoose) {
		currentMoose.delegate = nil;
		currentMoose.dontIdleAnimate = YES;
	}
	
	NSString*   currAnim = [_sharedDefaults objectForKey: @"UKCurrentMooseAnimationPath"];
	
	UKLog(@"Attempting to load animation %@", currAnim);
	
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
	
	if( !foundMoose ) {	// Moose in prefs doesn't exist? Use default!
		currMooseIndex = defaultMooseIndex;
		UKLog(@"\tFalling back on animation %@", defaultMoose);
	}
	
	currentMoose = mooseControllers[currMooseIndex];
	currentMoose.delegate = self;
	currentMoose.dontIdleAnimate = NO;
	
	[self mooseControllerDidChange];
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
	NSString*	animPos = [_sharedDefaults objectForKey: @"UKMooseAnimPosition"];
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
	
	[speechSynth startSpeakingString: @""]; // Make sure everything's loaded and ready.
	[[imageView window] display];
	
	// Say hello to the user:
	[self performSelector: @selector(speakPhraseFromGroup:) withObject: @"HELLO" afterDelay: 0.0];
	
#if 0
	int	*	crashy = 0;
	(*crashy) = 1;
#endif
}


-(NSApplicationTerminateReply)  applicationShouldTerminate:(NSApplication *)sender
{
	if( mooseDisableCount == 0 && ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning] )
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
	UKLog( @"applicationWillTerminate: Saving position: %@", moosePosString );
	[_sharedDefaults setObject: moosePosString forKey: @"UKMooseAnimPosition"];
	[_sharedDefaults setObject: [speechSynth settingsDictionary] forKey: @"UKSpeechChannelSettings"];
	[_sharedDefaults setFloat: [self scaleFactor] forKey: @"UKMooseScaleFactor"];
}


-(void) loadAnimationsInFolder: (NSString*)folder
{
	NSError *err = nil;
	NSString *animFolder = [folder stringByExpandingTildeInPath];
	
	for (NSString * currPath in [NSFileManager.defaultManager contentsOfDirectoryAtPath: animFolder error: &err]) {
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
	NSDate* calDate = nil;
	
	if( [_sharedDefaults boolForKey: @"UKMooseSpeakTime"] )
	{
		NSCalendarUnit desiredUnits =	NSCalendarUnitEra |
										NSCalendarUnitYear |
										NSCalendarUnitMonth |
										NSCalendarUnitDay |
										NSCalendarUnitHour |
										NSCalendarUnitMinute |
										NSCalendarUnitSecond |
										NSCalendarUnitCalendar |
										NSCalendarUnitTimeZone;
		
		calDate = NSDate.date;
		NSCalendar *calendar = NSCalendar.currentCalendar;
		NSDateComponents *dateParts = [calendar components: desiredUnits fromDate: calDate];
		
		unsigned int    randNum = (unsigned int) rand();
		int             minAdd = (randNum & 0x00000007),		// Low 3 bits: 0...7
		secAdd = (randNum & 0x00000070) >> 4;	// 3 bits: 0...7
		
		if( dateParts.minute >= 30 || ![_sharedDefaults boolForKey: @"UKMooseSpeakTimeOnHalfHours"] )
		{
			dateParts.minute = 0;
			dateParts.hour += 1;
			
			if( dateParts.hour >= 24 )
			{
				dateParts.hour = 0;
				
				// Add 1 day to the date:
				calDate = [calendar dateFromComponents: dateParts];
				calDate = [calendar dateByAddingUnit: NSCalendarUnitHour value: 1 toDate: calDate options: NSCalendarWrapComponents];
				dateParts = [calendar components: desiredUnits fromDate: calDate];
			}
		}
		else
			dateParts.minute = 30;
		
		if( [_sharedDefaults boolForKey: @"UKMooseSpeakTimeAnallyRetentive"] )
			dateParts.second = 0;
		
		calDate = [calendar dateFromComponents: dateParts];

		if( ![_sharedDefaults boolForKey: @"UKMooseSpeakTimeAnallyRetentive"] ) {
			calDate = [calendar dateByAddingUnit: NSCalendarUnitMinute value: minAdd toDate: calDate options: NSCalendarWrapComponents];
			calDate = [calendar dateByAddingUnit: NSCalendarUnitSecond value: secAdd toDate: calDate options: NSCalendarWrapComponents];
		}
	}
	else
		calDate = [NSDate distantFuture];
	
	[timer setFireDate: calDate];
	UKLog( @"Actual fire time: %@", [timer fireDate] );
}


-(void) halfHourElapsed: (NSTimer*)timer
{
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	
	if( !speechSynth ) {
		NSLog(@"Speech channel is NIL in halfHourElapsed.");
		return;
	}
	
	if( ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
	{
		NSString*			timeFmtStr = @"%I:%M";
		NSDateFormatter*    form = [[[NSDateFormatter alloc] init] autorelease];
		form.dateFormat = timeFmtStr;
		NSString*			timeStr = [form stringForObjectValue: NSDate.date];
		if( timeStr ) {
			[self speakPhraseFromGroup: @"TIME ANNOUNCEMENT" withFillerString: timeStr];
		} else {
			NSLog(@"Time String is NIL in halfHourElapsed.");
		}
		
		UKLog( @"Speaking time: %@", timeStr );
	}
	[self updateClockTimerFireTime: timer];
	
	[pool release];
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
	if (currEvent.type != NSEventTypeLeftMouseUp) {
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
		currEvt = [NSApp nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged
									 untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		if( currEvt && [currEvt type] == NSEventTypeLeftMouseUp )
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
		evt = [NSApp nextEventMatchingMask: (NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged)
								 untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode
								   dequeue:YES];
		if( !evt )
			continue;
		
		if( [evt type] == NSEventTypeLeftMouseUp )
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


-(IBAction) speakOnePhrase: (id)sender
{
	[self speakPhraseFromGroup: @"PAUSE"];
}


-(BOOL) speakPhraseFromGroup: (NSString*)group
{
	return [self speakAndReturnIfPhraseFoundFromGroup: group withFillerString: nil];
}

-(void) speakPhraseFromGroup: (NSString*)group withFillerString: (NSString*)fill
{
	[self speakAndReturnIfPhraseFoundFromGroup: group withFillerString: fill];
}
// Speaks the next phrase from the specified group, optionally replacing any "%s" placeholders
//	in that string with a filler string. Used to e.g. allow the Moose to say the name of a disk ejected.
-(BOOL) speakAndReturnIfPhraseFoundFromGroup: (NSString*)group withFillerString: (NSString*)fill
{
	UKLog(@"speakPhraseFromGroup: %@ withFillerString: %@", group, fill);
	
	if( mooseDisableCount == 0
	   && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] && ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning] )
	{
		NSString*		currPhrase = [phraseDB randomPhraseFromGroup: group];
		if( !currPhrase ) {
			UKLog(@"\tNo phrase found.");
			return NO;
		}
		
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
			self.appNapDeactivatingActivity = [[NSProcessInfo processInfo] beginActivityWithOptions: NSActivityBackground | NSActivityAutomaticTerminationDisabled | NSActivitySuddenTerminationDisabled reason: @"Moose speaking."];
			UKLog(@"app nap = %@", self.appNapDeactivatingActivity);
			
			NSDictionary*	voiceAttrs = [NSSpeechSynthesizer attributesForVoice: [speechSynth voice]];
			BOOL	voiceCantDoPhonemes = [self voiceCantProvidePhonemesJudgingByAttributes: voiceAttrs];
			
			[currentMoose setSimulateMissingPhonemes: voiceCantDoPhonemes];
			
			lastSpeakTime = NSDate.timeIntervalSinceReferenceDate;

			if( voiceCantDoPhonemes )
				[currentMoose speechStartedWithoutPhonemes];
			
			UKLog(@"\tspeaking: %@", currPhrase);
			[speechSynth startSpeakingString: currPhrase];
			[self showSpeechBubbleWithString: currPhrase];
		}
		else
		{
			NSString*	methodName = [NSString stringWithFormat: @"embeddedPhraseCommand%@:", [cmdDict objectForKey: UKGroupFileCommandNameKey]];
			SEL			methodSelector = NSSelectorFromString( methodName );
			if( [self respondsToSelector: methodSelector] ) {
				UKLog(@"Executing embedded command %@", methodName);
				[self performSelector: methodSelector withObject: [cmdDict objectForKey: UKGroupFileCommandArgsKey]];
			} else {
				UKLog(@"Skipping unknown embedded command %@", methodName);
				return NO;
			}
		}
		
		return YES;
	}
	else {
		UKLog(@"Not allowed to speak right now.");
		return NO;
	}
}


-(void)	embeddedPhraseCommandSOUNDFILE: (NSArray*)args
{
	if( [args count] >= 1 )
	{
		UKLog(@"\tPlaying soundfile \"%@\"", args.firstObject);
		self.appNapDeactivatingActivity = [[NSProcessInfo processInfo] beginActivityWithOptions: NSActivityBackground | NSActivityAutomaticTerminationDisabled | NSActivitySuddenTerminationDisabled reason: @"Moose speaking."];
		UKLog(@"app nap = %@", self.appNapDeactivatingActivity);
		lastSpeakTime = NSDate.timeIntervalSinceReferenceDate;
		NSString*	fPath = [[NSBundle mainBundle] pathForSoundResource: args.firstObject];
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
	if( mooseDisableCount == 0 && ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning] )
	{
		self.appNapDeactivatingActivity = [[NSProcessInfo processInfo] beginActivityWithOptions: NSActivityBackground | NSActivityAutomaticTerminationDisabled | NSActivitySuddenTerminationDisabled reason: @"Moose speaking."];
		UKLog(@"app nap = %@", self.appNapDeactivatingActivity);

		NSDictionary*	voiceAttrs = [NSSpeechSynthesizer attributesForVoice: [speechSynth voice]];
		BOOL	voiceCantDoPhonemes = [self voiceCantProvidePhonemesJudgingByAttributes: voiceAttrs];
		[currentMoose setSimulateMissingPhonemes: voiceCantDoPhonemes];
		
		if( voiceCantDoPhonemes )
			[currentMoose speechStartedWithoutPhonemes];
		
		lastSpeakTime = NSDate.timeIntervalSinceReferenceDate;
		[speechSynth startSpeakingString: currPhrase];
		[self showSpeechBubbleWithString: currPhrase];
		UKLog(@"Speaking: %@", currPhrase);
	}
}

-(void) showSpeechBubbleWithString: (NSString*)currPhrase
{
	NSWindow*		bubbleWin = [speechBubbleView window];
	NSWindow*		mooseWin = [imageView window];
	if( showSpokenString )
	{
		//UKLog(@"About to position.");
		NSRect			mooseFrame = [mooseWin frame];
		NSRect			bubbleFrame = [bubbleWin frame];
		//NSDictionary*   attrs = [NSDictionary dictionaryWithObjectsAndKeys: [[NSColor whiteColor] colorWithAlphaComponent: 0.8], NSBackgroundColorAttributeName, nil];
		
		[mooseWin removeChildWindow: bubbleWin];
		
		[speechBubbleView setString: [NSSpeechSynthesizer prettifyString: currPhrase]];
		//[[speechBubbleView textStorage] setAttributes: attrs range: NSMakeRange(0,[currPhrase length])];
		[speechBubbleView setAlignment: NSTextAlignmentCenter];
		
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
		UKLog(@"bubbleWindow frame: %@", NSStringFromRect(bubbleFrame));
		[bubbleWin setFrame: bubbleFrame display: YES];
		
		[mooseWin addChildWindow: bubbleWin ordered: NSWindowAbove];
		[bubbleWin display];
	}
	else {
		[mooseWin removeChildWindow: bubbleWin];
		[bubbleWin orderOut: self];
	}
}


-(void) repeatLastPhrase
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
			//[[speechBubbleView window] fadeInWithDuration: 0.5];
			[speechBubbleView.window orderFront: self];
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
	UKLog(@"mooseControllerDidChange");
	
	NSWindow*		mooseWindow = [imageView window];
	
#ifdef TRYTOKEEPPOSITION
	NSRect		oldWBox = [mooseWindow frame];
	oldWBox.origin = [mooseWindow convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	NSRect		wBox = oldWBox;
	wBox.size = [currentMoose size];
	wBox.origin.y += oldWBox.size.height;	// These two pin it to upper left.
	wBox.origin.y -= wBox.size.height;
	UKLog(@"mooseControllerDidChange (1): Old: %@ New: %@", NSStringFromRect([mooseWindow frame]), NSStringFromRect(wBox));
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
	UKLog(@"mooseControllerDidChange (2): Old: %@ New: %@", NSStringFromRect([mooseWindow frame]), NSStringFromRect(wdBox));
	[mooseWindow setFrame: wdBox display: YES];
	[currentMoose setGlobalFrame: wdBox];
#endif
	
	[currentMoose setDelegate: self];
	[speechSynth setDelegate: currentMoose];
	[recSpeechSynth setDelegate: currentMoose];
	
	// Make sure widgets are in lower right:
	[self pinWidgetsBoxToBotRight];
	//[currentMoose setDontIdleAnimate: NO];
	
	[self mooseControllerAnimationDidChange: currentMoose];
	
	UKLog(@"Moose controller changed to \"%@\".", [currentMoose filePath]);
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
	wBox.origin = [imageView.window convertPointToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	[currentMoose setGlobalFrame: wBox];
	
	UKLog(@"About to call showMoose");
	[self showMoose];
}


-(void) mooseControllerAnimationDidChange: (UKMooseController*)mc
{
	NSImage*		currImg = [mc image];
	NSWindow*		mooseWin = [imageView window];
	
//	NSImage*		iconImg = [currImg scaledImageToFitSize: NSMakeSize(128,128)];
//	[NSApp setApplicationIconImage: iconImg];
	if( [mooseWin isVisible] )
	{
		[imageView setImage: currImg];
		//UKLog(@"Moose image changed.");
		//[mooseWin invalidateShadow];
		
		// Show/hide the window widgets if mouse is (not) in window:
		BOOL    hideWidgets = !NSPointInRect( [NSEvent mouseLocation], [mooseWin frame] );
		//UKLog(@"hide widgets? %d", hideWidgets);
		if( hideWidgets != [windowWidgets isHidden] )
			[windowWidgets setHidden: hideWidgets];
	}
	
	UKLog(@"moose position: %@ (%@ %@ %@ %f %p)", NSStringFromRect(mooseWin.frame), mooseWin.isVisible ? @"visible" : @"HIDDEN", mooseWin.isOnActiveSpace ? @"on this space" : @"ON INACTIVE SPACE", ((mooseWin.occlusionState & NSWindowOcclusionStateVisible) ? @"not occluded" : @"OCCLUDED"), mooseWin.alphaValue, mooseWin);
	
	//UKLog(@"mooseControllerAnimationDidChange:");
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
	lastSpeakTime = NSDate.timeIntervalSinceReferenceDate;
	
	[self hideMoose];
	
	if( terminateWhenFinished )
	{
		[NSApp replyToApplicationShouldTerminate: YES];
		UKLog(@"finished speaking, resuming quit.");
	}
	
	UKLog(@"finished.");
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
	if( speakOnAppLaunchQuit && (NSDate.timeIntervalSinceReferenceDate - lastSpeakTime) >= speechDelay )
	{
		NSRunningApplication 	*runningApp = notif.userInfo[NSWorkspaceApplicationKey];
		NSString				*appName = runningApp.localizedName;
		
		if ([runningApp.bundleIdentifier isEqualToString: NSBundle.mainBundle.bundleIdentifier]) {
			return; // Don't send messages for ourself.
		} else if ([runningApp.bundleIdentifier isEqualToString: UKMainApplicationID]) {
			[self speakPhraseOnMainThreadFromGroup: @"LAUNCH SETUP" withFillerString: appName];
		} else if (![appName isEqualToString: @"ScreenSaverEngine"]
			&& ![appName isEqualToString: @"ScreenSaverEngin"]) {
			[self speakPhraseOnMainThreadFromGroup: @"LAUNCH APPLICATION" withFillerString: appName];
		}
	}
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) applicationTerminationNotification:(NSNotification*)notif
{
	if( speakOnAppLaunchQuit && (NSDate.timeIntervalSinceReferenceDate - lastSpeakTime) >= speechDelay )
	{
		NSRunningApplication 	*runningApp = notif.userInfo[NSWorkspaceApplicationKey];
		NSString				*appName = runningApp.localizedName;
		
		if ([runningApp.bundleIdentifier isEqualToString: NSBundle.mainBundle.bundleIdentifier]) {
			return; // Don't send messages for ourself.
		} else if ([runningApp.bundleIdentifier isEqualToString: UKMainApplicationID]) {
			[self speakPhraseOnMainThreadFromGroup: @"QUIT SETUP" withFillerString: appName];
		} else if (![appName isEqualToString: @"ScreenSaverEngine"]
				   && ![appName isEqualToString: @"ScreenSaverEngin"]) {
			[self speakPhraseOnMainThreadFromGroup: @"QUIT APPLICATION" withFillerString: appName];
		}
	}
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) applicationSwitchNotification:(NSNotification*)notif
{
	//UKLog(@"applicationSwitchNotification");
	if( speakOnAppChange && (NSDate.timeIntervalSinceReferenceDate - lastSpeakTime) >= speechDelay )
	{
		NSRunningApplication *runningApp = notif.userInfo[NSWorkspaceApplicationKey];
		if ([runningApp.bundleIdentifier isEqualToString: NSBundle.mainBundle.bundleIdentifier]) {
			return; // Don't send messages for ourself.
		} else if ([runningApp.bundleIdentifier isEqualToString: UKMainApplicationID]) {
			[self speakPhraseOnMainThreadFromGroup: @"LAUNCH SETUP" withFillerString: runningApp.localizedName];
		} else {
			[self speakPhraseOnMainThreadFromGroup: @"CHANGE APPLICATION" withFillerString: runningApp.localizedName];
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
	
	UKLog( @"Hiding Moose (%d)", mooseVisibleCount );
	
	if( mooseVisibleCount < 0 )
		mooseVisibleCount = 0;
	
	if( mooseVisibleCount == 0 )
	{
		//[currentMoose setDontIdleAnimate: NO];
		//UKLog( @"\tHit zero. Fading out." );
		[imageView.window orderOut: self];
		[speechBubbleView.window orderOut: self];
//		[[imageView window] fadeOutWithDuration: 0.5];
//		[[speechBubbleView window] fadeOutWithDuration: 0.5];
		self.appNapDeactivatingActivity = nil;
		UKLog(@"app nap = %@", self.appNapDeactivatingActivity);
	}
}


-(void)     showMoose
{
	NSWindow*		mooseWin = [imageView window];

	mooseVisibleCount++;
	
	UKLog( @"Showing Moose (%d)", mooseVisibleCount );
	//UKLogBacktrace();
	
	if( mooseVisibleCount < 0 )
		mooseVisibleCount = 0;
	
	if( mooseVisibleCount == 1 )
	{
		[NSApplication.sharedApplication unhideWithoutActivation];
		
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
//		[mooseWin fadeInWithDuration: 0.5];
		[mooseWin orderFront: self];
		if( showSpokenString ) {
//			[[speechBubbleView window] fadeInWithDuration: 0.5];
			[speechBubbleView.window orderFront: self];
		}
		//[currentMoose setDontIdleAnimate: NO];
		[self pinWidgetsBoxToBotRight];
	}
	else
		;//UKLog(@"Not 1, leaving window untouched.");
	[mooseWin invalidateShadow];
	
	[NSApplication.sharedApplication unhide: nil];
}

@end
