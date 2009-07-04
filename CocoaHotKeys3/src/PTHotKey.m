//
//  PTHotKey.m
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTHotKey.h"

#import "PTHotKeyCenter.h"
#import "PTKeyCombo.h"

@implementation PTHotKey

- (id)init
{
	self = [super init];
	
	if( self )
	{
		[self setKeyCombo: [PTKeyCombo clearKeyCombo]];
	}
	
	return self;
}

-(id)   initWithName: (NSString*)nm // UK 2004-04-15
{
	[self init];
	
	if( self )
	{
		[self setName: nm];
		[self readFromStandardDefaults];
	}
	
	return self;
}

- (id)initWithName: (NSString*)nm target: (id)tg action: (SEL)ac addToCenter: (BOOL)n // UK 2004-04-15
{
	[self init];
	
	if( self )
	{
		[self setName: nm];
		[self setTarget: tg];
		[self setAction: ac];
		[self readFromStandardDefaults];
		if( n )
			[[PTHotKeyCenter sharedCenter] registerHotKey: self];
	}
	
	return self;
}

- (void)dealloc
{
	[[PTHotKeyCenter sharedCenter] unregisterHotKey: self]; // UK 2004-04-15
	[mName release];
	[mKeyCombo release];
	
	[super dealloc];
}

- (NSString*)description
{
	return [NSString stringWithFormat: @"<%@: %@>", NSStringFromClass( [self class] ), [self keyCombo]];
}

- (NSString*)stringValue   // UK 2004-04-15
{
	return [[self keyCombo] description];
}

#pragma mark -

- (void)setKeyCombo: (PTKeyCombo*)combo
{
	[combo retain];
	[mKeyCombo release];
	mKeyCombo = combo;
}

- (PTKeyCombo*)keyCombo
{
	return mKeyCombo;
}

- (void)setName: (NSString*)name
{
	[name retain];
	[mName release];
	mName = name;
}

- (NSString*)name
{
	return mName;
}

- (void)setTarget: (id)target
{
	mTarget = target;
}

- (id)target
{
	return mTarget;
}

- (void)setAction: (SEL)action
{
	mAction = action;
}

- (SEL)action
{
	return mAction;
}

- (void)invoke
{
	[mTarget performSelector: mAction withObject: self];
}

-(void) writeToStandardDefaults	// UK 2004-04-15
{
	[self writeToDefaults: [NSUserDefaults standardUserDefaults]];
}


-(void) writeToDefaults: (NSUserDefaults*)ud	// UK 2004-04-15
{
	if( !mName )
		return;
	
	NSString*		prefsKey = [@"PTHotKey " stringByAppendingString: mName];
	
	[ud setObject: [mKeyCombo plistRepresentation] forKey: prefsKey];
}

-(void) readFromStandardDefaults	// UK 2004-04-15
{
	[self readFromDefaults: [NSUserDefaults standardUserDefaults]];
}


-(void) readFromDefaults: (NSUserDefaults*)ud	// UK 2004-04-15
{
	if( !mName )
		return;
	
	NSString*		prefsKey = [@"PTHotKey " stringByAppendingString: mName];
	NSDictionary*	plistRep = [ud objectForKey: prefsKey];
	
	if( plistRep )
	{
		PTKeyCombo* combo = [[PTKeyCombo alloc] initWithPlistRepresentation: plistRep];
		[self setKeyCombo: combo];
	}
}

@end
