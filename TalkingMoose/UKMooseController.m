//
//  UKMooseController.m
//  CocoaMoose
//
//  Created by Uli Kusterer on Sun Apr 04 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKMooseController.h"
#import "NSImage+NiceScaling.h"
#import "UKGroupFile.h"
#import "UKMooseMouthImageRep.h"


#define MERGE_ANIMATION_FRAMES		0


@interface UKMooseController (PrivateMethods)

-(void)			buildCurrentImage;
-(NSString*)	filenameFromPhoneme: (short)phon;
-(NSImage*)		imageFileForPhoneme: (short)phon;
-(NSString*)	filenameForEyeDirection: (NSImageAlignment)pos;
-(NSImage*)		imageFileForEyeDirection: (NSImageAlignment)pos;
-(int)			angleOfLineFrom: (NSPoint)point1 to: (NSPoint)point2;
-(NSImageAlignment) alignmentFromAngle: (int)degrees;
-(void)			setEyesImageForGlobalMouse: (NSPoint)pos;
-(void)			eyeFollowTimerAction: (id)sender;
-(void)			changeMouthImageToPhoneme: (int)thePhoneme;

@end


@implementation UKMooseController

-(id)   initWithAnimationFile: (NSString*)fpath
{
	self = [super init];
    
	if( self )
	{
		NS_DURING
			NSString*				infoPath = [fpath stringByAppendingPathComponent: @"Contents/info.txt"];
			
			mooseImages = [[NSMutableDictionary alloc] init];
			mooseInfo = [[UKGroupFile alloc] initFromGroupFile: infoPath withDefaultCategory: @"DISCARDS"];
			
			[self setBackgroundImage: @"Transparent"];
			NSImage* bgImage = [mooseInfo imageFileFromString: @"base"];
			if( bgImage )
				[mooseImages setObject: bgImage forKey: @"BASE"];
			
			NSImage* mouthInsideImage = [mooseInfo imageFileFromString: @"mouth-inside"];
			if( mouthInsideImage )
				[mooseImages setObject: mouthInsideImage forKey: @"MOUTH-INSIDE"];
			
			lastPhonemeTime = CFAbsoluteTimeGetCurrent();
			[self changeMouthImageToPhoneme: 0];
			
			startColor = [[NSColor colorWithCalibratedWhite: 1.0 alpha: 0] retain];
			endColor = [[NSColor blueColor] retain];
			
			[self setEyesImageForGlobalMouse: [NSEvent mouseLocation]];
			[self buildCurrentImage];
		NS_HANDLER
			NSLog(@"Couldn't load animation \"%@\": %@",fpath,localException);
			[self autorelease];
			self = nil;
		NS_ENDHANDLER
	}
	
	return self;
}


-(void) dealloc
{
	[mooseImages release];
	[mooseInfo release];
	[currentImage release];
	[previewImage release];
	[eyeFollowTimer release];
	[startColor release];
	[endColor release];
    [badgeImage release];
	
	[super dealloc];
}


-(NSImage*)     imageForKey: (NSString*)key
{
    return [mooseInfo imageFileForKey: key index: 0];
}


-(NSString*)	filePath
{
	NSString*		path = [mooseInfo objectForKey: @"CONTENTSPATH"];
	return [path stringByDeletingLastPathComponent];
}


-(void)	speechStartedWithoutPhonemes
{
	if( simulateMissingPhonemes && !isSpeaking )
	{
		isSpeaking = YES;
		if( delegate && [delegate respondsToSelector: @selector(mooseControllerSpeechStart:)] )
			[delegate mooseControllerSpeechStart: self];
	}
}


-(NSArray*)		backgroundImages
{
	NSArray*		bgs = [mooseInfo objectForKey: @"BACKGROUND"];
	
	return [[NSArray arrayWithObjects: @"Transparent", @"Solid Color", @"Radial Gradient", @"Horizontal Gradient", @"Vertical Gradient", nil] arrayByAddingObjectsFromArray: bgs];
}


-(BOOL)	bgImageHasStartColor: (NSString*)imgName
{
	return( [imgName isEqualToString: @"Solid Color"]
		|| [imgName isEqualToString: @"Radial Gradient"]
		|| [imgName isEqualToString: @"Horizontal Gradient"]
		|| [imgName isEqualToString: @"Vertical Gradient"] );
}


-(BOOL)	bgImageHasEndColor: (NSString*)imgName
{
	return( [imgName isEqualToString: @"Radial Gradient"]
		|| [imgName isEqualToString: @"Horizontal Gradient"]
		|| [imgName isEqualToString: @"Vertical Gradient"] );
}

-(void)			drawBevelAtSize: (NSSize)imgSize
{
	NSRect		box = { { -0.5, -0.5 }, { 0, 0 } };
	NSPoint		tl, tr, bl, br;
	
	box.size = imgSize;
	box.size.width++;
	box.size.height++;
	box = NSInsetRect( box, 2, 2 );
	
	bl = box.origin;

	tr.x = box.origin.x +box.size.width;
	tr.y = box.origin.y +box.size.height;

	tl.x = bl.x;
	tl.y = tr.y;

	br.x = tr.x;
	br.y = bl.y;
	
	[NSBezierPath setDefaultLineWidth: 2];
	[[NSColor colorWithCalibratedWhite: 1.0 alpha: 0.4] set];
	[NSBezierPath strokeLineFromPoint: bl toPoint: tl];
	[NSBezierPath strokeLineFromPoint: tl toPoint: tr];
	
	[[NSColor colorWithCalibratedWhite: 0 alpha: 0.4] set];
	[NSBezierPath strokeLineFromPoint: tr toPoint: br];
	[NSBezierPath strokeLineFromPoint: br toPoint: bl];
	
	[NSBezierPath setDefaultLineWidth: 1];
}


-(void)			setBackgroundImage: (NSString*)filename
{
	NSImage*	img = nil;
	
	if( [filename isEqualToString: @"Transparent"] )
		img = [[[NSImage alloc] initWithSize: [self sizeWithoutShadow]] autorelease];
	else if( [filename isEqualToString: @"Solid Color"] )
	{
		NSRect		box = { { 0.5, -0.5 }, { 0, 0 } };
		
		box.size = [self sizeWithoutShadow];
		
		img = [[[NSImage alloc] initWithSize: box.size] autorelease];
		
		[img lockFocus];
			[startColor set];
			NSRectFill( box );
			if( [startColor alphaComponent] >= 0.5 )
				[self drawBevelAtSize: box.size];
		[img unlockFocus];
	}
	else if( [filename isEqualToString: @"Radial Gradient"] )
	{
		NSRect		box = { { 0.5, 0.5 }, { 0, 0 } };
		NSSize		imgSize = box.size = [self sizeWithoutShadow];
		float		stepSize, x;
		
		img = [[[NSImage alloc] initWithSize: box.size] autorelease];
		stepSize = 1.0 / (box.size.height / 2);
		
		[img lockFocus];
			[startColor set];
			NSRectFill( box );
			for( x = 0; x < (imgSize.height /2); x++ )
			{
				box.origin.y++;
				box.origin.x++;
				box.size.height -= 2;
				box.size.width -= 2;
				[[startColor blendedColorWithFraction: (stepSize * x) ofColor: endColor] set];
				[[NSBezierPath bezierPathWithOvalInRect:box] fill];
			}
			if( [startColor alphaComponent] >= 0.5 && [endColor alphaComponent] >= 0.5 )
				[self drawBevelAtSize: imgSize];
		[img unlockFocus];
	}
	else if( [filename isEqualToString: @"Horizontal Gradient"] )
	{
		NSPoint		startPoint = { 0.5, -0.5 }, endPoint = { 0.5, -0.5 };
		NSSize		imgSize = [self sizeWithoutShadow];
		float		stepSize, x;
		if( (imgSize.width == imgSize.height) && (imgSize.width == 0) )
		{
			NSLog(@"Error: Animation has zero size!");
			imgSize.width = imgSize.height = 1;
		}
		
		img = [[[NSImage alloc] initWithSize: imgSize] autorelease];
		endPoint.x = imgSize.width;
		stepSize = 1.0 / imgSize.height;
		
		NS_DURING
			[img lockFocus];
				for( x = 0; x < imgSize.height; x++ )
				{
					startPoint.y++;
					endPoint.y++;
					[[endColor blendedColorWithFraction: (stepSize * x) ofColor: startColor] set];
					[NSBezierPath strokeLineFromPoint: startPoint toPoint: endPoint];
				}
				if( [startColor alphaComponent] >= 0.5 && [endColor alphaComponent] >= 0.5 )
					[self drawBevelAtSize: imgSize];
			[img unlockFocus];
		NS_HANDLER
			NSLog(@"Error trying to draw gradient background: %@", localException);
		NS_ENDHANDLER
	}
	else if( [filename isEqualToString: @"Vertical Gradient"] )
	{
		NSPoint		startPoint = { 0.5, -0.5 }, endPoint = { 0.5, -0.5 };
		NSSize		imgSize = [self sizeWithoutShadow];
		float		stepSize, x;
		
		img = [[[NSImage alloc] initWithSize: imgSize] autorelease];
		endPoint.y = imgSize.height;
		stepSize = 1.0 / imgSize.width;
		
		[img lockFocus];
			for( x = 0; x < imgSize.width; x++ )
			{
				startPoint.x++;
				endPoint.x++;
				[[startColor blendedColorWithFraction: (stepSize * x) ofColor: endColor] set];
				[NSBezierPath strokeLineFromPoint: startPoint toPoint: endPoint];
			}
			if( [startColor alphaComponent] >= 0.5 && [endColor alphaComponent] >= 0.5 )
				[self drawBevelAtSize: imgSize];
		[img unlockFocus];
	}
	else
		img = [mooseInfo imageFileFromString: filename];
	
	if( img )
		[mooseImages setObject: img forKey: @"BACKGROUND"];
	
	[currentImage release];
	currentImage = nil;
}


-(NSColor *)	startColor
{
    return startColor;
}

-(void)	setStartColor: (NSColor *)newStartColor
{
    if( startColor != newStartColor )
	{
		[startColor release];
		startColor = [newStartColor retain];
		[currentImage release];
		currentImage = nil;
	}
}

-(NSColor *)	endColor
{
    return endColor;
}

-(void)	setEndColor: (NSColor *)newEndColor
{
    if( endColor != newEndColor )
	{
		[endColor release];
		endColor = [newEndColor retain];
		[currentImage release];
		currentImage = nil;
	}
}


#define XOR(a,b)	(((a) || (b)) && !((a) && (b)))


-(int) angleOfLineFrom: (NSPoint)point1 to: (NSPoint)point2
{
	double   opposite = point2.y - point1.y;
    double   adjacent = point2.x - point1.x;
	double   lineangle = 0;

	// Calculates an angle if the line is at 90 or -90 degrees
	if( adjacent != 0 )
    {
		lineangle = atan(opposite/adjacent);
		
		if( adjacent < 0 )
			lineangle += XOR(opposite < 0, adjacent < 0) ? MOOSE_PI : -MOOSE_PI;
	}
	else
	{
		if( opposite >= 0 ) 
            lineangle = MOOSE_PI /2;
        else
			lineangle = -MOOSE_PI /2;
	}
	
    // Converts the angle from radians to degrees
    lineangle = lineangle * 180 / MOOSE_PI;

    return( (int) lineangle );
}


-(NSImageAlignment) alignmentFromAngle: (int)degrees
{
	if( degrees < 22 && degrees > -22 )				// 0
		return NSImageAlignRight;
	else if( degrees >= 22 && degrees < 67 )		// 45
		return NSImageAlignTopRight;
	else if( degrees >= 67 && degrees < 112 )		// 90
		return NSImageAlignTop;
	else if( degrees >= 112 && degrees < 157 )		// 135
		return NSImageAlignTopLeft;
	else if( degrees > 0 && degrees <= 180 )		// 180
		return NSImageAlignLeft;
	else if( degrees <= -22 && degrees > -67 )		// -45
		return NSImageAlignBottomRight;
	else if( degrees <= -67 && degrees > -112 )		// -90
		return NSImageAlignBottom;
	else if( degrees <= -112 && degrees > -157 )	// -135
		return NSImageAlignBottomLeft;
	else if( degrees <= 157 && degrees > -180 )		// > -180
		return NSImageAlignLeft;
	else
		return NSImageAlignCenter;
}


-(NSString*)	filenameFromEyeDirection: (NSImageAlignment)pos
{
	NSString*   vEyeFileNames[9] = {	@"eyes-ahead",
										@"eyes-n",
										@"eyes-nw",
										@"eyes-ne",
										@"eyes-w",
										@"eyes-s",
										@"eyes-sw",
										@"eyes-se",
										@"eyes-e"		};
	return [mooseInfo filenameFromString: vEyeFileNames[pos] extension: nil];
}

-(NSString*) filenameFromPhoneme: (short)phon
{
	NSString*		fname = nil;

	if( [[self reducedPhonemes] boolValue] )
	{
		NSString*		vMouthFileNames[5] = {	@"mouth-0",
												@"mouth-uh",
												@"mouth-oo",
												@"mouth-mm",
												@"mouth-ee" };
		if( phon != 0 )
		{
			switch( phon )
			{
				case 1:		// Breath intake.
				case 2:		// Ä
				case 3:		// Äi
				case 4:		// å
				case 5:		// Ah
				case 9:		// ai
				case 11:	// å
				case 14:	// a
				case 19:	// tch
				case 23:	// g
				case 24:	// h
				case 25:	// dsch
				case 26:	// k
				case 29:	// n
				case 30:	// ng
				case 32:	// r
				case 16:	// au
				case 35:	// t
					fname = vMouthFileNames[1];
					break;
				
				
				case 36:	// [th] (hart)
				case 39:	// j
				case 12:	// uh
				case 13:	// u
				case 17:	// oi
				case 15:	// ou
				case 33:	// s
				case 34:	// sch
				case 38:	// uo, ua etc.
				case 40:	// s (stimmhaft)
				case 41:	// sch (weich)
					fname = vMouthFileNames[2];
					break;
				
				case 27:	// l
				case 28:	// m
				case 18:	// b
				case 20:	// d
				case 21:	// [th]
				case 22:	// f
				case 31:	// p
				case 37:	// w
					fname = vMouthFileNames[3];
					break;
				
				case 6:		// ih
				case 7:		// e
				case 8:		// i
				case 10:	// i mit e-Anklang
					fname = vMouthFileNames[4];
					break;
			}
		}
		else if( phon == 0 )
			fname = vMouthFileNames[0];
	}
	else
		fname = [NSString stringWithFormat: @"mouth-%d", phon];
	
	#if DEBUG
	if( [[self useMooseMouthFiles] boolValue] )
		return [mooseInfo filenameFromString: fname extension: @".mooseMouth"];
	else
	#endif // DEBUG
		return [mooseInfo filenameFromString: fname extension: nil];
}


-(NSImage*)		imageFileForPhoneme: (short)phon
{
	NSString*   phonemeFilename = [self filenameFromPhoneme: phon];
    NSImage*    img = [mooseImages objectForKey: phonemeFilename];
    
    if( !img )
    {
        img = [[[NSImage alloc] initWithContentsOfFile: phonemeFilename] autorelease];
		[img setInsideImage: [mooseImages objectForKey: @"MOUTH-INSIDE"]];
        [img setCacheMode: NSImageCacheAlways];
	
        if( !img )
            NSLog(@"UKMooseController: Couldn't load image %@", phonemeFilename);
        else
            [mooseImages setObject: img forKey: phonemeFilename];
    }
    
    return img;
}

-(NSImage*)		imageFileForEyeDirection: (NSImageAlignment)phon
{
	NSString*   bgFilename = [self filenameFromEyeDirection: phon];
    NSImage*    img = [mooseImages objectForKey: bgFilename];
    
    if( !img )
    {
        img = [[[NSImage alloc] initWithContentsOfFile: bgFilename] autorelease];
        //img = [img scaledImageToFitSize: [img size]];
        [img setCacheMode: NSImageCacheAlways];
    
        if( !img )
            NSLog(@"UKMooseController: Couldn't load image %@", bgFilename);
        else
            [mooseImages setObject: img forKey: bgFilename];
    }
    
    return img;
}


#define DO_SHADOW   1
#define SHDW_WIDTH  3
#define SHDW_HEIGHT 8
#define SHDW_BLUR   8


-(void)		buildCurrentImage
{
	NSPoint		mouthImgPos = [self mouthImagePosition];
	NSPoint		eyeImgPos = [self eyeImagePosition];
	
	// Create an image to draw in and load the images from which we build this frame:
	NSSize			imgSize = { 20, 20 };
	NSImage*		mouthImg = [mooseImages objectForKey: @"MOUTH"];
	if( ![mouthImg isKindOfClass: [NSImage class]] )
		mouthImg = nil;
	NSImage*		eyesImg = [mooseImages objectForKey: @"EYES"];
	NSImage*		baseImg = [mooseImages objectForKey: @"BASE"];
	NSImage*		bgImage = [mooseImages objectForKey: @"BACKGROUND"];
	if( baseImg )
		imgSize = [baseImg size];
    NSSize          imgSzWithBg = imgSize;
    #if DO_SHADOW
    imgSzWithBg.width += SHDW_WIDTH;
    imgSzWithBg.height += SHDW_HEIGHT;
	NSImage*		newImg = [[[NSImage alloc] initWithSize: imgSzWithBg] autorelease];
    #endif
	NSImage*		img = [[[NSImage alloc] initWithSize: imgSize] autorelease];
    NSPoint         zeroPoint = { 0, 0 };
	
	// Composite the parts into the image:
	[img lockFocus];
		[bgImage compositeToPoint: zeroPoint operation: NSCompositeCopy];
		[baseImg compositeToPoint: zeroPoint operation: NSCompositeSourceOver];
		[mouthImg compositeToPoint: mouthImgPos operation: NSCompositeSourceOver];
		[eyesImg compositeToPoint: eyeImgPos operation: NSCompositeSourceOver];
        if( badgeImage )
        {
            NSPoint pos;
            NSSize  siz = [badgeImage size];
            pos.x = truncf((imgSize.width /2) -(siz.width /2));
            pos.y = truncf((imgSize.height /2) -(siz.height /2));
            [badgeImage compositeToPoint: pos operation: NSCompositeSourceOver];
        }
	[img unlockFocus];
    
    #if DO_SHADOW
        [newImg lockFocus];
            // Draw shadow of image:
            NSPoint     pos = { 0, SHDW_WIDTH };
			[NSGraphicsContext saveGraphicsState];
			NSShadow	*shad = [[[NSShadow alloc] init] autorelease];
			[shad setShadowOffset: NSMakeSize(SHDW_HEIGHT,-SHDW_WIDTH)];
			[shad setShadowBlurRadius: SHDW_BLUR];
			[shad set];
			[img dissolveToPoint: pos fraction: 1.0];
			[NSGraphicsContext restoreGraphicsState];
			
            // Draw image on top of shadow:
            [img compositeToPoint: pos operation: NSCompositeSourceOver];
        [newImg unlockFocus];
        
        // Replace old cached image with the new one:
        [currentImage release];
        currentImage = [newImg retain];
    #else
    	[currentImage release];
        currentImage = [img retain];
    #endif
	
	// Notify anyone who's interested that our image changed:
	if( delegate && [delegate respondsToSelector: @selector(mooseControllerAnimationDidChange:)] )
	{
		if( (lastPhonemeTime -CFAbsoluteTimeGetCurrent()) > 3.0 && isSpeaking )
		{
			//UKLog(@"finished speaking. (2)");
			isSpeaking = NO;
			if( delegate && [delegate respondsToSelector: @selector(speechSynthesizer:didFinishSpeaking:)] )
				[delegate speechSynthesizer: nil didFinishSpeaking: YES];
			[self changeMouthImageToPhoneme: 0];
		}
		else
			[delegate mooseControllerAnimationDidChange: self];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName: UKMooseControllerAnimationDidChangeNotification object:self];
}


-(void)			setDontIdleAnimate: (BOOL)state
{
	dontIdleAnimate = state;
	
	if( eyeFollowTimer && state )
	{
		[eyeFollowTimer invalidate];
		[eyeFollowTimer release];
		eyeFollowTimer = nil;
	}
	else if( !eyeFollowTimer && !state )
	{
		eyeFollowTimer = [NSTimer scheduledTimerWithTimeInterval: UK_EYE_TIMER_TIME target: self
							selector: @selector(eyeFollowTimerAction:) userInfo: nil
							repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: eyeFollowTimer forMode: NSModalPanelRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer: eyeFollowTimer forMode: NSEventTrackingRunLoopMode];
		[eyeFollowTimer retain];
	}
}


-(BOOL)			dontIdleAnimate
{
	return dontIdleAnimate;
}


-(void)			setSimulateMissingPhonemes: (BOOL)inSimulateMissingPhonemes
{
	simulateMissingPhonemes = inSimulateMissingPhonemes;
}


-(BOOL)			simulateMissingPhonemes
{
	return simulateMissingPhonemes;
}



-(void)			eyeFollowTimerAction: (id)sender
{
	if( blinking == 0 && (rand() % 3) == 0
		&& lastBlinkTime < time(NULL) )
	{
		blinking = 1;
		lastBlinkTime = time(NULL) +3;
	}
	
	if( blinking != 0 )
	{
		NSImage* theImage = [mooseInfo imageFileFromString: [NSString stringWithFormat: @"eyes-blink%d", (blinking > 0) ? blinking : -blinking]];
		if( theImage )
			[mooseImages setObject: theImage forKey: @"EYES"];
		blinking++;
		
		if( blinking > 3 )
			blinking = -2;
		
		oldMousePos.x = [NSEvent mouseLocation].x +1;   // Make sure eyes are redrawn when we're finished.
		
		[eyeFollowTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]];
	}
	else
		[self setEyesImageForGlobalMouse: [NSEvent mouseLocation]];
	
	if( isSpeaking && simulateMissingPhonemes && ([NSDate timeIntervalSinceReferenceDate] -lastPhonemeTime) > (1.0 / 20.0) )
	{
		int	currPhoneme = (rand() % 42);
		[self changeMouthImageToPhoneme: currPhoneme];
		if( [delegate respondsToSelector: @selector(speechSynthesizer:willSpeakPhoneme:)] )
			[delegate speechSynthesizer: nil willSpeakPhoneme: currPhoneme];
		lastPhonemeTime = [NSDate timeIntervalSinceReferenceDate];
	}
	
	[self buildCurrentImage];
}


-(void)			setEyesImageForGlobalMouse: (NSPoint)pos
{
	if( pos.x != oldMousePos.x || pos.y != oldMousePos.y )
	{
		NSImage*	theImage = nil;
		if( [[self eyesFollowMouse] boolValue] )
		{
			int angle = [self angleOfLineFrom: globalCenter to: pos];
			theImage = [self imageFileForEyeDirection: [self alignmentFromAngle: angle]];
		}
		else
			theImage = [self imageFileForEyeDirection: NSImageAlignCenter];
		
		oldMousePos = pos;
		
		if( theImage )
			[mooseImages setObject: theImage forKey: @"EYES"];
	}
}


-(NSImage*)		image
{
	if( !currentImage )
		[self buildCurrentImage];
	return currentImage;
}


-(NSImage*)		previewImage
{
	if( !previewImage )
		previewImage = [[[self image] scaledImageToFitSize: NSMakeSize(MOOSE_PREVIEW_WIDTH,MOOSE_PREVIEW_HEIGHT)] retain];
	
	return previewImage;
}


-(NSString*)	name
{
	return [mooseInfo lineForKey: @"NAME" index: 0];
}


-(NSString*)	version
{
	return [mooseInfo lineForKey: @"VERSION" index: 0];
}


-(NSString*)	author
{
	return [mooseInfo lineForKey: @"AUTHOR" index: 0];
}


-(NSNumber*)	tintBackground
{
	return [NSNumber numberWithInt: ([mooseInfo objectForKey: @"TINT BACKGROUND"] != nil)];
}


-(NSNumber*)	reducedPhonemes
{
	return [NSNumber numberWithInt: ([mooseInfo objectForKey: @"REDUCED PHONEMES"] != nil)];
}


-(NSPoint)		mouthImagePosition
{
	NSArray*	strs = [mooseInfo objectForKey: @"MOUTH IMAGE POSITION"];
	if( !strs || [strs count] == 0 )
		return NSZeroPoint;
	return NSPointFromString( [strs objectAtIndex: 0] );
}


-(NSPoint)		eyeImagePosition
{
	NSArray*	strs = [mooseInfo objectForKey: @"EYE IMAGE POSITION"];
	if( !strs || [strs count] == 0 )
		return NSZeroPoint;
	return NSPointFromString( [strs objectAtIndex: 0] );
}



-(NSNumber*)	useMooseMouthFiles
{
#if DEBUG
	return [NSNumber numberWithInt: ([mooseInfo objectForKey: @"USE MOOSEMOUTH FILES"] != nil)];
#else
	return [NSNumber numberWithInt: 0];
#endif
}


-(NSNumber*)	eyesFollowMouse
{
	return [NSNumber numberWithInt: ([mooseInfo objectForKey: @"EYES FOLLOW MOUSE"] != nil)];
}


-(void)			setGlobalCenter: (NSPoint)pos
{
	globalCenter = pos;
	
	if( !dontIdleAnimate && !eyeFollowTimer && [[self eyesFollowMouse] boolValue] )
	{
		eyeFollowTimer = [NSTimer scheduledTimerWithTimeInterval: UK_EYE_TIMER_TIME target: self
							selector: @selector(eyeFollowTimerAction:) userInfo: nil
							repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: eyeFollowTimer forMode: NSModalPanelRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer: eyeFollowTimer forMode: NSEventTrackingRunLoopMode];
		[eyeFollowTimer retain];
	}
}

-(NSPoint)		globalCenter
{
	return globalCenter;
}


-(void)			setGlobalFrame: (NSRect)box
{
	[self setGlobalCenter: NSMakePoint(NSMidX(box),NSMidY(box))];
}


-(NSRect)		globalFrame
{
	NSRect		box;
	
	box.size = [self size];
	box.origin = globalCenter;
	box.origin.x -= box.size.width /2;
	box.origin.y -= box.size.height /2;
	
	return box;
}

-(NSSize)		size
{
	return [[self image] size];
}


-(NSSize)		sizeWithoutShadow
{
    NSSize  sz = [[self image] size];
    
    #if DO_SHADOW
    sz.width -= SHDW_WIDTH;
    sz.height -= SHDW_HEIGHT;
    #endif
    
	return sz;
}


-(void)			setDelegate: (id)dele
{
	delegate = dele;
	
	if( !dele )
	{
		[eyeFollowTimer invalidate];
		[eyeFollowTimer release];
		eyeFollowTimer = nil;
	}
}


-(id)			delegate
{
	return delegate;
}


// ---------------------------------------------------------- 
// - badgeImage:
// ---------------------------------------------------------- 
-(NSImage*) badgeImage
{
    return badgeImage; 
}

// ---------------------------------------------------------- 
// - setBadgeImage:
// ---------------------------------------------------------- 
-(void) setBadgeImage: (NSImage*)theBadgeImage
{
    if (badgeImage != theBadgeImage)
    {
        [badgeImage release];
        badgeImage = [theBadgeImage retain];
		[currentImage release];
		currentImage = nil;
    }
}


-(void)	setMouthImage_Internal: (NSImage*)img
{
	[mooseImages setObject: img forKey: @"MOUTH"];
	
	[currentImage release];
	currentImage = nil;
	
	lastPhonemeTime = CFAbsoluteTimeGetCurrent();
	
	[self buildCurrentImage];
}


-(void)	changeMouthImageToPhoneme: (int)thePhoneme
{
	#if MERGE_ANIMATION_FRAMES
	NSImage*		prevMouth = [[[mooseImages objectForKey: @"MOUTH"] retain] autorelease];
	NSTimeInterval	timeTillFullPhoneme = (CFAbsoluteTimeGetCurrent() -lastPhonemeTime) / 2;
	#endif // MERGE_ANIMATION_FRAMES
	NSImage*		phonImg = [self imageFileForPhoneme: thePhoneme];
	if( !phonImg )
		;//UKLog(@"No image for phoneme %d",thePhoneme);
	else
	{
		#if MERGE_ANIMATION_FRAMES
		if( prevMouth && phonImg )
		{
			[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(setMouthImage_Internal:) object: nil];
			[self setMouthImage_Internal: [prevMouth imageMergedWith: phonImg percentageOfOther: 0.5]];
			[self performSelector: @selector(setMouthImage_Internal:) withObject: phonImg afterDelay: timeTillFullPhoneme];
		}
		else if( phonImg )
		#endif // MERGE_ANIMATION_FRAMES
			[self setMouthImage_Internal: phonImg];
	}
}


- (void)speechSynthesizer: (NSSpeechSynthesizer *)sender didFinishSpeaking: (BOOL)finishedSpeaking
{
	//UKLog( @"finished speaking%s. (1)", (finishedSpeaking?"":" abnormally") );
	isSpeaking = NO;
	if( delegate && [delegate respondsToSelector: @selector(speechSynthesizer:didFinishSpeaking:)] )
		[delegate speechSynthesizer: (NSSpeechSynthesizer*) sender didFinishSpeaking: finishedSpeaking];
	[self changeMouthImageToPhoneme: 0];
	[sender stopSpeaking];
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakPhoneme:(short)phonemeOpcode
{
	//UKLog(@"About to speak phoneme %d",phonemeOpcode);
	
	if( !isSpeaking )
	{
		isSpeaking = YES;
		if( delegate && [delegate respondsToSelector: @selector(mooseControllerSpeechStart:)] )
			[delegate mooseControllerSpeechStart: self];
	}

	if( delegate && [delegate respondsToSelector: @selector(speechSynthesizer:willSpeakPhoneme:)] )
		[delegate speechSynthesizer: (NSSpeechSynthesizer*) sender willSpeakPhoneme: phonemeOpcode];
	
	[self changeMouthImageToPhoneme: phonemeOpcode];
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakWord:(NSRange)characterRange ofString:(NSString *)string
{
	if( delegate && [delegate respondsToSelector: @selector(speechSynthesizer:willSpeakWord:ofString:)] )
	{
		[delegate speechSynthesizer: (NSSpeechSynthesizer*) sender willSpeakWord: characterRange ofString: string];
		
		if( !isSpeaking && delegate && [delegate respondsToSelector: @selector(mooseControllerSpeechStart:)] )
		{
			isSpeaking = YES;
			[delegate mooseControllerSpeechStart: self];
		}
	}
}


-(NSString*)	description
{
	return [NSString stringWithFormat: @"%@ {\n\tpath = \"%@\",\n\tglobalCenter = \"%@\"\n\tisSpeaking = %@\n\tsize = %@ }",
				NSStringFromClass([self class]),
				[mooseInfo filePath],
				NSStringFromPoint(globalCenter),
				(isSpeaking ? @"YES" : @"NO"),
				NSStringFromSize( [self size] ) ];
}


@end
