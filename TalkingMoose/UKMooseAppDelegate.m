//
//  UKMooseAppDelegate.m
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "UKMooseAppDelegate.h"
#import "UKCrashReporter.h"
#import "UKMooseController.h"
#import "UKPhraseDatabase.h"
#import "NSImage+NiceScaling.h"
#import "UKSpeechSettingsView.h"
#import "UKIdleTimer.h"
#import "UKBorderlessWindow.h"
#import "NSArray+Color.h"
#import "PTHotKey.h"
#import "PTKeyComboPanel.h"
#import "UKLoginItemRegistry.h"
#import "NSFileManager+CreateDirectoriesForPath.h"
#import "NSWindow+Fade.h"
//#import "UKUIElement.h"
#include <Carbon/Carbon.h>
#import "UKCarbonEventHandler.h"
#import "UKMooseDragAreaView.h"
#import "UKMooseMouthImageRep.h"
#import "UKGroupFile.h"
#import "UKRecordedSpeechChannel.h"
#import "UKClickableImageView.h"
#import "UKFinderIconCell.h"

#if DEBUG && 0
#include <execinfo.h>
#include <stdio.h>
#endif


#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
#define	NSWindowCollectionBehaviorCanJoinAllSpaces	(1 << 0)	// Leopard constant.
@protocol UKNSWindowLeopardMethods
-(void)	setCollectionBehavior: (unsigned int)n;	// Leopard method.
@end
#endif


#if USE_ISHIDDEN_WHERE_AVAILABLE
@interface NSObject (NSViewTenThreeMethods)

-(BOOL)		isHidden;
-(void)		setHidden: (BOOL)state;

@end
#endif


// -----------------------------------------------------------------------------
//	Constants:
// -----------------------------------------------------------------------------

#define UKUserAnimationsPath    "/Library/Application Support/Moose/Animations"
#define UKUserPhrasesPath       "/Library/Application Support/Moose/Phrases"


// -----------------------------------------------------------------------------
//	Globals:
// -----------------------------------------------------------------------------

static BOOL		gIsSilenced = NO;


@implementation UKMooseAppDelegate

// -----------------------------------------------------------------------------
//	* CONSTRUCTOR:
// -----------------------------------------------------------------------------

-(id) init
{
	self = [super init];
	if( self )
	{
		srand(time(NULL));
		
		phraseTimer = [[UKIdleTimer alloc] initWithTimeInterval: 30];
		[phraseTimer setDelegate: self];
		mooseControllers = [[NSMutableArray alloc] init];
		
		// Speech channel:
		long		outVersion = 0;
		Gestalt( gestaltSystemVersion, &outVersion);
		if( outVersion >= 0x1050 )	// NSSpeechSynthesizer has finally become usable! Use that!
			speechSynth = [[NSSpeechSynthesizer alloc] init];
		else	// Load UKSpeechChannel from bundle and use that:
		{
			NSString*	bPath = [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"UKSpeechSynthesizer.bundle"];
			NSBundle*	speechSynthCompatClasses = [NSBundle bundleWithPath: bPath];
			[speechSynthCompatClasses load];
			speechSynth = (NSSpeechSynthesizer*) [[NSClassFromString( @"UKSpeechSynthesizer" ) alloc] init];
		}
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
		
		// System-wide keyboard shortcuts:
		speakNowHotkey = [[PTHotKey alloc] initWithName: @"Speak Now" target: self action: @selector(speakOnePhrase:) addToCenter: YES];
		repeatLastPhraseHotkey = [[PTHotKey alloc] initWithName: @"Repeat Last Phrase" target: self action: @selector(repeatLastPhrase:) addToCenter: YES];
		silenceMooseHotkey = [[PTHotKey alloc] initWithName: @"Silence, Moose!" target: self action: @selector(silenceMoose:) addToCenter: YES];
		
		// Install Carbon event handler for app switches:
		appSwitchEventHandler = [[UKCarbonEventHandler alloc] initWithEventClass: kEventClassApplication kind: kEventAppFrontSwitched];
		
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
		[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(applicationSwitchNotification:)
				name: UKCarbonEventHandlerEventReceived object: appSwitchEventHandler];
        
        // Set up a timer to fire every half hour for clock announcements:
        clockTimer = [[NSTimer scheduledTimerWithTimeInterval: 60 * 30
                        target: self selector: @selector(halfHourElapsed:)
                        userInfo: [NSDictionary dictionary] repeats: YES] retain];
        [self updateClockTimerFireTime: clockTimer];
        
        [self setScaleFactor: 1];	// Make sure Moose doesn't start out 0x0 pixels large.
	}
	
	return self;
}


// -----------------------------------------------------------------------------
//	* DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
	DESTROY(recSpeechSynth);
	DESTROY(speakNowHotkey);
	DESTROY(repeatLastPhraseHotkey);
	DESTROY(silenceMooseHotkey);
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
	
    DESTROY(clockTimer);
	DESTROY(phraseTimer);
	DESTROY(mooseControllers);
	DESTROY(speechSynth);
	DESTROY(appSwitchEventHandler);
	
	#if USE_ISHIDDEN_WHERE_AVAILABLE
	if( ![windowWidgets respondsToSelector: @selector(isHidden)] )	// We're on 10.2, and we retained it an additional time to be able to hide it by removing it from its superview.
	#endif
		DESTROY(windowWidgets);
	
	[super dealloc];
}


// -----------------------------------------------------------------------------
//	NIB has been loaded, set up GUI:
// -----------------------------------------------------------------------------


//#define kCGWindowListOptionOnScreenOnly		(1 << 0)
//typedef CFArrayRef (*CGWLCWIPtr)( uint32_t, uint32_t );
//static CGWLCWIPtr	_CGWindowListCopyWindowInfo = NULL;
//
//CFBundleRef		appServices = CFBundleGetBundleWithIdentifier( CFSTR("com.apple.ApplicationServices") );
//if( appServices )
//	_CGWindowListCopyWindowInfo = (CGWLCWIPtr) CFBundleGetFunctionPointerForName( appServices, CFSTR("CGWindowListCopyWindowInfo") );
//
//if( _CGWindowListCopyWindowInfo )
//{
//	NSArray*	arr = (NSArray*) _CGWindowListCopyWindowInfo( kCGWindowListOptionOnScreenOnly, 0 );
//	UKLog(@"%@",arr);
//}

-(void) awakeFromNib
{
	UKCrashReporterCheckForCrash();
	
//	NSView*	dockView = [[NSApp dockTile] contentView];
//	UKLog(@"%@", dockView);
	
	// Set window bg pattern:
	//[settingsWindow setBackgroundColor: [NSColor colorWithPatternImage: [NSImage imageNamed: @"window_bg"]]];
	
	#if 0
	// Remove the phrases tab for now, it's not finished yet:
	int	phrasesTab = [mainTabView indexOfTabViewItemWithIdentifier: @"de.zathras.phrases-tab"];
	NSTabViewItem*	tvi = [mainTabView tabViewItemAtIndex: phrasesTab];
	[tvi retain];
	[mainTabView removeTabViewItem: tvi];
	#endif
	
	[mainTabView selectTabViewItemAtIndex: 0];
	
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
	[self loadSettingsFromDefaultsIntoUI];
    [self refreshSpeakHoursUI];
    [self setUpSpeechBubbleWindow];
	
	// Hide widgets on 10.2:
	#if USE_ISHIDDEN_WHERE_AVAILABLE
	if( ![windowWidgets respondsToSelector: @selector(isHidden)] )
	{
	#endif
		if( windowWidgetsSuperview == nil )
			windowWidgetsSuperview = [mooseWindow contentView];
		[windowWidgets retain];
		[windowWidgets removeFromSuperview];
	#if USE_ISHIDDEN_WHERE_AVAILABLE
	}
	else
		[windowWidgets setHidden: YES];
	#endif
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


// -----------------------------------------------------------------------------
//	Load all those animations:
// -----------------------------------------------------------------------------

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
	
    // Make sure the view knows whose settings to change:
    [speechSets setSpeechSynthesizer: speechSynth];
	
    // Update list and select current moose:
	[mooseList reloadData];
	[mooseList selectRow: currMooseIndex byExtendingSelection: NO];	// Changes animation and may cause reset in scale factor:
}


// -----------------------------------------------------------------------------
//	Set up settings window GUI:
// -----------------------------------------------------------------------------

-(void)	loadSettingsFromDefaultsIntoUI
{
	UKLog(@"About to Load.");
	
    // Hotkey shortcut edit fields:
	[speakNowHKField setStringValue: [speakNowHotkey stringValue]];
	[repeatLastPhraseHKField setStringValue: [repeatLastPhraseHotkey stringValue]];
	[silenceMooseHKField setStringValue: [silenceMooseHotkey stringValue]];
	
    // "Launch at startup" checkbox:
	NSString*		bundlePath = [[NSBundle mainBundle] bundlePath];
	
	if( [UKLoginItemRegistry indexForLoginItemWithPath: bundlePath] != -1 )
		[launchAtLoginSwitch setState: YES];
	
	// BG Image:
	NSString*   bgImageName = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndImage"];
	if( bgImageName != nil )
		[imagePopup selectItemWithTitle: bgImageName];
	[self backgroundImageDidChange: self];
	
	// Gradient colors:
	NSColor*	theColor = [[[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndStartColor"] colorValue];
	if( theColor != nil )
		[startColor setColor: theColor];
	[self takeStartColorFrom: startColor];

	theColor = [[[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseBkgndEndColor"] colorValue];
	if( theColor != nil )
		[endColor setColor: theColor];
	[self takeEndColorFrom: endColor];
	
	// Delay:
	NSNumber* delay = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseSpeechDelay"];
	if( delay != nil )
		[speechDelaySlider setDoubleValue: [delay doubleValue]];
	[self takeSpeechDelayFrom: speechDelaySlider];
	
	// Settings window:
	NSNumber*   num = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMoosePanelVisible"];
	if( !num || [num boolValue] )
		[[mooseList window] makeKeyAndOrderFront: self];
	
	// Checkboxes:
	NSNumber*   sspks = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseShowSpokenString"];
	showSpokenString = (sspks && [sspks boolValue]);
	[showSpokenStringSwitch setState: showSpokenString];
	
	NSNumber*   fios = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseFadeInOut"];
	fadeInOut = (fios && [fios boolValue]);
	[fadeInOutSwitch setState: fadeInOut];
	
	NSNumber*   aids = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseAnimateInDock"];
	[animateInDockSwitch setState: (aids && [aids boolValue])];

	NSNumber*   sovms = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseSpeakOnVolumeMount"];
	if( !sovms )
	{
		sovms = [NSNumber numberWithBool: YES];
		[[NSUserDefaults standardUserDefaults] setObject: sovms forKey: @"UKMooseSpeakOnVolumeMount"];
	}
	speakOnVolumeMount = [sovms boolValue];
	[speakOnVolMountSwitch setState: speakOnVolumeMount];

	NSNumber*   soalqs = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseSpeakOnAppLaunchQuit"];
	if( !soalqs )
	{
		soalqs = [NSNumber numberWithBool: YES];
		[[NSUserDefaults standardUserDefaults] setObject: soalqs forKey: @"UKMooseSpeakOnAppLaunchQuit"];
	}
	speakOnAppLaunchQuit = [soalqs boolValue];
	[speakOnAppLaunchQuitSwitch setState: speakOnAppLaunchQuit];
	
	NSNumber*   soacs = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseSpeakOnAppChange"];
	if( !soacs )
	{
		soacs = [NSNumber numberWithBool: YES];
		[[NSUserDefaults standardUserDefaults] setObject: soacs forKey: @"UKMooseSpeakOnAppChange"];
	}
	speakOnAppChange = [soacs boolValue];
	[speakOnAppChangeSwitch setState: speakOnAppChange];
	
	UKLog(@"Loaded.");
}


// -----------------------------------------------------------------------------
//	Set up all those properties our window for displaying phrase text needs:
// -----------------------------------------------------------------------------

-(void)		setUpSpeechBubbleWindow
{
	UKLog(@"About to set up.");
	UKBorderlessWindow*		speechBubbleWindow = (UKBorderlessWindow*) [speechBubbleView window];
	
	[speechBubbleWindow setBackgroundColor: [NSColor clearColor]];
	[speechBubbleWindow setOpaque: NO];
	[speechBubbleWindow setHasShadow: YES];
	[speechBubbleWindow setConstrainRect: YES];
	[speechBubbleWindow setLevel: kCGOverlayWindowLevel];
	[speechBubbleWindow setHidesOnDeactivate: NO];
	[speechBubbleWindow setCanHide: NO];
	[speechBubbleView setTextContainerInset: NSMakeSize(4,6)];
	UKLog(@"Finished.");
}


// -----------------------------------------------------------------------------
//	application:openFiles:
//		User opened several Moose phrase files or animation files, or dragged
//		several of those on our icon. Ask the user whether we're to nstall them
//		in the proper ~/Library subfolder, and do that. Optionally let the user
//		open the Moose panel to work with them.
// -----------------------------------------------------------------------------

-(void)	application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	NSString*	title = NSLocalizedString(@"Install these files?",@"Multiple Install Question Title");
	NSString*   msg = NSLocalizedString(@"You have opened animation/phrase files with the Moose. Do you want to install them on your computer so the Moose will use them from now on?",@"Multiple Install Question Message");

	if( NSRunInformationalAlertPanel( title, msg, NSLocalizedString(@"Yes",@""), NSLocalizedString(@"No",@""), @"" ) == NSOKButton )
	{
		NSEnumerator*	enny = [filenames objectEnumerator];
		NSString*		currFilename = nil;
		NSMutableArray*	installedFileNames = [NSMutableArray array];
		
		while( (currFilename = [enny nextObject]) )
			[self application: sender openFile: currFilename dontAskButAddToList: installedFileNames];
		
		msg = NSLocalizedString(@"The following files have been installed:\n\n%@\n\nDo you want to open the Moose panel so you can examine/activate them?",@"Multiple Install Success Message");
		msg = [NSString stringWithFormat: msg, [installedFileNames componentsJoinedByString: @"\n"]];
		title = [NSString stringWithFormat: NSLocalizedString(@"%d Files Installed.",@""), [installedFileNames count]];
		
		if( NSRunInformationalAlertPanel( title, msg, NSLocalizedString(@"Yes",@""), NSLocalizedString(@"No",@""), @"" ) == NSOKButton )
			[[mooseList window] makeKeyAndOrderFront: self];
	}
}


// -----------------------------------------------------------------------------
//	application:openFile:
//		User opened a Moose phrase file or animation file, or dragged one of
//		those on our icon. Install it in the proper ~/Library subfolder.
// -----------------------------------------------------------------------------

-(BOOL) application: (NSApplication*)sender openFile: (NSString*)filename
{
	NSString*	title = NSLocalizedString(@"Install this file?",@"Install Question Title");
	NSString*   msg = NSLocalizedString(@"You have opened an animation/phrase file with the Moose. Do you want to install it on your computer so the Moose will use it from now on?",@"Install Question Message");

	if( NSRunInformationalAlertPanel( title, msg, NSLocalizedString(@"Yes",@""), NSLocalizedString(@"No",@""), @"" ) == NSOKButton )
	{
		return [self application: sender openFile: filename dontAskButAddToList: nil];
	}
	else
		return NO;
}


// -----------------------------------------------------------------------------
//	application:openFile:dontAskButAddToList:
//		Main bottleneck called by application:openFile: and
//		application:openFiles: to actually install a single animation or
//		phrase file.
//
//		When arr is NIL, this will display a panel telling the user that the
//		file has been installed, offering to open the Moose panel now.
//		When arr is an array, this will add the name and type of each installed
//		item to the array, so you can display them all as a list in a single
//		panel.
// -----------------------------------------------------------------------------

-(BOOL)	application: (NSApplication*)sender openFile: (NSString*)filename dontAskButAddToList: (NSMutableArray*)arr
{
    NSString*   ext = [filename pathExtension];
    NSString*   dirToCopyTo = nil;
    NSString*   itemKindName = nil;
	BOOL		isAnimation = YES;
    
    if( [ext isEqualToString: @"txt"] || [ext isEqualToString: @"phraseFile"] )
    {
        NSString*   userPhraseDir = [@"~" UKUserPhrasesPath stringByExpandingTildeInPath];
        
        if( ![filename hasPrefix: @"" UKUserPhrasesPath]
            && ![filename hasPrefix: userPhraseDir] )
        {
            dirToCopyTo = userPhraseDir;
            itemKindName = NSLocalizedString(@"Phrase File",@"Install Success Phrase File Type String");
			isAnimation = NO;
        }
    }
    else if( [ext isEqualToString: @"nose"] )
    {
        NSString*   userAnimDir = [@"~" UKUserAnimationsPath stringByExpandingTildeInPath];
        
        if( ![filename hasPrefix: @"" UKUserAnimationsPath]
            && ![filename hasPrefix: userAnimDir] )
        {
            dirToCopyTo = userAnimDir;
            itemKindName = NSLocalizedString(@"Animation File",@"Install Success Animation File Type String");
			isAnimation = YES;
        }
    }
    
    if( dirToCopyTo != nil )
    {
        if( ![[NSFileManager defaultManager] createDirectoriesForPath: dirToCopyTo] )
            return NO;
        
		NSString*	itemName = [[NSFileManager defaultManager] displayNameAtPath: filename];
        dirToCopyTo = [dirToCopyTo stringByAppendingPathComponent: [filename lastPathComponent]];
        
		if( [[NSFileManager defaultManager] fileExistsAtPath: dirToCopyTo] )
			[[NSFileManager defaultManager] removeFileAtPath: dirToCopyTo handler: nil];
		
        if( [[NSFileManager defaultManager] copyPath: filename toPath: dirToCopyTo handler: nil] )
        {
			if( isAnimation )
				[self loadAnimationAtPath: dirToCopyTo andReload: YES];
			else
				[phraseDB loadPhrasesInFile: dirToCopyTo];
            
			if( arr )
				[arr addObject: [NSString stringWithFormat: @"%@ (%@)", itemName, itemKindName]];
			else
			{
				NSString*   msg = NSLocalizedString(@"The %@ \"%@\" has been installed. Do you want to open the Moose panel so you can examine/activate it?",@"Install Success Message");
				msg = [NSString stringWithFormat: msg, itemKindName, itemName];
				if( NSRunInformationalAlertPanel( NSLocalizedString(@"Installation successful.",@""), msg,
						NSLocalizedString(@"Yes",@""), NSLocalizedString(@"No",@""), @"" ) == NSOKButton )
					[[mooseList window] makeKeyAndOrderFront: self];
			}
        }
    }
    
    return YES;
}


-(BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    [[mooseList window] makeKeyAndOrderFront: self];
    
    return NO;
}


-(void) applicationDidFinishLaunching: (NSNotification*)notif
{
	// Make a backup of our prefs file if this is first startup of new version:
	NSString*		currVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"];
	NSString*		lastPrefVersion = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKMooseLastPrefsVersion"];
	if( !lastPrefVersion )
		lastPrefVersion = @"";
	if( ![lastPrefVersion isEqualToString: currVersion] )	// Compare version of Moose that last wrote prefs to ours:
	{
		NSString*		prefsFile = [[NSString stringWithFormat: @"~/Library/Preferences/%@.plist", [[NSBundle mainBundle] bundleIdentifier]] stringByExpandingTildeInPath];
		NSString*		backupFile = [prefsFile stringByAppendingString: @".backup"];
		NSFileManager*	dfm = [NSFileManager defaultManager];
		BOOL			goOn = YES;
		
		// Copy prefs file to a backup file:
		if( [dfm fileExistsAtPath: backupFile] )
			goOn = [dfm removeFileAtPath: backupFile handler: nil];
		if( goOn )
			[dfm copyPath: prefsFile toPath: backupFile handler: nil];	// We don't really care if this fails
		
		// Remember we already did a backup:
		[[NSUserDefaults standardUserDefaults] setObject: currVersion forKey: @"UKMooseLastPrefsVersion"];
	}
	
	// Force update of Moose, even when we can't say "hello":
	[self refreshShutUpBadge];
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
	//UKLog( @"applicationWillTerminate: Saving position: %@", moosePosString );
	[[NSUserDefaults standardUserDefaults] setObject: moosePosString forKey: @"UKMooseAnimPosition"];
	[[NSUserDefaults standardUserDefaults] setObject: [speechSynth settingsDictionary] forKey: @"UKSpeechChannelSettings"];
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: [[mooseList window] isVisible]] forKey: @"UKMoosePanelVisible"];
	[[NSUserDefaults standardUserDefaults] setFloat: [self scaleFactor] forKey: @"UKMooseScaleFactor"];
}


-(void) loadAnimationsInFolder: (NSString*)folder
{
	NSString*			animFolder = [folder stringByExpandingTildeInPath];
	NSEnumerator*		enny = [[[NSFileManager defaultManager] directoryContentsAtPath: animFolder] objectEnumerator];
	NSString*			currPath = nil;
	UKMooseController*  newController = nil;
	
	while( (currPath = [enny nextObject]) )
	{
		if( [currPath characterAtIndex:0] == '.' )
			continue;
		if( ![[currPath pathExtension] isEqualToString: @"nose"] )
			continue;
		
		currPath = [animFolder stringByAppendingPathComponent: currPath];
		
		NS_DURING
			newController = [self loadAnimationAtPath: currPath andReload: NO];
		NS_HANDLER
			NSLog( @"Error: %@", localException );
		NS_ENDHANDLER
	}
    
    [mooseList reloadData];
}


-(UKMooseController*) loadAnimationAtPath: (NSString*)animationPath andReload: (BOOL)reloadList
{
    UKMooseController* newController = [[[UKMooseController alloc] initWithAnimationFile: animationPath] autorelease];
    [mooseControllers addObject: newController];
    
    if( reloadList )
        [mooseList reloadData];
    
    return newController;
}


-(void) setMooseSilenced: (BOOL)doSilence
{
    if( gIsSilenced != doSilence )
        [self silenceMoose: self];
}


-(BOOL) mooseSilenced
{
    return gIsSilenced;
}


-(void) refreshSpeakHoursUI
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakTime"];
    [speakHoursSwitch setState: state];
    [speakHalfHoursSwitch setEnabled: state];
    [beAnallyRetentive setEnabled: state];
    [speakHalfHoursSwitch setState: [ud boolForKey: @"UKMooseSpeakTimeOnHalfHours"]];
    [beAnallyRetentive setState: [ud boolForKey: @"UKMooseSpeakTimeAnallyRetentive"]];
}


-(void) toggleSpeakHours: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakTime"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakTime"];
    [self updateClockTimerFireTime: clockTimer];
    
    [speakHalfHoursSwitch setEnabled: !state];
    [beAnallyRetentive setEnabled: !state];
}


-(void) toggleSpeakHalfHours: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakTimeOnHalfHours"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakTimeOnHalfHours"];
    [self updateClockTimerFireTime: clockTimer];
}


-(void) toggleAnallyRetentive: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakTimeAnallyRetentive"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakTimeAnallyRetentive"];
    [self updateClockTimerFireTime: clockTimer];
}


-(void) toggleFadeInOut: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseFadeInOut"];
    
    [ud setBool: !state forKey: @"UKMooseFadeInOut"];
    fadeInOut = !state;
}


-(void) toggleSpeakVolumeMount: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakOnVolumeMount"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakOnVolumeMount"];
    speakOnVolumeMount = !state;
}


-(void) toggleSpeakAppLaunchQuit: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakOnAppLaunchQuit"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakOnAppLaunchQuit"];
    speakOnAppLaunchQuit = !state;
}


-(void) toggleSpeakAppChange: (id)sender
{
    NSUserDefaults*     ud = [NSUserDefaults standardUserDefaults];
    BOOL                state = [ud boolForKey: @"UKMooseSpeakOnAppChange"];
    
    [ud setBool: !state forKey: @"UKMooseSpeakOnAppChange"];
    speakOnAppChange = !state;
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


-(void)	interruptMoose: (id)sender
{
    [speechSynth stopSpeaking];
    [recSpeechSynth stopSpeaking];
	// Reset visible count to make sure it goes away.
	mooseVisibleCount = 1;
	[self hideMoose];
}


// Called by click on moose image:
-(void) mooseAnimationWindowClicked: (id)sender
{
    BOOL        dragInstead = NO;
	
	Point	globMouse = { 0, 0 };
	GetGlobalMouse( &globMouse );
	if( WaitMouseMoved( globMouse ) )
		dragInstead = YES;
	
    if( dragInstead )
    {
        [self dragMooseAnimationWindow: sender];   // Call title bar drag method instead.
        return;
    }
	
	[self interruptMoose: self];
}


-(void) resizeMoose: (id)sender
{
    NSWindow    *wd = [imageView window];
    NSSize      imgSize = [[imageView image] size],
                mooseSize = [currentMoose size];
    NSRect      oldBox = [wd frame],
                newBox = [wd frame];
    NSEvent*    currEvt = nil;
    
	UKLog(@"About to call showMoose");
    [self showMoose];
    
    while( YES )
    {
        currEvt = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                    untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
        if( currEvt && [currEvt type] == NSLeftMouseUp )
            break;
        
        newBox.size.width = oldBox.size.width +[currEvt deltaX];
        newBox.size.height = oldBox.size.height +[currEvt deltaY];
        
        oldBox.origin.y -= newBox.size.height -oldBox.size.height;
        oldBox.size.width = newBox.size.width;
        oldBox.size.height = newBox.size.height;
        
        newBox.origin = oldBox.origin;
        newBox.size = [NSImage scaledSize: imgSize toCoverSize: oldBox.size];
        
        [wd setFrame: newBox display: YES];
        [currentMoose setGlobalFrame: newBox];
    }
    
    [self setScaleFactor: newBox.size.width / mooseSize.width];
	
	[self pinWidgetsBoxToBotRight];
    [self hideMoose];
}


-(void) zoomMoose: (id)sender
{
    [self setScaleFactor: 1];
}


// Called by click in window's "title bar" drag area:
-(void) dragMooseAnimationWindow: (id)sender
{
	NSPoint		mousePos = [NSEvent mouseLocation];
	NSPoint		posDiff = [[imageView window] frame].origin;
	NSEvent*	evt = nil;
    
	posDiff.x -= mousePos.x;
	posDiff.y -= mousePos.y;
	
	UKLog(@"About to call showMoose");
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
	[self refreshShutUpBadge];
	[self speakOnePhrase: sender];
}


-(void) timerContinuesIdling: (id)sender
{
	[self refreshShutUpBadge];
	[self speakOnePhrase: sender];
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [mooseControllers count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [[mooseControllers objectAtIndex: row] valueForKey: [tableColumn identifier]];
}


- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell
		forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if( [[tableColumn identifier] isEqualToString: @"name"] )
	{
		UKFinderIconCell*	fic = cell;
		NSImage*			theImg = [[mooseControllers objectAtIndex: row] valueForKey: @"previewImage"];
		NSString*			theName = [[mooseControllers objectAtIndex: row] valueForKey: @"name"];
		
		[fic setStringValue: theName];
		[fic setImage: theImg];
		[fic setImagePosition: NSImageLeft];
	}
}

- (void)tableViewSelectionDidChange: (NSNotification *)notification
{
	[speechSynth stopSpeaking];
	[recSpeechSynth stopSpeaking];
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


-(void)	showSettingsWindow: (id)sender
{
	[settingsWindow makeKeyAndOrderFront: sender];
	
	if( ![NSApp isActive] || [NSApp isHidden] )
		[NSApp activateIgnoringOtherApps: YES];
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
		&& ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] && ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning] )
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


-(void) speakString: (NSString*)currPhrase
{
	if( mooseDisableCount == 0 && ![excludeApps appInListMatches] && ![excludeApps screenSaverRunning] )
	{
		[speechSynth startSpeakingString: currPhrase];
		[self showSpeechBubbleWithString: currPhrase];
        //UKLog(@"Speaking: %@", currPhrase);
	}
}

-(void) showSpeechBubbleWithString: (NSString*)currPhrase
{
    if( showSpokenString )
    {
		UKLog(@"About to position.");
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
		UKLog(@"Positioned at %@ for moose frame %@.",NSStringFromRect( bubbleFrame ),NSStringFromRect( mooseFrame ));
		
		[mooseWin addChildWindow: bubbleWin ordered: NSWindowAbove];
    }
	else
		UKLog(@"showSpokenString == false");
}


-(void) repeatLastPhrase: (id)sender
{
	if( mooseDisableCount == 0 )
	{
		NSString*   currPhrase = [phraseDB mostRecentPhrase];
		if( !currPhrase )
			return;
		[speechSynth startSpeakingString: currPhrase];
		if( showSpokenString )
		{
			[speechBubbleView setString: currPhrase];
            if( fadeInOut )
                [[speechBubbleView window] fadeInWithDuration: 0.5];
            else
                [[speechBubbleView window] orderFrontRegardless];
		}
	}
}


-(void) silenceMoose: (id)sender
{
	if( gIsSilenced )
		mooseDisableCount--;
	else
		mooseDisableCount++;
	
	gIsSilenced = !gIsSilenced;
	[shutUpSwitch setState: gIsSilenced];
    [self refreshShutUpBadge];
	[self interruptMoose: self];
}


-(void) refreshShutUpBadge
{
    NSImage*    shutUpImg = [currentMoose imageForKey: UKMooseControllerShutUpBadgeKey];
    if( !shutUpImg )
        shutUpImg = [NSImage imageNamed: @"BandAid"];
    [currentMoose setBadgeImage: (gIsSilenced || [excludeApps appInListMatches]) ? shutUpImg : nil];
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
	int				loginItemIdx = [UKLoginItemRegistry indexForLoginItemWithPath: bundlePath];
	
	if( loginItemIdx == -1 )
		[UKLoginItemRegistry addLoginItemWithPath: bundlePath hideIt: YES];
	else
		[UKLoginItemRegistry removeLoginItemAtIndex: loginItemIdx];
}


-(void) takeShowSpokenStringBoolFrom: (id)sender
{
	showSpokenString = [sender state];
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: showSpokenString] forKey: @"UKMooseShowSpokenString"];
}


-(void) takeAnimateInDockBoolFrom: (id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: [sender state]] forKey: @"UKMooseAnimateInDock"];
	[currentMoose setDontIdleAnimate: ![sender state]];
}


-(void) backgroundImageDidChange: (id)sender
{
	NSEnumerator*		enny = [mooseControllers objectEnumerator];
	UKMooseController*  mc = nil;
	NSString*			imgName = [imagePopup titleOfSelectedItem];
	
	while( (mc = [enny nextObject]) )
		[mc setBackgroundImage: imgName];
	
	[[NSUserDefaults standardUserDefaults] setObject: imgName forKey: @"UKMooseBkgndImage"];
	
	// Now correctly enable color pickers:
	mc = [mooseControllers lastObject];
	[startColor setEnabled: [mc bgImageHasStartColor: imgName]];
	if( ![mc bgImageHasStartColor: imgName] )
		[startColorLabel setTextColor: [NSColor disabledControlTextColor]];
	else
		[startColorLabel setTextColor: [NSColor controlTextColor]];
	[endColor setEnabled: [mc bgImageHasEndColor: imgName]];
	if( ![mc bgImageHasEndColor: imgName] )
		[endColorLabel setTextColor: [NSColor disabledControlTextColor]];
	else
		[endColorLabel setTextColor: [NSColor controlTextColor]];
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
	
	NSString*   bgImageName = [[[imagePopup titleOfSelectedItem] retain] autorelease];
	[imagePopup removeAllItems];
	if( !bgImageName || [bgImageName length] == 0 )
		bgImageName = @"Transparent";
	[imagePopup addItemsWithTitles: [currentMoose backgroundImages]];
	[imagePopup selectItemWithTitle: bgImageName];
	
	// Make sure widgets are in lower right:
	[self pinWidgetsBoxToBotRight];
	[currentMoose setDontIdleAnimate: ![animateInDockSwitch state]];
	
    [self refreshShutUpBadge];
    
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
	wBox.origin = [[imageView window] convertBaseToScreen: [imageView convertPoint: NSZeroPoint toView: nil]];
	[currentMoose setGlobalFrame: wBox];

	UKLog(@"About to call showMoose");
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
		UKLog(@"Moose image changed.");
        //[mooseWin invalidateShadow];
    
		// Show/hide the window widgets if mouse is (not) in window:
		BOOL    hideWidgets = !NSPointInRect( [NSEvent mouseLocation], [mooseWin frame] );
		#if USE_ISHIDDEN_WHERE_AVAILABLE
		if( [windowWidgets respondsToSelector: @selector(isHidden)] )
		{
			if( hideWidgets != [windowWidgets isHidden] )
				[windowWidgets setHidden: hideWidgets];
		}
		else	// 10.2 doesn't have isHidden and setHidden:
		{
		#endif
			if( hideWidgets && ([windowWidgets superview] != nil) )			// Should be hidden but isn't?
			{
				[windowWidgets removeFromSuperview];
				[windowWidgets setNeedsDisplay: YES];
			}
			else if( !hideWidgets && ([windowWidgets superview] == nil) )	// Is hidden but shouldn't be?
			{
				[windowWidgetsSuperview addSubview: windowWidgets];
				[windowWidgetsSuperview setNeedsDisplay: YES];
			}
		#if USE_ISHIDDEN_WHERE_AVAILABLE
		}
		#endif
	}

    //UKLog(@"mooseControllerAnimationDidChange:");
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
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
	if( speakOnAppLaunchQuit )
	{
		NSString*		appName = [[[[notif userInfo] objectForKey: @"NSApplicationName"] retain] autorelease];
		
		if( ![appName isEqualToString: @"ScreenSaverEngine"]
			&& ![appName isEqualToString: @"ScreenSaverEngin"] )
			[self speakPhraseOnMainThreadFromGroup: @"LAUNCH APPLICATION" withFillerString: appName];
	}
	[self refreshShutUpBadge];
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
	[self refreshShutUpBadge];
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
	[self refreshShutUpBadge];
	[self mooseControllerAnimationDidChange: currentMoose];
}


-(void) applicationDidBecomeActive: (NSNotification *)notification
{
	[self speakPhraseOnMainThreadFromGroup: @"LAUNCH SETUP" withFillerString: nil];
	
	[self refreshShutUpBadge];
	[self mooseControllerAnimationDidChange: currentMoose];
}

-(void) applicationDidResignActive: (NSNotification *)notification
{
	[self speakPhraseOnMainThreadFromGroup: @"QUIT SETUP" withFillerString: nil];
	
	[self refreshShutUpBadge];
	[self mooseControllerAnimationDidChange: currentMoose];
}	


-(void) fastUserSwitchedInNotification:(NSNotification*)notif
{
	mooseDisableCount--;
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseOnMainThreadFromGroup: @"USER SWITCHED IN" withFillerString: nil];
	[self refreshShutUpBadge];
}


-(void) fastUserSwitchedOutNotification:(NSNotification*)notif
{
	if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseOnMainThreadFromGroup: @"USER SWITCHED OUT" withFillerString: nil];
	mooseDisableCount++;
	[self refreshShutUpBadge];
}


-(void)     hideMoose
{
    mooseVisibleCount--;
    
    UKLog( @"Hiding Moose (%d)", mooseVisibleCount );
    
	if( mooseVisibleCount < 0 )
		mooseVisibleCount = 0;
	
    if( mooseVisibleCount == 0 )
    {
		[currentMoose setDontIdleAnimate: ![animateInDockSwitch state]];
        if( fadeInOut )
        {
            UKLog( @"\tHit zero. Fading out." );
            [[imageView window] fadeOutWithDuration: 0.5];
            [[speechBubbleView window] fadeOutWithDuration: 0.5];
        }
        else
        {
            UKLog( @"\tHit zero. Hiding." );
            [[imageView window] orderOut: nil];
            [[speechBubbleView window] orderOut: nil];
        }
		
		/*if( rehideAppOnMooseHide )
		{
			[NSApp hide: nil];
			rehideAppOnMooseHide = NO;
		}*/
    }
}


@class UKSplotchChatterbot;

-(void)		splotchChatterbot: (UKSplotchChatterbot*)sender gaveAnswer: (NSString*)theAnswer
{
	[self speakString: theAnswer];
}

-(NSString*)	randomPhraseForSplotchChatterbot: (UKSplotchChatterbot*)sender
{
	return [phraseDB randomPhraseFromGroup: @"PAUSE"];
}


#if DEBUG && 0
void	UKLogBacktrace()
{
	void*	callstack[128];
	int		i,
			frames = backtrace(callstack, 128);
	char** strs = backtrace_symbols(callstack, frames);
	for (i = 0; i < frames; ++i)
	{
		UKLog(@"%s", strs[i]);
	}
	free(strs);
}
#endif


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
		// Make sure it's onscreen:
		NSRect		oldMooseFrame = [mooseWin frame],
					mooseFrame = oldMooseFrame;
		mooseFrame = [mooseWin constrainFrameRect: mooseFrame toScreen: [mooseWin screen]];
		if( mooseFrame.origin.x != oldMooseFrame.origin.x || mooseFrame.origin.y != oldMooseFrame.origin.y
			|| mooseFrame.size.width != oldMooseFrame.size.width || mooseFrame.size.height != oldMooseFrame.size.height )
		{
			UKLog(@"constraining moose rect %@ to %@", NSStringFromRect( oldMooseFrame ), NSStringFromRect( mooseFrame ));
			[mooseWin setFrame: mooseFrame display: YES];
		}
		else
			UKLog(@"no need to constrain rect %@.",NSStringFromRect( mooseFrame ));

		// Now actually show the Moose window:
        if( fadeInOut )
        {
            UKLog( @"\tHit 1. Fading in." );
            [mooseWin fadeInWithDuration: 0.5];
			if( showSpokenString )
				[[speechBubbleView window] fadeInWithDuration: 0.5];
        }
        else
        {
            UKLog( @"\tHit 1. Showing." );
            [mooseWin orderFrontRegardless];
            if( showSpokenString )
				[[speechBubbleView window] orderFrontRegardless];
        }
		[currentMoose setDontIdleAnimate: NO];
		[self pinWidgetsBoxToBotRight];
    }
	else
		UKLog(@"Not 1, leaving window untouched.");
    [mooseWin invalidateShadow];
}


- (void)windowDidBecomeMain: (NSNotification*)notification
{
    if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseFromGroup: @"LAUNCH SETUP"];
}


- (void)windowDidResignMain: (NSNotification*)notification
{
    if( mooseDisableCount == 0 && ![speechSynth isSpeaking] && ![recSpeechSynth isSpeaking] )
		[self speakPhraseFromGroup: @"QUIT SETUP"];
}


-(void)	moosePictClicked: (id)sender
{
	[self speakPhraseFromGroup: @"MOOSE SETTINGS PICTURE CLICKED"];
}



@end
