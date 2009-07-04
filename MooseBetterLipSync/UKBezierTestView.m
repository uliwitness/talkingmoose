//
//  UKBezierTestView.m
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import "UKBezierTestView.h"


@implementation UKBezierTestView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        startPoint = NSMakePoint( 10, 50);
        endPoint = NSMakePoint( 100, 50);
		cp1 = endPoint;
		cp2 = endPoint;
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
    NSBezierPath*	path = [NSBezierPath bezierPath];
	[[NSColor blackColor] set];
	[path moveToPoint: startPoint];
	[path curveToPoint: endPoint controlPoint1: cp1 controlPoint2: cp2];
	
	[[NSColor redColor] set];
	[NSBezierPath fillRect: NSMakeRect( cp1.x -2, cp1.y -2, 4, 4 )];

	[[NSColor blueColor] set];
	[NSBezierPath fillRect: NSMakeRect( cp2.x -2, cp2.y -2, 4, 4 )];
	
	[path stroke];
}

-(void)	mouseDown: (NSEvent*)evt
{
	NSPoint		localClickPos = [evt locationInWindow];
	localClickPos = [self convertPoint: localClickPos fromView: nil];
	if( [evt modifierFlags] & NSAlternateKeyMask )
		cp2 = localClickPos;
	else
		cp1 = localClickPos;
	[self setNeedsDisplay: YES];
}

@end
