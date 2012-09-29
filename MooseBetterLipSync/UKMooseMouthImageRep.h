//
//  UKMooseMouthImageRep.h
//  testapp
//
//  Created by Uli Kusterer on 11.02.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

/*
    This class renders a .mooseMouth image file.
*/

#if DEBUG

#import <Cocoa/Cocoa.h>
#import "UKMouthShape.h"


@interface UKMooseMouthImageRep : NSImageRep
{
    UKMouthShape*	mouthShape;	// The loaded shape to draw.
	NSImage*		insideImage;
}

+(id)				imageRepWithData: (NSData *)plistData;
+(id)				imageRepWithMouthShape: (UKMouthShape*)shape;

-(id)				initWithMouthShape: (UKMouthShape*)shape;
-(id)				initWithData: (NSData *)plistData;

-(UKMouthShape*)	mouthShape;

-(void)				setInsideImage: (NSImage*)inImage;
-(NSImage*)			insideImage;

@end


@interface NSImage (UKMooseMouthRepMergeImage)

// Works best with images containing each a UKMooseMouthImageRep:
//	Assumes both images are same size.
-(id)	imageMergedWith: (NSImage*)otherImage percentageOfOther: (float)perc;

-(void)				setInsideImage: (NSImage*)inImage;
-(NSImage*)			insideImage;

@end

#endif // DEBUG