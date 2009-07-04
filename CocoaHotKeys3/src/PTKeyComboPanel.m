//
//  PTKeyComboPanel.m
//  Protein
//
//  Created by Quentin Carnicelli on Sun Aug 03 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTKeyComboPanel.h"

#import "PTHotKey.h"
#import "PTKeyCombo.h"
#import "PTKeyBroadcaster.h"
#import "PTHotKeyCenter.h"

#if __PROTEIN__
#import "PTNSObjectAdditions.h"
#endif

@implementation PTKeyComboPanel

static id _sharedKeyComboPanel = nil;

+ (id)sharedPanel
{
	if( _sharedKeyComboPanel == nil )
	{
		_sharedKeyComboPanel = [[self alloc] init];
	
		#if __PROTEIN__
			[_sharedKeyComboPanel releaseOnTerminate];
		#endif
	}

	return _sharedKeyComboPanel;
}

- (id)init
{
	return [self initWithWindowNibName: @"PTKeyComboPanel"];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[mKeyName release];
	[mTitleFormat release];

	[super dealloc];
}

- (void)windowDidLoad
{
	mTitleFormat = [[mTitleField stringValue] retain];

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector( noteKeyBroadcast: )
		name: PTKeyBroadcasterKeyEvent
		object: mKeyBcaster];
}

- (void)_refreshContents
{
	if( mComboField )
		[mComboField setStringValue: [mKeyCombo description]];

	if( mTitleField )
		[mTitleField setStringValue: [NSString stringWithFormat: mTitleFormat, mKeyName]];
}

- (int)runModal
{
	int resultCode;

	[self window]; //Force us to load

	[self _refreshContents];
	[[self window] center];
	[self showWindow: self];
	resultCode = [[NSApplication sharedApplication] runModalForWindow: [self window]];
	[self close];

	return resultCode;
}

- (void)runModalForHotKey: (PTHotKey*)hotKey
{
	int resultCode;

	[self setKeyBindingName: [hotKey name]];
	[self setKeyCombo: [hotKey keyCombo]];

	resultCode = [self runModal];
	
	if( resultCode == NSOKButton )
	{
		[hotKey setKeyCombo: [self keyCombo]];
		[[PTHotKeyCenter sharedCenter] registerHotKey: hotKey];
	}
}

#pragma mark -

- (void)setKeyCombo: (PTKeyCombo*)combo
{
	[combo retain];
	[mKeyCombo release];
	mKeyCombo = combo;
	[self _refreshContents];
}

- (PTKeyCombo*)keyCombo
{
	return mKeyCombo;
}

- (void)setKeyBindingName: (NSString*)name
{
	[name retain];
	[mKeyName release];
	mKeyName = name;
	[self _refreshContents];
}

- (NSString*)keyBindingName
{
	return mKeyName;
}

#pragma mark -

- (IBAction)ok: (id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode: NSOKButton];
}

- (IBAction)cancel: (id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode: NSCancelButton];
}

- (IBAction)clear: (id)sender
{
	[self setKeyCombo: [PTKeyCombo clearKeyCombo]];
	[[NSApplication sharedApplication] stopModalWithCode: NSOKButton];
}

- (void)noteKeyBroadcast: (NSNotification*)note
{
	PTKeyCombo* keyCombo;
	
	keyCombo = [[note userInfo] objectForKey: @"keyCombo"];

	[self setKeyCombo: keyCombo];
}

@end
