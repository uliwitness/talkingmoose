//
//  MooseAnimThumberAppDelegate.m
//  MooseAnimThumber
//
//  Created by Uli Kusterer on 25.02.06.
//  Copyright 2006 Uli Kusterer. All rights reserved.
//

#import "MooseAnimThumberAppDelegate.h"
#import "UKGroupFile.h"
#import "NSImage+NiceScaling.h"


@implementation MooseAnimThumberAppDelegate

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
	[progress setDoubleValue: 0];
	[progress setMaxValue: 6];
	
	NSString*		fileImgFolder = [filename stringByAppendingPathComponent: @"Contents"];
	NSString*		infoFilePath = [fileImgFolder stringByAppendingPathComponent: @"info.txt"];
	NSDictionary*	groupDict = [UKGroupFile dictionaryFromGroupFile: infoFilePath withDefaultCategory: @"IGNORE"];
	NSString*		fsuffix = [[groupDict objectForKey: @"EXTENSION"] objectAtIndex: 0];
	[progress incrementBy: 1];
	[progress display];

	NSString*		baseImgPath = [fileImgFolder stringByAppendingPathComponent: [@"base" stringByAppendingString: fsuffix]];
	NSImage*		baseImg = [[[NSImage alloc] initWithContentsOfFile: baseImgPath] autorelease];
	[progress incrementBy: 1];
	[progress display];
	[preview setImage: baseImg];
	[preview display];

	NSString*		eyesImgPath = [fileImgFolder stringByAppendingPathComponent: [@"eyes-ahead" stringByAppendingString: fsuffix]];
	NSImage*		eyesImg = [[[NSImage alloc] initWithContentsOfFile: eyesImgPath] autorelease];
	[progress incrementBy: 1];
	[progress display];
	[preview setImage: eyesImg];
	[preview display];

	NSString*		mouthImgPath = [fileImgFolder stringByAppendingPathComponent: [@"mouth-0" stringByAppendingString: fsuffix]];
	NSImage*		mouthImg = [[[NSImage alloc] initWithContentsOfFile: mouthImgPath] autorelease];
	[progress incrementBy: 1];
	[progress display];
	[preview setImage: mouthImg];
	[preview display];
	
	NSRect			baseBox = NSZeroRect;
	baseBox.size = [baseImg size];
	NSRect			box = { { 0, 0 }, { 64, 64 } };
	box.size = [NSImage scaledSize: [baseImg size] toFitSize: box.size];
	NSImage*		finalImg = [[NSImage alloc] initWithSize: box.size];

	[finalImg lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		[baseImg drawInRect: box fromRect: baseBox operation: NSCompositeSourceOver fraction: 1.0];
		[mouthImg drawInRect: box fromRect: baseBox operation: NSCompositeSourceOver fraction: 1.0];
		[eyesImg drawInRect: box fromRect: baseBox operation: NSCompositeSourceOver fraction: 1.0];
		NSBitmapImageRep * imgRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect: box] autorelease];
	[finalImg unlockFocus];
	[progress incrementBy: 1];
	[progress display];
	[preview setImage: finalImg];
	[preview display];
	
	NSString*			outFileName = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension: @"png"];
	NSData*				pngData = [imgRep representationUsingType: NSPNGFileType properties: [NSDictionary dictionary]];
	[pngData writeToFile: outFileName atomically: NO];
	[progress incrementBy: 1];
	[progress display];
	
	[progress setDoubleValue: 0];

	return YES;
}

@end
