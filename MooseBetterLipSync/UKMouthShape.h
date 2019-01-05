//
//  UKMouthShape.h
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef struct _UKMouthPoint
{
	NSPoint		pos;			// Actual point where we draw.
	BOOL		isHardCorner;	// Is this a "hard" corner, or just a point which a curve goes through?
} UKMouthPoint;


// Special values returned by pointClicked:inRect:
//	These are guaranteed to be < 0, because >= 0 are all valid indexes.
enum
{
	UKMouthShapeNoPoints	= -1,	// User clicked outside the shape.
	UKMouthShapeAllPoints	= -2	// User clicked inside the shape, but hit no point directly.
};


// A UKMouthShape's points live in a virtual 120 x 120 pixel box, and should be
//	centered around the 60,60 point so merging shapes works correctly.

@interface UKMouthShape : NSObject <NSCopying>
{
	UKMouthPoint*	points;
	NSUInteger		numPoints;
	NSSize			imageSize;
}

+(id)				mouthShape;
+(id)				mouthShapeWithDictionary: (NSDictionary*)arr;
+(id)				mouthShapeWithData: (NSData*)fdata;
+(id)				mouthShapeWithContentsOfFile: (NSString*)fpath;

//-(id)	init;		// also available.
-(id)				initWithDictionary: (NSDictionary*)arr;
-(id)				initWithData: (NSData*)fdata;
-(id)				initWithContentsOfFile: (NSString*)fpath;

-(NSSize)			size;
-(void)				setSize: (NSSize)sz;

-(UKMouthShape*)	mouthShapeByMergingWithShape: (UKMouthShape*)otherShape percentageOfOther: (float)perc;

-(NSDictionary*)	dictionaryRepresentation;
-(NSData*)			dataRepresentation;

-(int)				countPoints;
-(void)				addCurvePoint: (NSPoint)pos inRect: (NSRect)box;
-(void)				addCornerPoint: (NSPoint)pos inRect: (NSRect)box;
-(NSPoint)			positionOfPointAtIndex: (int)idx inRect: (NSRect)box;
-(void)				setPosition: (NSPoint)pos atIndex: (int)idx inRect: (NSRect)box;
-(void)				moveAllPointsBy: (NSPoint)distance inRect: (NSRect)box;
-(NSRect)			clickRectOfPointAtIndex: (int)idx inRect: (NSRect)box;

-(void)				drawInRect: (NSRect)box displayArea: (NSRect)dirtyRect insideImage: (NSImage*)img;
-(void)				drawPointsInRect: (NSRect)box displayArea: (NSRect) dirtyRect;
-(int)				pointClicked: (NSPoint)clickPos inRect: (NSRect)box;

-(NSBezierPath*)	pathInRect: (NSRect)box;

@end
