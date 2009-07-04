//
//  MyDocument.m
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright The Void Software 2007 . All rights reserved.
//

#import "MyDocument.h"
#import "UKLipSyncDrawingView.h"
#import "UKMouthShape.h"
#import "UKSharedObjectPot.h"


@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self)
	{
		#if 1
		// Oh:
		shape = [[UKMouthShape alloc] init];
		[shape addCornerPoint: NSMakePoint(45, 60) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(45, 80) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(75, 80) inRect: NSZeroRect];
		[shape addCornerPoint: NSMakePoint(75, 60) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(75, 40) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(45, 40) inRect: NSZeroRect];
		#else
		// Eee:
		shape = [[UKMouthShape alloc] init];
		[shape addCornerPoint: NSMakePoint(10, 60) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(35, 70) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(75, 70) inRect: NSZeroRect];
		[shape addCornerPoint: NSMakePoint(110, 60) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(75, 50) inRect: NSZeroRect];
		[shape addCurvePoint: NSMakePoint(35, 50) inRect: NSZeroRect];
		#endif
	}
    return self;
}


- (void) dealloc
{
	[[UKSharedObjectPot sharedObjectPot] unshareAllObjectsOfOwner: self];
	DESTROY(shape);
	
	[super dealloc];
}



- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	if( shape )
	{
		[lipView setMouthShape: shape];
		[lipView setFrameSize: [shape size]];
		[[UKSharedObjectPot sharedObjectPot] unshareObject: shape owner: self];
		[[UKSharedObjectPot sharedObjectPot] shareObject: shape owner: self name: [self displayName]];
	}
	// Make sure popup is current.
}

-(NSData*)	dataOfType:(NSString *)typeName error:(NSError **)outError
{
	return [shape dataRepresentation];
}

-(BOOL)	readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	[[UKSharedObjectPot sharedObjectPot] unshareObject: shape owner: self];
    
	ASSIGN(shape,[UKMouthShape mouthShapeWithData: data]);
	
	if( shape )
	{
		if( lipView )
		{
			[lipView setMouthShape: shape];
			[lipView setFrameSize: [shape size]];
		}
		[[UKSharedObjectPot sharedObjectPot] shareObject: shape owner: self name: [self displayName]];
	}
    return YES;
}

-(void)	sharedObjectPotChanged: (UKSharedObjectPot*)thePot session: (NSUInteger)sessionNum
{
	[prevShapePopup removeAllItems];
	NSUInteger	x = 0,
				numObjs = [[UKSharedObjectPot sharedObjectPot] count];
	for( x = 0; x < numObjs; x++ )
		[prevShapePopup addItemWithTitle: [[UKSharedObjectPot sharedObjectPot] nameOfObjectAtIndex: x]];
	[prevShapePopup synchronizeTitleAndSelectedItem];
}

-(IBAction)	userChosePreviousShape: (id)sender
{
	int				choice = [sender indexOfSelectedItem];
	UKMouthShape*	aShape = [[UKSharedObjectPot sharedObjectPot] objectAtIndex: choice];
	if( [[UKSharedObjectPot sharedObjectPot] ownerOfObjectAtIndex: choice] == self )
		aShape = nil;
	[lipView setOtherMouthShape: aShape];
}


-(IBAction)	selectBackgroundImage: (id)sender
{
	NSOpenPanel*	panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles: YES];
	[panel setCanChooseDirectories: NO];
	[panel setAllowsMultipleSelection: NO];
	[panel setAllowsMultipleSelection: NO];
	if( [panel runModalForTypes: [NSImage imageFileTypes]] == NSOKButton )
	{
		NSImage*		img = [[[NSImage alloc] initWithContentsOfFile: [panel filename]] autorelease];
		[lipView setBackgroundImage: img];
	}
}

-(IBAction)	percentOfOtherSliderChanged: (id)sender
{
	[lipView setPercentageOfOther: [sender floatValue]];
}


-(IBAction)	onlyDrawMergedSwitchChanged: (id)sender
{
	[lipView setDisplayMergedOnly: [sender state]];
}


@end
