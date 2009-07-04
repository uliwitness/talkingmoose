//
//  UKMooseController.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Sun Apr 04 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>


@class UKGroupFile;


@interface UKMooseController : NSObject
{
	NSMutableDictionary*		mooseImages;		// Array of NSImages to draw for this moose animation.
	UKGroupFile*				mooseInfo;			// Contents of info.txt file, as NSMutableArrays of NSStrings for the lines in each category.
	NSImage*					currentImage;		// Completely composited image of this moose in its current state.
	NSImage*					previewImage;		// Completely composited image of this moose in an arbitrary state, maximum 200x200 pixels large.
	NSPoint						globalCenter;		// Center of moose image on screen (used for following eyes).
    NSTimer*					eyeFollowTimer;		// Timer that periodically syncs eyes with mouse location.
	NSPoint						oldMousePos;		// Most recent mouse position we synced eyes for.
	id							delegate;			// Gets our speech delegate messages and notifications we send.
	int							blinking;			// 0 when not in the process of blinking, positive if closing, negative if reopening eyes.
	time_t						lastBlinkTime;		// Last time we blinked.
	BOOL						isSpeaking;			// So we can send "started speaking" messages.
	NSColor*					startColor;			// Start color of gradient or solid color.
	NSColor*					endColor;			// End color of gradient.
    NSImage*                    badgeImage;			// Badge to draw on top of animation.
	BOOL						dontIdleAnimate;	// No idle animations like blinking and eye following the mouse?
	NSTimeInterval				lastPhonemeTime;	// Last time we displayed a phoneme, so we can calc a good time to show an image morphed between this and the next phoneme.
}

-(id)			initWithAnimationFile: (NSString*)fpath;

-(NSImage*)		image;			// Composited Moose image ready for display.
-(NSImage*)		previewImage;   // Composited Moose image resized to fit in MOOSE_PREVIEW_WIDTH x MOOSE_PREVIEW_HEIGHT pixel box as a preview for the animation.


// Set up this object:
-(void)			setGlobalFrame: (NSRect)box;            // Convenience method for setGlobalCenter.
-(NSRect)		globalFrame;                            // Convenience method for globalCenter.
-(void)			setGlobalCenter: (NSPoint)pos;          // Specify where the Moose is displayed on screen (so eyes can follow mouse).
-(NSPoint)		globalCenter;
-(NSImage*)     badgeImage;
-(void)         setBadgeImage: (NSImage*)theBadgeImage; // Overlay this image on the animation.
-(NSImage*)     imageForKey: (NSString*)key;            // Useful for getting badge images.

-(void)			setDontIdleAnimate: (BOOL)state;
-(BOOL)			dontIdleAnimate;

-(void)			setDelegate: (id)dele;
-(id)			delegate;


// Useful info for displaying this thing to users:
-(NSString*)	name;
-(NSString*)	version;
-(NSString*)	author;
-(NSNumber*)	tintBackground;
-(NSNumber*)	reducedPhonemes;
-(NSNumber*)	eyesFollowMouse;
-(NSNumber*)	useMooseMouthFiles;
-(NSPoint)		mouthImagePosition;
-(NSPoint)		eyeImagePosition;
-(NSSize)		size;							// Size of full Moose image.
-(NSSize)		sizeWithoutShadow;              // Size of actual Moose part of image (without any dropshadows).
-(NSArray*)		backgroundImages;
-(void)			setBackgroundImage: (NSString*)filename;
-(NSString*)	filePath;

-(NSColor *)	startColor;
-(void)			setStartColor: (NSColor *)newStartColor;
-(BOOL)			bgImageHasStartColor: (NSString*)imgName;

-(NSColor *)	endColor;
-(void)			setEndColor: (NSColor *)newEndColor;
-(BOOL)			bgImageHasEndColor: (NSString*)imgName;

// Speech synthesizer delegate methods: (You need to create the synthesizer yourself)
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking;
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakPhoneme:(short)phonemeOpcode;

@end


@interface NSObject (UKMooseControllerDelegate)

-(void) mooseControllerAnimationDidChange: (UKMooseController*)mc;
-(void) mooseControllerSpeechStart: (UKMooseController*)mc;

// Speech synthesizer delegate methods are also forwarded.

@end

// -----------------------------------------------------------------------------
//  Constants:
// -----------------------------------------------------------------------------

// Badge names to pass to imageForKey:
#define UKMooseControllerShutUpBadgeKey                     @"QUIETIMAGE"       // Moose has been told to shut up.

// Notifications:
#define UKMooseControllerAnimationDidChangeNotification		@"UKMooseControllerAnimationDidChange"

// Desired Moose preview sizes (in pixels):
#ifndef MOOSE_PREVIEW_WIDTH
#define MOOSE_PREVIEW_WIDTH		50
#define MOOSE_PREVIEW_HEIGHT	50
#endif

// Number for our eye-position maths:
#define MOOSE_PI				3.14159265358979323846


#define UK_EYE_TIMER_TIME		0.06


