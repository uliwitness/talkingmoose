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
#import "UKBorderlessWindow.h"
#import "NSArray+Color.h"
#import "PTHotKey.h"
#import "PTKeyComboPanel.h"
//#import "NSWindow+Fade.h"
#include <Carbon/Carbon.h>
#import "UKCarbonEventHandler.h"
#import "UKMooseDragAreaView.h"
#import "UKMooseMouthImageRep.h"
#import "UKGroupFile.h"
#import "UKRecordedSpeechChannel.h"
#import "UKClickableImageView.h"
#import "UKFinderIconCell.h"
#import "UKHelperMacros.h"
#import "MooseHelper/ULIMooseServiceProtocol.h"
#import <ServiceManagement/ServiceManagement.h>

#if DEBUG && 0
#include <execinfo.h>
#include <stdio.h>
#endif


// -----------------------------------------------------------------------------
//	Constants:
// -----------------------------------------------------------------------------

#define UKUserAnimationsPath    "/Library/Application Support/Moose/Animations"
#define STRINGIFY2(n)			@"" #n
#define STRINGIFY(n)			STRINGIFY2(n)
#define UKUserPhrasesPath       "/Library/Application Support/Moose/Phrases"
#define UKHelperApplicationID	@"" STRINGIFY(UKApplicationGroupID) ".talkingmoose.macosx.helper"
#define MINIMUM_MOOSE_SIZE		48


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
		mooseControllers = [[NSMutableArray alloc] init];
		_sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName: STRINGIFY(UKApplicationGroupID)];
//		UKLog(@"%@: %@ %@", STRINGIFY(UKApplicationGroupID), _sharedDefaults, _sharedDefaults.dictionaryRepresentation);

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
	}
	
	return self;
}


// -----------------------------------------------------------------------------
//	* DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
	DESTROY(_mooseHelper);
	[_connectionToService invalidate];
	DESTROY(_connectionToService);
	
	DESTROY(speakNowHotkey);
	DESTROY(repeatLastPhraseHotkey);
	DESTROY(silenceMooseHotkey);
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
	
	DESTROY(mooseControllers);
	DESTROY(appSwitchEventHandler);
	
	[super dealloc];
}


// -----------------------------------------------------------------------------
//	NIB has been loaded, set up GUI:
// -----------------------------------------------------------------------------

-(void) awakeFromNib
{
	UKCrashReporterCheckForCrash();
		
	[mainTabView selectTabViewItemAtIndex: 0];
	
	[self loadMooseControllers];
	
    // Load settings from user defaults:
	[self loadSettingsFromDefaultsIntoUI];
    [self refreshSpeakHoursUI];
	
	[self refreshServiceConnection];
}


-(void) refreshServiceConnection
{
	if (!_connectionToService) {
		_connectionToService = [[NSXPCConnection alloc] initWithMachServiceName: UKHelperApplicationID options: 0];
		_connectionToService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ULIMooseServiceProtocol)];
		[_connectionToService resume];
	}
	_mooseHelper = [[_connectionToService remoteObjectProxyWithErrorHandler:^(NSError *error) { NSLog(@"XPC error: %@", error); }] retain];
}


-(IBAction)	orderFrontSecretAboutBox: (id)sender
{
	[_mooseHelper speakPhraseFromGroup: @"SECRET ABOUT BOX" withFillerString: @""];
	[secretAboutBox makeKeyAndOrderFront: self];
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
    NSString*   currAnim = [_sharedDefaults objectForKey: @"UKCurrentMooseAnimationPath"];

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
	
    // Update list and select current moose:
	[mooseList reloadData];
	[mooseList selectRowIndexes: [NSIndexSet indexSetWithIndex: currMooseIndex] byExtendingSelection: NO];	// Changes animation and may cause reset in scale factor:
}


// -----------------------------------------------------------------------------
//	Set up settings window GUI:
// -----------------------------------------------------------------------------

-(void)	loadSettingsFromDefaultsIntoUI
{
	//UKLog(@"About to Load.");
	
    // Hotkey shortcut edit fields:
	[speakNowHKField setStringValue: [speakNowHotkey stringValue]];
	[repeatLastPhraseHKField setStringValue: [repeatLastPhraseHotkey stringValue]];
	[silenceMooseHKField setStringValue: [silenceMooseHotkey stringValue]];
	
    // "Launch at startup" checkbox:
	NSString				*bundleID = UKHelperApplicationID;
	NSRunningApplication	*helperApp = [NSRunningApplication runningApplicationsWithBundleIdentifier: bundleID].firstObject;
	
	if( helperApp != nil )
		[launchAtLoginSwitch setState: YES];
	
	// Delay:
	NSNumber* delay = [_sharedDefaults objectForKey: @"UKMooseSpeechDelay"];
	if( delay != nil )
		[speechDelaySlider setDoubleValue: [delay doubleValue]];
	[self takeSpeechDelayFrom: speechDelaySlider];
	
	// Settings window:
	NSNumber*   num = [_sharedDefaults objectForKey: @"UKMoosePanelVisible"];
	if( !num || [num boolValue] )
		[[mooseList window] makeKeyAndOrderFront: self];
	
	// Checkboxes:
	NSNumber*   sspks = [_sharedDefaults objectForKey: @"UKMooseShowSpokenString"];
	showSpokenString = (sspks && [sspks boolValue]);
	[showSpokenStringSwitch setState: showSpokenString];
	
	NSNumber*   sovms = [_sharedDefaults objectForKey: @"UKMooseSpeakOnVolumeMount"];
	if( !sovms )
	{
		sovms = [NSNumber numberWithBool: YES];
		[_sharedDefaults setObject: sovms forKey: @"UKMooseSpeakOnVolumeMount"];
	}
	speakOnVolumeMount = [sovms boolValue];
	[speakOnVolMountSwitch setState: speakOnVolumeMount];

	NSNumber*   soalqs = [_sharedDefaults objectForKey: @"UKMooseSpeakOnAppLaunchQuit"];
	if( !soalqs )
	{
		soalqs = [NSNumber numberWithBool: YES];
		[_sharedDefaults setObject: soalqs forKey: @"UKMooseSpeakOnAppLaunchQuit"];
	}
	speakOnAppLaunchQuit = [soalqs boolValue];
	[speakOnAppLaunchQuitSwitch setState: speakOnAppLaunchQuit];
	
	NSNumber*   soacs = [_sharedDefaults objectForKey: @"UKMooseSpeakOnAppChange"];
	if( !soacs )
	{
		soacs = [NSNumber numberWithBool: YES];
		[_sharedDefaults setObject: soacs forKey: @"UKMooseSpeakOnAppChange"];
	}
	speakOnAppChange = [soacs boolValue];
	[speakOnAppChangeSwitch setState: speakOnAppChange];
	
	[self reloadHelperSettings];
	//UKLog(@"Loaded.");
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

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	alert.messageText = title;
	alert.informativeText = msg;
	[alert addButtonWithTitle: NSLocalizedString(@"Install",@"")];
	[alert addButtonWithTitle: NSLocalizedString(@"Cancel",@"")];
	
	[alert beginSheetModalForWindow: mooseList.window completionHandler: ^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			NSEnumerator*	enny = [filenames objectEnumerator];
			NSString*		currFilename = nil;
			NSMutableArray*	installedFileNames = [NSMutableArray array];
			
			while( (currFilename = [enny nextObject]) )
				[self application: sender openFile: currFilename dontAskButAddToList: installedFileNames];
			
			NSString *successMsg = NSLocalizedString(@"The following files have been installed:\n\n%@",@"Multiple Install Success Message");
			successMsg = [NSString stringWithFormat: successMsg, [installedFileNames componentsJoinedByString: @"\n"]];
			NSString *successTitle = [NSString stringWithFormat: NSLocalizedString(@"%d Files Installed.",@""), [installedFileNames count]];
			
			NSAlert *successAlert = [[[NSAlert alloc] init] autorelease];
			successAlert.messageText = successTitle;
			successAlert.informativeText = successMsg;
			[successAlert addButtonWithTitle: NSLocalizedString(@"OK",@"")];

			[successAlert beginSheetModalForWindow: mooseList.window completionHandler: ^(NSModalResponse returnCode) {
				[mooseList.window makeKeyAndOrderFront: self];
			}];
		}
	}];
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

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	alert.messageText = title;
	alert.informativeText = msg;
	[alert addButtonWithTitle: NSLocalizedString(@"Install",@"")];
	[alert addButtonWithTitle: NSLocalizedString(@"Cancel",@"")];
	
	if ([alert runModal] == NSModalResponseOK) {
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
		NSError * err = nil;
		if( ![NSFileManager.defaultManager createDirectoryAtPath: dirToCopyTo withIntermediateDirectories: NO attributes: @{} error: &err] ) {
			NSLog(@"Error %@ creating directory %@:", err, dirToCopyTo);
            return NO;
		}
        
		NSString*	itemName = [[NSFileManager defaultManager] displayNameAtPath: filename];
        dirToCopyTo = [dirToCopyTo stringByAppendingPathComponent: [filename lastPathComponent]];
        
		if( [[NSFileManager defaultManager] fileExistsAtPath: dirToCopyTo] ) {
			[[NSFileManager defaultManager] removeItemAtPath: dirToCopyTo error: &err];
		}
		
        if( [[NSFileManager defaultManager] copyItemAtPath: filename toPath: dirToCopyTo error: &err] )
        {
			if( isAnimation )
				[self loadAnimationAtPath: dirToCopyTo andReload: YES];
			else
				[phraseDB loadPhrasesInFile: dirToCopyTo];
            
			if( arr )
				[arr addObject: [NSString stringWithFormat: @"%@ (%@)", itemName, itemKindName]];
			else
			{
				NSString *title = NSLocalizedString(@"Installation successful.",@"");
				NSString *msg = NSLocalizedString(@"The %@ \"%@\" has been installed.",@"Install Success Message");
				msg = [NSString stringWithFormat: msg, itemKindName, itemName];
				
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				alert.messageText = title;
				alert.informativeText = msg;
				[alert addButtonWithTitle: NSLocalizedString(@"OK",@"")];
				
				[alert beginSheetModalForWindow: mooseList.window completionHandler: ^(NSModalResponse returnCode) {
					[mooseList.window makeKeyAndOrderFront: self];
				}];
			}
        }
    }
    
    return YES;
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}


-(void) applicationDidFinishLaunching: (NSNotification*)notif
{
	// Make a backup of our prefs file if this is first startup of new version:
	NSString*		currVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"];
	NSString*		lastPrefVersion = [_sharedDefaults objectForKey: @"UKMooseLastPrefsVersion"];
	if( !lastPrefVersion )
		lastPrefVersion = @"";
	if( ![lastPrefVersion isEqualToString: currVersion] )	// Compare version of Moose that last wrote prefs to ours:
	{
		NSError *err = nil;
		NSString*		prefsFile = [[NSString stringWithFormat: @"~/Library/Preferences/%@.plist", [[NSBundle mainBundle] bundleIdentifier]] stringByExpandingTildeInPath];
		NSString*		backupFile = [prefsFile stringByAppendingString: @".backup"];
		NSFileManager*	dfm = [NSFileManager defaultManager];
		BOOL			goOn = YES;
		
		// Copy prefs file to a backup file:
		if( [dfm fileExistsAtPath: backupFile] )
			goOn = [dfm removeItemAtPath: backupFile error: &err];
		if( goOn )
			[dfm copyItemAtPath:prefsFile toPath: backupFile error: &err];	// We don't really care if this fails
		
		// Remember we already did a backup:
		[_sharedDefaults setObject: currVersion forKey: @"UKMooseLastPrefsVersion"];
		[self reloadHelperSettings];
	}
	
	// Force update of Moose, even when we can't say "hello":
	[self refreshShutUpBadge];
	
#if 0
	int	*	crashy = 0;
	(*crashy) = 1;
#endif
}


-(void) loadAnimationsInFolder: (NSString*)folder
{
	NSError *err = nil;
	NSString*			animFolder = [folder stringByExpandingTildeInPath];
	UKMooseController*  newController = nil;
	
	for (NSString *currPath in [NSFileManager.defaultManager contentsOfDirectoryAtPath: animFolder error: &err]) {
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
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakTime"];
    [speakHoursSwitch setState: state];
    [speakHalfHoursSwitch setEnabled: state];
    [beAnallyRetentive setEnabled: state];
    [speakHalfHoursSwitch setState: [_sharedDefaults boolForKey: @"UKMooseSpeakTimeOnHalfHours"]];
    [beAnallyRetentive setState: [_sharedDefaults boolForKey: @"UKMooseSpeakTimeAnallyRetentive"]];
}


-(void) toggleSpeakHours: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakTime"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakTime"];
	[self reloadHelperSettings];

    [speakHalfHoursSwitch setEnabled: !state];
    [beAnallyRetentive setEnabled: !state];
}


-(void) toggleSpeakHalfHours: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakTimeOnHalfHours"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakTimeOnHalfHours"];
	[self reloadHelperSettings];
}


-(void) toggleAnallyRetentive: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakTimeAnallyRetentive"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakTimeAnallyRetentive"];
	[self reloadHelperSettings];
}


-(void) toggleSpeakVolumeMount: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakOnVolumeMount"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakOnVolumeMount"];
	[self reloadHelperSettings];
    speakOnVolumeMount = !state;
}


-(void) toggleSpeakAppLaunchQuit: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakOnAppLaunchQuit"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakOnAppLaunchQuit"];
	[self reloadHelperSettings];
    speakOnAppLaunchQuit = !state;
}


-(void) toggleSpeakAppChange: (id)sender
{
    BOOL                state = [_sharedDefaults boolForKey: @"UKMooseSpeakOnAppChange"];
    
    [_sharedDefaults setBool: !state forKey: @"UKMooseSpeakOnAppChange"];
	[self reloadHelperSettings];
    speakOnAppChange = !state;
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
		
		[fic setBgColor: nil];
		[fic setBoxColor: nil];
		[fic setNameColor: nil];
		[fic setSelectionColor: nil];
		[fic setStringValue: theName];
		[fic setImage: theImg];
		[fic setImagePosition: NSImageLeft];
	}
}

- (void)tableViewSelectionDidChange: (NSNotification *)notification
{
	[currentMoose setDelegate: nil];
	
	currentMoose = [mooseControllers objectAtIndex: [mooseList selectedRow]];
	
	[self mooseControllerDidChange];
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
	
	[_sharedDefaults setObject: [NSNumber numberWithDouble: theVal] forKey: @"UKMooseSpeechDelay"];
	[self reloadHelperSettings];

	[speechDelayField setStringValue: [NSString stringWithFormat: @"Every %d min.", ((int)trunc(theVal /60.0))]];
}


-(NSURL *) helperURL
{
	return [[[[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent: @"Contents"] URLByAppendingPathComponent: @"Library"] URLByAppendingPathComponent: @"LoginItems"] URLByAppendingPathComponent: UKHelperApplicationID ".app"];
}


-(void) takeLaunchAtLoginBoolFrom: (id)sender
{
	if ([NSRunningApplication runningApplicationsWithBundleIdentifier: UKHelperApplicationID].count == 0) {
		[self.launchProgressSpinner startAnimation: self];
	}
	
	BOOL shouldLaunch = [sender state] == NSControlStateValueOn;
	if (shouldLaunch) {
		LSRegisterURL((CFURLRef) self.helperURL, true);
	}
	SMLoginItemSetEnabled( (CFStringRef) UKHelperApplicationID, shouldLaunch );
	
	//[self performSelector: @selector(refreshServiceConnection) withObject: nil afterDelay: 3.0];
}


-(void) takeShowSpokenStringBoolFrom: (id)sender
{
	showSpokenString = [sender state];
	
	[_sharedDefaults setObject: [NSNumber numberWithBool: showSpokenString] forKey: @"UKMooseShowSpokenString"];
	[self reloadHelperSettings];
}


-(void) reloadHelperSettings
{
	[_sharedDefaults synchronize];
	[_mooseHelper reloadSettings];
}


-(void) mooseControllerDidChange
{
    //UKLog(@"mooseControllerDidChange");
    
	[_sharedDefaults setObject: [currentMoose filePath] forKey: @"UKCurrentMooseAnimationPath"];
	[self reloadHelperSettings];

    [self refreshShutUpBadge];
	
	UKLog(@"Moose controller changed to \"%@\".", [currentMoose filePath]);
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
	[_mooseHelper speakPhraseFromGroup: [dict objectForKey: @"Group"] withFillerString: [dict objectForKey: @"Filler"]];
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
	NSRunningApplication *launchedApp = notif.userInfo[NSWorkspaceApplicationKey];
	UKLog(@"App %@ launched", launchedApp);
	if ( [launchedApp.bundleIdentifier isEqualToString: UKHelperApplicationID] ) {
		[self.launchProgressSpinner stopAnimation: self];
		[_connectionToService invalidate];
		DESTROY(_connectionToService);
		[self refreshServiceConnection];
	}
	
	[self refreshShutUpBadge];
}


-(void) applicationTerminationNotification:(NSNotification*)notif
{
	NSRunningApplication *launchedApp = notif.userInfo[NSWorkspaceApplicationKey];
	UKLog(@"App %@ terminated", launchedApp);
	if( speakOnAppLaunchQuit )
	{
		NSString*		appName = [[[[notif userInfo] objectForKey: @"NSApplicationName"] retain] autorelease];
		UKLog(@"App %@ launched", launchedApp);
		if( ![appName isEqualToString: @"ScreenSaverEngine"]
			&& ![appName isEqualToString: @"ScreenSaverEngin"] )
		[self speakPhraseOnMainThreadFromGroup: @"QUIT APPLICATION" withFillerString: appName];
	}
	[self refreshShutUpBadge];
}


-(void) applicationSwitchNotification:(NSNotification*)notif
{
	//UKLog(@"applicationSwitchNotification");
	if( speakOnAppChange ) {
		// Don't speak if we're switching to this app, so the two methods bwlow get their shot:
		NSRunningApplication *activeApp = [NSWorkspace.sharedWorkspace frontmostApplication];
		if (![activeApp.bundleURL.path isEqualToString: NSBundle.mainBundle.bundlePath]) {
			NSString *appName = [[activeApp.localizedName retain] autorelease];
			[self speakPhraseOnMainThreadFromGroup: @"CHANGE APPLICATION" withFillerString: appName];
		}
	}
	[self refreshShutUpBadge];
}


-(void) applicationDidBecomeActive: (NSNotification *)notification
{
	[self speakPhraseOnMainThreadFromGroup: @"LAUNCH SETUP" withFillerString: nil];
	
	[self refreshShutUpBadge];
}

-(void) applicationDidResignActive: (NSNotification *)notification
{
	[self speakPhraseOnMainThreadFromGroup: @"QUIT SETUP" withFillerString: nil];
	
	[self refreshShutUpBadge];
}


-(void) speakString: (NSString *)msg
{
	[_mooseHelper speakString: msg];
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


-(IBAction) silenceMoose: (id)sender
{
	[self setMooseSilenced: self.mooseSilenced];
}


-(IBAction) speakOnePhrase: (id)sender
{
	[_mooseHelper speakPhraseFromGroup:@"PAUSE" withFillerString:@""];
}


-(IBAction)repeatLastPhrase:(id)sender
{
	[_mooseHelper repeatLastPhrase];
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

-(void) speakPhraseFromGroup: (NSString *)group  withFillerString: (NSString *)filler
{
	[_mooseHelper speakPhraseFromGroup: group withFillerString: filler];
}


- (void)windowDidBecomeMain: (NSNotification*)notification
{
	[self speakPhraseFromGroup: @"LAUNCH SETUP" withFillerString: @""];
}


- (void)windowDidResignMain: (NSNotification*)notification
{
	[self speakPhraseFromGroup: @"QUIT SETUP" withFillerString: @""];
}


-(void)	moosePictClicked: (id)sender
{
	[self speakPhraseFromGroup: @"MOOSE SETTINGS PICTURE CLICKED" withFillerString: @""];
}

@end
