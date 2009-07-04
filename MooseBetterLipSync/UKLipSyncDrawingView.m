//
//  UKLipSyncDrawingView.m
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import "UKLipSyncDrawingView.h"
#import "UKMouthShape.h"


@implementation UKLipSyncDrawingView

-(id)	initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		draggedNode = -1;
		percentageOfOther = 0.5;
    }
    return self;
}


-(void) dealloc
{
	[mouthShape release];
	mouthShape = nil;
	[otherMouthShape release];
	otherMouthShape = nil;
	[backgroundImage release];
	backgroundImage = nil;
	
	[super dealloc];
}


-(void)		setPercentageOfOther: (float)perc
{
	percentageOfOther = perc;
	[self setNeedsDisplay: YES];
}


-(float)	percentageOfOther
{
	return percentageOfOther;
}


-(void)	drawRect:(NSRect)rect
{
    if( mouthShape )
	{
		// Get this shape and previous shape, and generate an intermediate one:
		UKMouthShape*	mergedShape = nil;
		if( otherMouthShape )
			mergedShape = [mouthShape mouthShapeByMergingWithShape: otherMouthShape percentageOfOther: percentageOfOther];
		
		if( backgroundImage )
			[backgroundImage drawInRect: [self bounds] fromRect: NSZeroRect operation: NSCompositeSourceAtop fraction: 1.0];
		
		if( displayMergedOnly )
		{
			NSImage*	img = [NSImage imageNamed: @"MouthContentImage"];
			[[NSColor blackColor] setStroke];
			if( mergedShape )
				[mergedShape drawInRect: [self bounds] displayArea: rect insideImage: img];
			else
				[mouthShape drawInRect: [self bounds] displayArea: rect insideImage: img];
		}
		else
		{
			// Draw center indicator:
			[NSBezierPath setDefaultLineWidth: 1.0];
			[[NSColor greenColor] setStroke];
			[NSBezierPath strokeLineFromPoint: NSMakePoint(([self bounds].size.width /2),([self bounds].size.height /2) +5)
								toPoint: NSMakePoint(([self bounds].size.width /2),([self bounds].size.height /2) -5)];
			[NSBezierPath strokeLineFromPoint: NSMakePoint(([self bounds].size.width /2) +5,([self bounds].size.height /2))
								toPoint: NSMakePoint(([self bounds].size.width /2) -5,([self bounds].size.height /2))];
			
			// Draw box indicating valid area:
			[[NSColor blueColor] setStroke];
			[NSBezierPath strokeRect: [self bounds]];
			
			// Draw previous and merged shapes in grey:
			[[NSColor grayColor] setStroke];
			[otherMouthShape drawInRect: [self bounds] displayArea: rect insideImage: nil];
			[[NSColor lightGrayColor] setStroke];
			[mergedShape drawInRect: [self bounds] displayArea: rect insideImage: nil];
			
			// Draw current shape and its dots so user knows where to click:
			[[NSColor blackColor] setStroke];
			[mouthShape drawInRect: [self bounds] displayArea: rect insideImage: nil];
			[[NSColor blueColor] setFill];
			[mouthShape drawPointsInRect: [self bounds] displayArea: rect];
		}
	}
}


-(void)	mouseDown: (NSEvent*)evt
{
    if( mouthShape )
	{
		NSPoint			localClickPos = [evt locationInWindow];
		localClickPos = [self convertPoint: localClickPos fromView: nil];
		draggedNode = [mouthShape pointClicked: localClickPos inRect: [self bounds]];
		
		if( draggedNode >= 0 )
		{
			NSPoint		nodePos = [mouthShape positionOfPointAtIndex: draggedNode inRect: [self bounds]];
			dragOffset.x = nodePos.x -localClickPos.x;
			dragOffset.y = nodePos.y -localClickPos.y;
		}
	}
}


-(void)	mouseDragged: (NSEvent*)evt
{
	if( mouthShape )
	{
		if( draggedNode >= 0 )
		{
			NSPoint			localClickPos = [evt locationInWindow];
			localClickPos = [self convertPoint: localClickPos fromView: nil];
			
			NSPoint			newPos;
			newPos.x = localClickPos.x +dragOffset.x;
			newPos.y = localClickPos.y +dragOffset.y;
			
			[mouthShape setPosition: newPos atIndex: draggedNode inRect: [self bounds]];
			[self setNeedsDisplay: YES];
			
			// Make sure any associated documents get marked dirty:
			NSDocument*	doc = [[[self window] windowController] document];
			[doc updateChangeCount: NSChangeDone];
			
			[[self window] invalidateCursorRectsForView: self];
		}
		else if( draggedNode == UKMouthShapeAllPoints )
		{
			[mouthShape moveAllPointsBy: NSMakePoint( [evt deltaX], -[evt deltaY]) inRect: [self bounds]];
			[self setNeedsDisplay: YES];
			
			// Make sure any associated documents get marked dirty:
			NSDocument*	doc = [[[self window] windowController] document];
			[doc updateChangeCount: NSChangeDone];
			
			[[self window] invalidateCursorRectsForView: self];
		}
	}
}


-(void)		setMouthShape: (UKMouthShape*)shape
{
	ASSIGN(mouthShape,shape);
	[self setNeedsDisplay: YES];
}


-(void)		setOtherMouthShape: (UKMouthShape*)shape
{
	ASSIGN(otherMouthShape,shape);
	[self setNeedsDisplay: YES];
}

-(void)		setDisplayMergedOnly: (BOOL)state
{
	displayMergedOnly = state;
	[self setNeedsDisplay: YES];
}


-(BOOL)		displayMergedOnly
{
	return displayMergedOnly;
}


-(void)	resetCursorRects
{
	int		x = 0,
			numNodes = [mouthShape countPoints];
	
	for( x = 0; x < numNodes; x++ )
	{
		NSRect	clickBox = NSIntersectionRect( [mouthShape clickRectOfPointAtIndex: x inRect: [self bounds]], [self visibleRect]);
		[self addCursorRect: clickBox cursor: [NSCursor crosshairCursor]];
	}
}


-(void)		setBackgroundImage: (NSImage*)bgImage
{
	ASSIGN(backgroundImage,bgImage);
	[self setNeedsDisplay: YES];
}

@end
