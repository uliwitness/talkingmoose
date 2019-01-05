//
//  UKMouthShape.m
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright 2007 The Void Software. All rights reserved.
//

#import "UKMouthShape.h"
#import "UKHelperMacros.h"


#define MAX_POINTS		16
#define DEFAULT_WIDTH	120.0f
#define DEFAULT_HEIGHT	120.0f


static NSPoint	UKExternalPointForRect( NSPoint origPos, NSSize internalSize, NSRect box )
{
	if( box.origin.x == 0 && box.origin.y == 0 && box.size.width == 0 && box.size.height == 0 )
		box.size = internalSize;
	
	float		hScale = box.size.width / internalSize.width,
				vScale = box.size.height / internalSize.height;
	NSPoint		pos;
	
	pos.x = origPos.x * hScale;
	pos.y = origPos.y * vScale;
	
	return pos;
}


static NSPoint	UKLocalPointForRect( NSPoint origPos, NSSize internalSize, NSRect box )
{
	if( box.origin.x == 0 && box.origin.y == 0 && box.size.width == 0 && box.size.height == 0 )
		box.size = internalSize;
	
	float		hScale = internalSize.width / box.size.width,
				vScale = internalSize.height / box.size.height;
	NSPoint		pos;
	
	pos.x = origPos.x * hScale;
	pos.y = origPos.y * vScale;
	
	return pos;
}


@implementation UKMouthShape

+(id)	mouthShape
{
	return [[[[self class] alloc] init] autorelease];
}

+(id)	mouthShapeWithDictionary: (NSDictionary*)arr
{
	return [[[[self class] alloc] initWithDictionary: arr] autorelease];
}

+(id)	mouthShapeWithContentsOfFile: (NSString*)fpath
{
	return [[[[self class] alloc] initWithContentsOfFile: fpath] autorelease];
}

+(id)	mouthShapeWithData: (NSData*)fdata
{
	return [[[[self class] alloc] initWithData: fdata] autorelease];
}

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		points = malloc(sizeof(UKMouthPoint) * MAX_POINTS);
		numPoints = 0;
		imageSize = NSMakeSize(DEFAULT_WIDTH,DEFAULT_HEIGHT);
	}
	return self;
}


-(id)	initWithDictionary: (NSDictionary*)enclosingDict
{
	self = [self init];
	if( self != nil )
	{
		NSString*	imgSizeStr = [enclosingDict objectForKey: @"UKImageSize"];
		if( imgSizeStr )
			imageSize = NSSizeFromString( imgSizeStr );
		else
			imageSize = NSMakeSize(DEFAULT_WIDTH,DEFAULT_HEIGHT);
		
		NSArray*	arr = [enclosingDict objectForKey: @"UKMouthPoints"];
		NSUInteger	arrCount = [arr count], x = 0;
		for( x = 0; x < arrCount; x++ )
		{
			NSDictionary*	dict = [arr objectAtIndex: x];
			NSString*		strPos = [dict objectForKey: @"UKPosition"];
			if( !strPos || ![strPos isKindOfClass: [NSString class]] )
			{
				[self autorelease];
				return nil;
			}
			points[x].pos = NSPointFromString( strPos );
			NSNumber*	isHardCornerBool = [dict objectForKey: @"UKIsHardCorner"];
			BOOL		isHardCorner = YES;
			if( isHardCornerBool && [isHardCornerBool isKindOfClass: [NSNumber class]] )
				isHardCorner = [isHardCornerBool boolValue];
			points[x].isHardCorner = isHardCorner;
		}
		numPoints = arrCount;
	}
	
	return self;
}


-(id)	initWithContentsOfFile: (NSString*)fpath
{
	NSData*					fdata = [NSData dataWithContentsOfFile: fpath];
	NSString*				errStr = nil;
	NSPropertyListFormat	format = NSPropertyListOpenStepFormat;
	NSDictionary*			dict = [NSPropertyListSerialization propertyListFromData: fdata
										mutabilityOption: NSPropertyListImmutable
										format: &format errorDescription: &errStr];
	if( errStr )
	{
		[errStr release];
		return nil;
	}
	
	return [self initWithDictionary: dict];
}


-(id)	initWithData: (NSData*)fdata
{
	NSString*				errStr = nil;
	NSPropertyListFormat	format = NSPropertyListBinaryFormat_v1_0;
	NSDictionary*			dict = [NSPropertyListSerialization propertyListFromData: fdata
										mutabilityOption: NSPropertyListImmutable
										format: &format errorDescription: &errStr];
	if( errStr )
	{
		[errStr release];
		return nil;
	}
	
	return [self initWithDictionary: dict];
}


-(void) dealloc
{
	if( points )
	{
		free(points);
		points = nil;
	}
	[super dealloc];
}


-(int)	countPoints
{
	return numPoints;
}


-(NSSize)	size
{
	return imageSize;
}


-(void)	setSize: (NSSize)sz
{
	imageSize = sz;
}


-(NSDictionary*)	dictionaryRepresentation
{
	NSMutableArray*	arr = [NSMutableArray arrayWithCapacity: numPoints];
	int				x = 0;
	for( x = 0; x < numPoints; x++ )
	{
		NSDictionary*	dict = [NSDictionary dictionaryWithObjectsAndKeys:
									NSStringFromPoint( points[x].pos ), @"UKPosition",
									[NSNumber numberWithBool: points[x].isHardCorner], @"UKIsHardCorner",
									nil];
		[arr addObject: dict];
	}
	
	NSDictionary* enclosingDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
																arr, @"UKMouthPoints",
																NSStringFromSize( imageSize ), @"UKImageSize",
																nil];
	
	return enclosingDictionary;
}


-(NSData*)			dataRepresentation
{
	NSDictionary*		dict = [self dictionaryRepresentation];
	NSString*			errStr = nil;
	NSData*				fdata = [NSPropertyListSerialization dataFromPropertyList: dict
											format: NSPropertyListBinaryFormat_v1_0
											errorDescription: &errStr];
	if( errStr )
	{
		UKLog(@"Error: %@",errStr);
		[errStr release];
		return nil;
	}
	
	return fdata;
}


-(void)	addCurvePoint: (NSPoint)pos inRect: (NSRect)box
{
	NSAssert1( numPoints < (MAX_POINTS-1), @"Can't add point, already have %d", numPoints );
	
	points[numPoints].pos = UKLocalPointForRect(pos,imageSize,box);
	points[numPoints].isHardCorner = NO;
	numPoints++;
}

-(void)	addCornerPoint: (NSPoint)pos inRect: (NSRect)box
{
	NSAssert1( numPoints < (MAX_POINTS-1), @"Can't add point, already have %d", numPoints );
	
	points[numPoints].pos = UKLocalPointForRect(pos,imageSize,box);
	points[numPoints].isHardCorner = YES;
	numPoints++;
}


-(NSPoint)	positionOfPointAtIndex: (int)idx inRect: (NSRect)box
{
	return UKExternalPointForRect(points[idx].pos,imageSize,box);
}


-(NSRect)	clickRectOfPointAtIndex: (int)idx inRect: (NSRect)box
{
	NSRect		clickBox = { { 0, 0 }, { 6, 6 } };
	
	clickBox.origin = [self positionOfPointAtIndex: idx inRect: box];
	clickBox.origin.x -= 3;
	clickBox.origin.y -= 3;
	
	return clickBox;
}


-(void)		setPosition: (NSPoint)pos atIndex: (int)idx inRect: (NSRect)box
{
	points[idx].pos = UKLocalPointForRect(pos,imageSize,box);
}


-(void)	addSegmentAtIndex: (int)x toPath: (NSBezierPath*)path controlPoint: (NSPoint*)cp1 controlPoint: (NSPoint*)cp2 inRect: (NSRect)box
{
	if( !points[x].isHardCorner )
	{
		if( cp1->x < 0 )
			*cp1 = UKExternalPointForRect(points[x].pos,imageSize,box);
		else if( cp2->x < 0 )
			*cp2 = UKExternalPointForRect(points[x].pos,imageSize,box);
		else
		{
			[path curveToPoint: UKExternalPointForRect(points[x].pos,imageSize,box) controlPoint1: *cp1 controlPoint2: *cp2];
			cp1->x = cp1->y = cp2->x = cp2->y = -1;
		}
	}
	else
	{
		if( cp1->x >= 0 )
		{
			if( cp2->x < 0 )
				cp2 = cp1;
			
			[path curveToPoint: UKExternalPointForRect(points[x].pos,imageSize,box) controlPoint1: *cp1 controlPoint2: *cp2];
			cp1->x = cp1->y = cp2->x = cp2->y = -1;
		}		
		else
		{
			[path lineToPoint: UKExternalPointForRect(points[x].pos,imageSize,box)];
			cp1->x = cp1->y = cp2->x = cp2->y = -1;
		}
	}
}


-(void)	drawInRect: (NSRect)box displayArea: (NSRect)dirtyRect insideImage: (NSImage*)img
{
	NSBezierPath*	path = [self pathInRect: box];
	
	if( img )
	{
		[[NSGraphicsContext currentContext] saveGraphicsState];
		
		[path setClip];
		[img drawInRect: box fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0];
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
	
	NSPoint		lineWidth = { 4, 4 };
	lineWidth = UKExternalPointForRect( lineWidth, imageSize, box );
	[path setLineWidth: lineWidth.x];
	[path stroke];
}


-(void)	moveAllPointsBy: (NSPoint)distance inRect: (NSRect)box
{
	distance = UKLocalPointForRect(distance,imageSize,box);
	
	int		x = 0;
	for( x = 0; x < numPoints; x++ )
	{
		points[x].pos.x += distance.x;
		points[x].pos.y += distance.y;
	}
}


-(void)	drawPointsInRect: (NSRect)box displayArea: (NSRect) dirtyRect
{
	int		x = 0;
	for( x = 0; x < numPoints; x++ )
	{
		NSBezierPath*	theHandle = NULL;
		NSPoint			currPoint = UKExternalPointForRect(points[x].pos,imageSize,box);
		if( points[x].isHardCorner )
			theHandle = [NSBezierPath bezierPathWithRect: NSMakeRect(currPoint.x -3, currPoint.y -3,6,6)];
		else
			theHandle = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(currPoint.x -3, currPoint.y -3,6,6)];
		[theHandle fill];
	}
}


-(int)	pointClicked: (NSPoint)clickPos inRect: (NSRect)box
{
	int		x = 0;
	for( x = (numPoints -1); x >= 0; x-- )
	{
		NSBezierPath*	theHandle = NULL;
		NSPoint			currPoint = UKExternalPointForRect(points[x].pos,imageSize,box);
		if( points[x].isHardCorner )
			theHandle = [NSBezierPath bezierPathWithRect: NSMakeRect(currPoint.x -3, currPoint.y -3,6,6)];
		else
			theHandle = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(currPoint.x -3, currPoint.y -3,6,6)];
		if( [theHandle containsPoint: clickPos] )
			return x;
	}
	
	// Nothing hit? At least give an indication whether the click was inside
	//	the path or outside:
	NSBezierPath*	path = [self pathInRect: box];
	if( [path containsPoint: clickPos] )
		return UKMouthShapeAllPoints;
	else
		return UKMouthShapeNoPoints;
}


-(NSBezierPath*)	pathInRect: (NSRect)box
{
	NSBezierPath*	path = [NSBezierPath bezierPath];
	if( numPoints < 2 )
		return path;
	
	[path moveToPoint: UKExternalPointForRect(points[0].pos,imageSize,box)];
	int				x = 0;
	NSPoint			cp1 = { -1, -1 }, cp2 = { -1, -1 };
	
	for( x = 1; x < numPoints; x++ )
	{
		[self addSegmentAtIndex: x toPath: path controlPoint: &cp1 controlPoint: &cp2 inRect: box];
	}
	[self addSegmentAtIndex: 0 toPath: path controlPoint: &cp1 controlPoint: &cp2 inRect: box];
	
	return path;
}


-(UKMouthShape*)	mouthShapeByMergingWithShape: (UKMouthShape*)otherShape percentageOfOther: (float)perc
{
	UKMouthShape*		shape = [[[UKMouthShape alloc] init] autorelease];
	
	int				x = 0;
	for( x = 0; x < numPoints; x++ )
	{
		NSPoint		selfPoint = points[x].pos;
		selfPoint.x -= (imageSize.width /2); selfPoint.y -= (imageSize.height /2);
		NSPoint		otherPoint = otherShape->points[x].pos;
		otherPoint.x -= (imageSize.width /2); otherPoint.y -= (imageSize.height /2);
		
		NSPoint		newPoint = selfPoint;
		newPoint.x += (otherPoint.x -selfPoint.x) * perc;
		newPoint.y += (otherPoint.y -selfPoint.y) * perc;
		
		newPoint.x += (imageSize.width /2); newPoint.y += (imageSize.height /2);
		shape->points[x].pos = newPoint;
		shape->points[x].isHardCorner = points[x].isHardCorner;
	}
	shape->numPoints = numPoints;
	
	return shape;
}


-(id)	copyWithZone: (NSZone*)zone
{
	UKMouthShape*	obj = [[[self class] alloc] init];
	obj->numPoints = numPoints;
	memmove( obj->points, points, sizeof(UKMouthPoint) * numPoints );
	return obj;
}


@end
