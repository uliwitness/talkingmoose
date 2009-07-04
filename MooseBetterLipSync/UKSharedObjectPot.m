//
//  UKSharedObjectPot.m
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 05.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import "UKSharedObjectPot.h"


@implementation UKSharedObjectPot

+(id)	sharedObjectPot
{
	static UKSharedObjectPot*	sPot = nil;
	if( !sPot )
		sPot = [[UKSharedObjectPot alloc] init];
	return sPot;
}

-(id)	init
{
	self = [super init];
	if (self != nil)
	{
		objects = [[NSMutableArray alloc] init];
	}
	return self;
}


-(void)	dealloc
{
	DESTROY(objects);
	
	[super dealloc];
}


-(void)	shareObject: (id)obj owner: (id)own name: (NSString*)displayName
{
	if( obj == nil )
		return;
	
	NSDictionary*	dict = [NSDictionary dictionaryWithObjectsAndKeys:
												obj, @"object",
												[NSValue valueWithNonretainedObject: own], @"owner",
												displayName, @"name",
												nil];
	[objects addObject: dict];
	
	[self sendSharedObjectPotChanged];
}


-(void)	unshareObject: (id)obj owner: (id)own
{
	if( obj == nil )
		return;
	
	NSUInteger	x = 0, numObjs = [objects count];
	for( x = 0; x < numObjs; x++ )
	{
		NSDictionary*	dict = [objects objectAtIndex: x];
		id				cobj = [dict objectForKey: @"object"];
		id				cown = own ? [[dict objectForKey: @"owner"] nonretainedObjectValue] : nil;
		if( cobj == obj && cown == own )
		{
			[objects removeObjectAtIndex: x];
			break;
		}
	}
	
	[self sendSharedObjectPotChanged];
}


-(void)			unshareAllObjectsOfOwner: (id)own
{
	NSUInteger	x = 0,
				numObjs = [objects count];
	if( numObjs == 0 )
		return;
	for( x = (numObjs -1); YES; x-- )
	{
		NSDictionary*	dict = [objects objectAtIndex: x];
		id				cown = own ? [[dict objectForKey: @"owner"] nonretainedObjectValue] : nil;
		if( cown == own )
			[objects removeObjectAtIndex: x];
		
		if( x == 0 )
			break;
	}
	
	[self sendSharedObjectPotChanged];
}

-(NSUInteger)	count
{
	return [objects count];
}


-(id)	objectAtIndex: (NSUInteger)x
{
	NSDictionary*	dict = [objects objectAtIndex: x];
	return [dict objectForKey: @"object"];
}

-(NSString*)	nameOfObjectAtIndex: (NSUInteger)x
{
	NSDictionary*	dict = [objects objectAtIndex: x];
	return [dict objectForKey: @"name"];
}

-(id)	ownerOfObjectAtIndex: (NSUInteger)x
{
	NSDictionary*	dict = [objects objectAtIndex: x];
	return [[dict objectForKey: @"owner"] nonretainedObjectValue];
}

-(NSString*)	nameOfObject: (id)obj owner: (id)own
{
	NSUInteger	x = 0,
				numObjs = [objects count];
	for( x = 0; x < numObjs; x++ )
	{
		NSDictionary*	dict = [objects objectAtIndex: x];
		id				cobj = [dict objectForKey: @"object"];
		id				cown = own ? [[dict objectForKey: @"owner"] nonretainedObjectValue] : nil;
		if( cobj == obj && cown == own )
			return [dict objectForKey: @"name"];
	}
	
	return nil;
}


-(id)	ownerOfObject: (id)obj
{
	NSUInteger	x = 0,
				numObjs = [objects count];
	for( x = 0; x < numObjs; x++ )
	{
		NSDictionary*	dict = [objects objectAtIndex: x];
		id				cobj = [dict objectForKey: @"object"];
		if( cobj == obj )
			return [[dict objectForKey: @"owner"] nonretainedObjectValue];
	}
	
	return nil;
}

-(void)	sendSharedObjectPotChanged
{
	NSUInteger			x = 0,
						numObjs = [objects count];
	static NSUInteger	sCurrSession = 0;
	
	sCurrSession++;	// Start a new session, so callee can detect when they've been messaged twice.
	
	for( x = 0; x < numObjs; x++ )
	{
		NSDictionary*	dict = [objects objectAtIndex: x];
		id				cown = [[dict objectForKey: @"owner"] nonretainedObjectValue];
		
		if( [cown respondsToSelector: @selector(sharedObjectPotChanged:session:)] )
			[cown sharedObjectPotChanged: self session: sCurrSession];
	}
}


@end
