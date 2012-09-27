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
}

+(id)				imageRepWithData: (NSData *)plistData;
+(id)				imageRepWithMouthShape: (UKMouthShape*)shape;

-(id)				initWithMouthShape: (UKMouthShape*)shape;
-(id)				initWithData: (NSData *)plistData;

-(UKMouthShape*)	mouthShape;

@end


@interface NSImage (UKMooseMouthRepMergeImage)

// Works best with images containing each a UKMooseMouthImageRep:
//	Assumes both images are same size.
-(id)	imageMergedWith: (NSImage*)otherImage percentageOfOther: (float)perc;

@end

#endif // DEBUG