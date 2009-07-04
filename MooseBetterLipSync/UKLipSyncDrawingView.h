//
//  UKLipSyncDrawingView.h
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class UKMouthShape;

@interface UKLipSyncDrawingView : NSView
{
	UKMouthShape*	mouthShape;
	UKMouthShape*	otherMouthShape;
	int				draggedNode;		// Node being dragged.
	NSPoint			dragOffset;			// Distance between mouse and center of node at start of drag.
	float			percentageOfOther;	// Amount of previous shape to merge into current mouth shape. 0.0 is only show current, 1.0 is only show previous, 0.5 is a 50/50 mix between the two.
	BOOL			displayMergedOnly;	// Only display the merged shape, in black, and none of the others or the nodes.
	NSImage*		backgroundImage;	// Image to draw underneath the mouth shape.
}

-(void)		setMouthShape: (UKMouthShape*)shape;
-(void)		setOtherMouthShape: (UKMouthShape*)shape;

-(void)		setPercentageOfOther: (float)perc;
-(float)	percentageOfOther;

-(void)		setDisplayMergedOnly: (BOOL)state;
-(BOOL)		displayMergedOnly;

-(void)		setBackgroundImage: (NSImage*)bgImage;

@end
