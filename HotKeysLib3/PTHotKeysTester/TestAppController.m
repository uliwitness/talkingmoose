//
//  TestAppController.m
//  PTHotKeysTester
//
//  Created by Quentin Carnicelli on Wed Jul 14 2004.
//  Copyright (c) 2004 Quentin D. Carnicelli. All rights reserved.
//

#import "TestAppController.h"

#import "PTHotKey.h"
#import "PTHotKeyCenter.h"
#import "PTKeyComboPanel.h"

@implementation TestAppController

- (void)refreshViews
{
	NSString* desc = [[mHotKey keyCombo] description];

	[mHotKeyDescriptionField setStringValue: desc];
	[mResultsField setStringValue: @""];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	id keyComboPlist;
	PTKeyCombo* keyCombo = nil;
	
	//Read our keycombo in from preferences
	keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey: @"testKeyCombo"];
	keyCombo = [[[PTKeyCombo alloc] initWithPlistRepresentation: keyComboPlist] autorelease];

	//Create our hot key
	mHotKey = [[PTHotKey alloc] initWithIdentifier: @"testHotKey" keyCombo: keyCombo];	
	[mHotKey setName: @"Test HotKey"]; //This is typically used by PTKeyComboPanel
	[mHotKey setTarget: self];
	[mHotKey setAction: @selector( hitHotKey: ) ];

	//Register it
	[[PTHotKeyCenter sharedCenter] registerHotKey: mHotKey];

	//Update our test window
	[self refreshViews];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	//Save our keycombo to preferences
	[[NSUserDefaults standardUserDefaults] setObject: [[mHotKey keyCombo] plistRepresentation] forKey: @"testKeyCombo"];

	//Unregister our hot key (not required)
	[[PTHotKeyCenter sharedCenter] unregisterHotKey: mHotKey];

	//Memory cleanup
	[mHotKey release];
	mHotKey = nil;
}

- (IBAction)hitHotKey: (id)sender
{
	[mResultsField setStringValue:
		[NSString stringWithFormat: @"%@\n%@",
			sender, [NSCalendarDate calendarDate]]];
}

#pragma mark -

/*
	Example of running the KeyComboPanel (as a sheet here)
*/

- (void)hotKeySheetDidEndWithReturnCode: (NSNumber*)resultCode
{
	if( [resultCode intValue] == NSOKButton )
	{
		//Update our hotkey with the new keycombo
		[mHotKey setKeyCombo: [[PTKeyComboPanel sharedPanel] keyCombo]];
		
		//Re-register it (required)
		[[PTHotKeyCenter sharedCenter] registerHotKey: mHotKey];
		
		//Update our window
		[self refreshViews];
	}
}

- (IBAction)hitSetHotKey: (id)sender
{
	PTKeyComboPanel* panel = [PTKeyComboPanel sharedPanel];
	[panel setKeyCombo: [mHotKey keyCombo]];
	[panel setKeyBindingName: [mHotKey name]];
	[panel runSheeetForModalWindow: [mHotKeyDescriptionField window] target: self];
}



@end

#pragma mark -

/*
	MacOS X 10.1 Support:
	
	If you are still supporting 10.1, this is how you make HotKeysLib work on it.
	You sublcass NSApplication, then override sendEvent: and pass all events to PTHotKeyCenter.
*/

@interface TestApplication : NSApplication
{
}
@end

@implementation TestApplication

- (void)sendEvent: (NSEvent*)event
{
	[[PTHotKeyCenter sharedCenter] sendEvent: event];
	[super sendEvent: event];
}

@end

#pragma mark -

int main(int argc, const char *argv[])
{
    return NSApplicationMain(argc, argv);
}
