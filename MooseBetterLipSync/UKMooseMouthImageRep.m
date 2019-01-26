//
//  UKMooseMouthImageRep.m
//  testapp
//
//  Created by Uli Kusterer on 11.02.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

#if DEBUG

#import "UKMooseMouthImageRep.h"
#import "UKHelperMacros.h"


@implementation UKMooseMouthImageRep

+(void) load
{
    [NSImageRep registerImageRepClass: self];
}


+(id)	imageRepWithData: (NSData *)plistData
{
	return [[[[self class] alloc] initWithData: plistData] autorelease];
}


+(id)	imageRepWithMouthShape: (UKMouthShape*)shape
{
	return [[[[self class] alloc] initWithMouthShape: shape] autorelease];
}

-(id)	initWithMouthShape: (UKMouthShape*)shape
{
    self = [super init];
    if( !self )
        return nil;
    
	mouthShape = [shape retain];

	[self setSize: [mouthShape size]];
	[self setPixelsWide: [mouthShape size].width];
	[self setPixelsHigh: [mouthShape size].height];
	[self setBitsPerSample: 32];
 	[self setColorSpaceName: NSDeviceRGBColorSpace];
	
    return self;
}


-(id)	initWithData: (NSData *)plistData
{
    self = [super init];
    if( !self )
        return nil;
    
	mouthShape = [[UKMouthShape alloc] initWithData: plistData];
	[self setSize: [mouthShape size]];
	[self setPixelsWide: [mouthShape size].width];
	[self setPixelsHigh: [mouthShape size].height];
	[self setBitsPerSample: 32];
 	[self setColorSpaceName: NSDeviceRGBColorSpace];
	
	return self;
}


-(void) dealloc
{
	DESTROY_DEALLOC(insideImage);
	DESTROY_DEALLOC(mouthShape);

	[super dealloc];
}


-(UKMouthShape*)	mouthShape
{
	return mouthShape;
}


-(id)	copyWithZone: (NSZone*)zone
{
	UKMooseMouthImageRep*	obj = [super copyWithZone: zone];
	obj->mouthShape = [mouthShape copyWithZone: zone];
	obj->insideImage = [insideImage retain];
	return obj;
}

-(BOOL) draw
{
	NSRect				box = { { 0, 0 }, { 120, 120 } };
	box.size = [mouthShape size];
	
	[mouthShape drawInRect: box displayArea: box insideImage: insideImage];
	
    return YES;
}


-(BOOL)	drawAtPoint: (NSPoint)point
{
	NSRect				box = { { 0, 0 }, { 120, 120 } };
	box.origin = point;
	box.size = [mouthShape size];
	
	[mouthShape drawInRect: box displayArea: box insideImage: insideImage];
	
    return YES;
}


-(BOOL)	drawInRect: (NSRect)rect
{
	rect.size.width /= 2;
	rect.size.height /= 2;
	[mouthShape drawInRect: rect displayArea: rect insideImage: insideImage];
	
    return YES;
}


-(void)		setInsideImage: (NSImage*)inImage
{
	ASSIGN(insideImage, inImage);
}


-(NSImage*)			insideImage
{
	return insideImage;
}


+(BOOL) canInitWithData: (NSData*)data
{
	NSPropertyListFormat			parsedFormat = NSPropertyListBinaryFormat_v1_0;
	NSString*						errStr = nil;
	NSDictionary*					commands = [NSPropertyListSerialization propertyListFromData: data
													mutabilityOption: NSPropertyListImmutable
													format: &parsedFormat errorDescription: &errStr];
	if( errStr || !commands )
	{
		[errStr release];
		return NO;
	}
	
    BOOL canOpen = [commands isKindOfClass: [NSDictionary class]] && [commands count] > 0;
	if( canOpen )
	{
		NSArray*	arr = [commands objectForKey: @"UKMouthPoints"];
		canOpen &= (arr != nil) && [arr isKindOfClass: [NSArray class]] && ([arr count] > 0);
		if( canOpen )
		{
			NSDictionary*	dict = [arr objectAtIndex: 0];
			canOpen &= (dict != nil) && [dict isKindOfClass: [NSDictionary class]]
						&&  [dict objectForKey: @"UKPosition"] != nil;	
		}
	}
	return canOpen;
}


+(NSArray*) imageUnfilteredFileTypes
{
    return [NSArray arrayWithObject: @"mooseMouth"];
}


+(NSArray*) imageUnfilteredPasteboardTypes
{
    return [NSArray array];
}

@end

@implementation NSImage (UKMooseMouthRepMergeImage)

-(id)	imageMergedWith: (NSImage*)otherImage percentageOfOther: (float)perc
{
	NSImage*				img = nil;
	NSImageRep*				currRep = nil;
	UKMooseMouthImageRep*	selfMouthRep = nil;
	UKMooseMouthImageRep*	otherMouthRep = nil;
	NSImageRep*				selfRep = nil;
	NSImageRep*				otherRep = nil;
	NSEnumerator*			enny = [[self representations] objectEnumerator];
	
	while(( currRep = [enny nextObject] ))
	{
		if( [currRep isKindOfClass: [UKMooseMouthImageRep class]] )
			selfMouthRep = (UKMooseMouthImageRep*) currRep;
		else
			selfRep = currRep;
	}

	enny = [[otherImage representations] objectEnumerator];
	while(( currRep = [enny nextObject] ))
	{
		if( [currRep isKindOfClass: [UKMooseMouthImageRep class]] )
			otherMouthRep = (UKMooseMouthImageRep*) currRep;
		else
			otherRep = currRep;
	}
	
	if( selfMouthRep && otherMouthRep )
	{
		UKMouthShape*			mergedShape = [[selfMouthRep mouthShape] mouthShapeByMergingWithShape: [otherMouthRep mouthShape] percentageOfOther: perc];
		UKMooseMouthImageRep*	mergedMouthRep = [UKMooseMouthImageRep imageRepWithMouthShape: mergedShape];
		[mergedMouthRep setInsideImage: [otherMouthRep insideImage]];
		img = [[[NSImage alloc] initWithSize: [mergedShape size]] autorelease];
		[img addRepresentation: mergedMouthRep];
	}
	else
	{
		img = [[[NSImage alloc] initWithSize: [self size]] autorelease];
		[img lockFocus];
			[self compositeToPoint: NSZeroPoint operation: NSCompositingOperationCopy];
			[otherImage compositeToPoint: NSZeroPoint operation: NSCompositingOperationSourceAtop fraction: perc];
		[img unlockFocus];
	}
	
	return img;
}


-(void)				setInsideImage: (NSImage*)inImage
{
	NSImageRep*				currRep = nil;
	UKMooseMouthImageRep*	selfMouthRep = nil;
	NSEnumerator*			enny = [[self representations] objectEnumerator];
	
	while(( currRep = [enny nextObject] ))
	{
		if( [currRep isKindOfClass: [UKMooseMouthImageRep class]] )
			selfMouthRep = (UKMooseMouthImageRep*) currRep;
	}
	
	[selfMouthRep setInsideImage: inImage];
}


-(NSImage*)			insideImage
{
	NSImageRep*				currRep = nil;
	UKMooseMouthImageRep*	selfMouthRep = nil;
	NSEnumerator*			enny = [[self representations] objectEnumerator];
	
	while(( currRep = [enny nextObject] ))
	{
		if( [currRep isKindOfClass: [UKMooseMouthImageRep class]] )
			selfMouthRep = (UKMooseMouthImageRep*) currRep;
	}
	
	return [selfMouthRep insideImage];
}

@end

#endif // DEBUG
