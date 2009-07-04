//
//  UKSharedObjectPot.h
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 05.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UKSharedObjectPot : NSObject
{
	NSMutableArray*	objects;	// Array of dictionaries. Each one contains a @"name", an @"owner" and an @"object". The owner is *not* retained!
}

+(id)			sharedObjectPot;

-(void)			shareObject: (id)obj owner: (id)own name: (NSString*)displayName;
-(void)			unshareObject: (id)obj owner: (id)own;	// own may be nil to mean any owner.
-(void)			unshareAllObjectsOfOwner: (id)own;		// own may be nil to mean any owner.

-(NSUInteger)	count;
-(id)			objectAtIndex: (NSUInteger)x;
-(NSString*)	nameOfObjectAtIndex: (NSUInteger)x;
-(NSString*)	nameOfObject: (id)obj owner: (id)own;	// own may be nil to mean any owner.
-(id)			ownerOfObjectAtIndex: (NSUInteger)x;
-(id)			ownerOfObject: (id)obj;

-(void)			sendSharedObjectPotChanged;

@end


@protocol UKSharedObjectPotClient
@optional
// Any owner that has shared an object receives the following message for each 
//	object it shares whenever the pot changes. If you're only interested in one
//	notification even though you're sharing several objects, you can use the
//	session number to detect whether this is still the same change.
-(void)	sharedObjectPotChanged: (UKSharedObjectPot*)thePot session: (NSUInteger)sessionNum;
@end