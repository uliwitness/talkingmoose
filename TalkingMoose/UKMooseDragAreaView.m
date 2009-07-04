//
//  UKMooseDragAreaView.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 16.08.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "UKMooseDragAreaView.h"


@implementation UKMooseDragAreaView

-(id)	initWithFrame: (NSRect)frame
{
    self = [super initWithFrame:frame];
    if( self )
	{
        // Initialization code here.
    }
    return self;
}

-(void)	drawRect: (NSRect)rect
{
	[[NSColor colorWithCalibratedWhite: 0.6 alpha: 0.9] set];
	
    NSBezierPath*	path = [NSBezierPath bezierPath];
	NSRect			box = [self bounds];
	float			halfHeight = truncf(box.size.height / 2.0);
	NSPoint			midPt = NSMakePoint( truncf(box.size.height / 2.0), NSMidY(box)),
					midRightPt = NSMakePoint( box.size.width, NSMidY(box));
	[path moveToPoint: NSMakePoint(midRightPt.x, NSMaxY(box))];
	[path lineToPoint: NSMakePoint(midPt.x, NSMaxY(box))];
	[path appendBezierPathWithArcWithCenter: midPt
				radius: halfHeight
				startAngle: 270.0
				endAngle: 90.0
				clockwise: YES];
	[path lineToPoint: NSMakePoint(midPt.x, NSMinY(box))];
	[path appendBezierPathWithArcWithCenter: midRightPt
				radius: halfHeight
				startAngle: 270.0
				endAngle: 90.0
				clockwise: YES];
	[path setLineWidth: 3.0];
	[path setLineCapStyle: NSRoundLineCapStyle];
	[path setLineJoinStyle: NSRoundLineJoinStyle];
	[path fill];
}


-(void)	mouseDown: (NSEvent*)evt
{
	NSLog(@"foo");
	[target performSelector: action withObject: self];
}


-(id)	target
{
	return target;
}


-(void)	setTarget:(id)anObject
{
	target = anObject;
}


-(SEL)	action
{
	return action;
}


-(void)	setAction:(SEL)aSelector
{
	action = aSelector;
}


-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

-(void)	resetCursorRects
{
	if( cursor )
		[self addCursorRect: [self bounds] cursor: cursor];
}


-(void)	setCursor: (NSCursor*)theCursor
{
	[theCursor retain];
	[cursor release];
	cursor = theCursor;
}

-(NSCursor*)	cursor
{
	return cursor;
}

@end
