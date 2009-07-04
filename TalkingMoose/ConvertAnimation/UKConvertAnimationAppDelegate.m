//
//  UKConvertAnimationAppDelegate.m
//  ConvertAnimation
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKConvertAnimationAppDelegate.h"
#import "NDResourceFork.h"
#import "NDResourceFork+Cicn.h"


@implementation UKConvertAnimationAppDelegate

-(void) exportImage: (NSImage*)img toTiffFile: (NSString*)fpath
{
	NSData* tiffData = [img TIFFRepresentationUsingCompression: NSTIFFCompressionLZW factor: 0.5];
	[tiffData writeToFile: fpath atomically: NO];
}

-(NSImage*) imageOfSize: (NSSize)siz withImage: (NSImage*)img atPosition: (NSPoint)pos
{
	NSImage*	outImg = [[[NSImage alloc] initWithSize: siz] autorelease];
	
	[outImg lockFocus];
		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0,0,siz.width,siz.height));
		[img compositeToPoint: pos operation: NSCompositeSourceOver];
	[outImg unlockFocus];
	
	return outImg;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
	NDResourceFork*		resFork = [NDResourceFork resourceForkForReadingAtPath: filename];
	NSImage*			img = nil;
	NSString*			packageFile = [filename stringByAppendingPathExtension: @"nose"];
	NSString*			contentsFolder = [packageFile stringByAppendingPathComponent: @"Contents"];
	short				currID;
	NSData*				ditlData = nil;
	NSRect				mouthRect, eyesRect,
						fullRect = { { 0, 0 }, { 0, 0 } };
	short				coords[4];
	
	// Load 'DITL' resource containing layout info:
	// Size of animation:
	ditlData = [resFork dataForType: 'DITL' Id: 200];
	memmove( coords, [ditlData bytes] +6, 8 );
	fullRect.size.height = coords[2] -coords[0];
	fullRect.size.width = coords[3] -coords[1];
	
	// Position to draw mouth at:
	memmove( coords, [ditlData bytes] +6 +8 +6, 8 );
	mouthRect.size.height = coords[2] -coords[0];
	mouthRect.size.width = coords[3] -coords[1];
	mouthRect.origin.x = coords[1];
	mouthRect.origin.y = fullRect.size.height -coords[0] -mouthRect.size.height;
	
	// Position to draw eyes at:
	memmove( coords, [ditlData bytes] +6 +8 +6 +8 +6, 8 );
	eyesRect.size.height = coords[2] -coords[0];
	eyesRect.size.width = coords[3] -coords[1];
	eyesRect.origin.x = coords[1];
	eyesRect.origin.y = fullRect.size.height -coords[0] -eyesRect.size.height;
	
	// Create our bundle:
	[[NSFileManager defaultManager] createDirectoryAtPath: packageFile attributes: nil];
	[[NSFileManager defaultManager] createDirectoryAtPath: contentsFolder attributes: nil];
	
	[@"MOOSMOSe" writeToFile: [contentsFolder stringByAppendingPathComponent: @"PkgInfo"] atomically: NO];
	
	[progress startAnimation: nil];
	
	[status setStringValue: @"Extracting base image..."];
	[progress incrementBy: 1];
	img = [resFork imageForCicnId: 300];
	[imageView setImage: img];
	[imageView display];
	[progress display];
	[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: @"base.tiff"]];
	
	BOOL		fullPhonemes = ([resFork dataForType: 'PHOs' Id: 128] != nil);
	if( fullPhonemes )
	{
		for( currID = 400; currID < 442; currID++ )
		{
			[status setStringValue: [NSString stringWithFormat: @"Extracting phoneme %d...", currID -399]];
			[progress incrementBy: 1];
			img = [resFork imageForCicnId: currID];
			if( !img )
				break;
			img = [self imageOfSize: fullRect.size withImage: img atPosition: mouthRect.origin];
			[imageView setImage: img];
			[imageView display];
			[progress display];
			[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: [NSString stringWithFormat: @"mouth-%d.tiff", currID -400]]];
		}
	}
	else
	{
		NSString*		mouthShapes[5] = {  @"0",
											@"uh",
											@"oo",
											@"mm",
											@"ee" };
		
		for( currID = 400; currID < 405; currID++ )
		{
			[status setStringValue: [NSString stringWithFormat: @"Extracting mouth-%@...", mouthShapes[currID -400] ]];
			[progress incrementBy: 1];
			img = [resFork imageForCicnId: currID];
			if( !img )
				break;
			img = [self imageOfSize: fullRect.size withImage: img atPosition: mouthRect.origin];
			[imageView setImage: img];
			[imageView display];
			[progress display];
			[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: [NSString stringWithFormat: @"mouth-%@.tiff", mouthShapes[currID -400] ]]];
		}
	}
	
	[status setStringValue: @"Extracting eyes-ahead..."];
	[progress incrementBy: 1];
	img = [resFork imageForCicnId: 500];
	img = [self imageOfSize: fullRect.size withImage: img atPosition: eyesRect.origin];
	[imageView setImage: img];
	[imageView display];
	[progress display];
	[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: @"eyes-ahead.tiff"]];
	
	for( currID = 501; currID < 504; currID++ )
	{
		[status setStringValue: [NSString stringWithFormat: @"Extracting eyes-blink%d...", currID -500]];
		[progress incrementBy: 1];
		img = [resFork imageForCicnId: currID];
		if( !img )
			break;
		img = [self imageOfSize: fullRect.size withImage: img atPosition: eyesRect.origin];
		[imageView setImage: img];
		[imageView display];
		[progress display];
		[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: [NSString stringWithFormat: @"eyes-blink%d.tiff", currID -500]]];
	}
	
	NSString*		eyeDirs[8] = {  @"n",
									@"ne",
									@"e",
									@"se",
									@"s",
									@"nw",
									@"w",
									@"sw" };
	
	for( currID = 510; currID < 518; currID++ )
	{
		[status setStringValue: [NSString stringWithFormat: @"Extracting eyes-%@...", eyeDirs[currID -510] ]];
		[progress incrementBy: 1];
		img = [resFork imageForCicnId: currID];
		if( !img )
			break;
		img = [self imageOfSize: fullRect.size withImage: img atPosition: eyesRect.origin];
		[imageView setImage: img];
		[imageView display];
		[progress display];
		[self exportImage: img toTiffFile: [contentsFolder stringByAppendingPathComponent: [NSString stringWithFormat: @"eyes-%@.tiff", eyeDirs[currID -510] ]]];
	}
	
	// Write info.txt file:
	NSString*   infoStr = [NSString stringWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"info" ofType: @"txt"]];
	infoStr = [NSString stringWithFormat: infoStr, [filename lastPathComponent], fullPhonemes ? @"" : @"REDUCED PHONEMES"];
	[infoStr writeToFile: [contentsFolder stringByAppendingPathComponent: @"info.txt"] atomically: NO];

	[progress setDoubleValue: 0];
	[status setStringValue: @"Ready."];
	[progress stopAnimation: nil];
	
	return YES;
}

@end
