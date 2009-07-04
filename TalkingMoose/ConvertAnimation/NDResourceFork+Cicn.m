//
//  NDResourceFork+Cicn.m
//  1FUG
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "NDResourceFork+Cicn.h"
#include <Carbon/Carbon.h>


@interface NDResourceFork (CicnPrivateMethods)

-(CIconHandle)  cicnHandleForId:(short)anID;
+(void)			releaseCIconHandle: (CIconHandle)theIcon;
+(NSImage*)		imageFromCicnHandle: (CIconHandle)theIcon;

@end


@implementation NDResourceFork (Cicn)

-(NSImage*)		imageForCicnId: (short)anID
{
	NSImage*	img = nil;
	CIconHandle icon = [self cicnHandleForId: anID];
	if( icon )
	{
		img = [NDResourceFork imageFromCicnHandle: icon];
		[NDResourceFork releaseCIconHandle: icon];
	}
	
	return img;
}

@end


@implementation NDResourceFork (CicnPrivateMethods)

/*
 * cicnHandleForId:Id:
 */
- (CIconHandle) cicnHandleForId:(short)anID
{
	CIconHandle		theResHandle = nil;
	short			thePreviousRefNum;

	thePreviousRefNum = CurResFile();		// save current resource
	
	UseResFile( fileReference );    		// set this resource to be current

	if( noErr ==  ResError( ) )
		theResHandle = GetCIcon( anID );
	
	UseResFile( thePreviousRefNum );		// reset back to resource previously set
	
	return theResHandle;
}

+(void) releaseCIconHandle: (CIconHandle)theIcon
{
	DisposeCIcon( theIcon );
}


#define DO_FIX(n)			((n) & 0xff00)  // Don't need more'n 24 bits anyway.

BOOL	IconCTabHasColor( CIconHandle theIcon, RGBColor transparentColor )
{
	CTabHandle  theTable = (**theIcon).iconPMap.pmTable;
		
	short x = (**theTable).ctSize;
	while( x >= 0 )
	{
		RGBColor	col;
		col = (**theTable).ctTable[x].rgb;
		
		if( DO_FIX(col.red) == DO_FIX(transparentColor.red)
			&& DO_FIX(col.green) == DO_FIX(transparentColor.green)
			&& DO_FIX(col.blue) == DO_FIX(transparentColor.blue) )
			return YES;
		
		--x;
	}
	
	return NO;
}


+(NSImage*) imageFromCicnHandle: (CIconHandle)theIcon
{
	GWorldPtr		theWorld = NULL;
	Rect			box = (**theIcon).iconPMap.bounds;
	PicHandle		thePicture = NULL;
	BitMap*			thePortBits;
	RGBColor		transparentColor = { 0x0000, 0x0000, 0xffff };
	
	if( NewGWorld( &theWorld, 0, &box, NULL, NULL, 0 ) != noErr )
		return nil;
	
	if( LockPixels( GetPortPixMap(theWorld) ) )
	{
		SetGWorld( theWorld, NULL );
		
		while( IconCTabHasColor( theIcon, transparentColor ) )
		{
			transparentColor.red += rand();
			transparentColor.green += rand();
			transparentColor.blue += rand();
		}
		
		OffsetRect( &box, -box.left, -box.top );
		RGBForeColor( &transparentColor );
		PaintRect( &box );
		ForeColor( blackColor );
		PlotCIcon( &box, theIcon );
		
		// Record the GWorld's contents into a PICT:
		thePicture = OpenPicture( &box );
		thePortBits = GetPortBitMapForCopyBits( theWorld );
		CopyBits( thePortBits, thePortBits, &box, &box,
					srcCopy, NULL );	// Copy onto itself. Needed as PlotCIcon isn't recorded into PICTs.
		ClosePicture();
		
		UnlockPixels( GetPortPixMap(theWorld) );
	}
	else
		return nil;
	
	DisposeGWorld( theWorld );
	
	NSImageRep* rep = [NSPICTImageRep imageRepWithData: [NSData dataWithBytes: (*thePicture)
											length: GetHandleSize((Handle)thePicture)]];
	NSImage*	image = [[[NSImage alloc] init] autorelease];
	KillPicture( thePicture );
	
	[image addRepresentation: rep];
	[image lockFocus];
		NSRect			pixelBox = { { 0, 0 }, { 1, 1 } };
		
		[[NSColor clearColor] set];
		
		while( pixelBox.origin.y < (box.bottom -box.top) )
		{
			pixelBox.origin.x = 0;
			while( pixelBox.origin.x < (box.right -box.left) )
			{
				NSColor*	col;
				float		r, g, b;
				short		rr, gg, bb;
				
				col = NSReadPixel( pixelBox.origin );
				r = [col redComponent];
				g = [col greenComponent];
				b = [col blueComponent];
				
				r *= 65535;
				g *= 65535;
				b *= 65535;
				rr = r; gg = g; bb = b;
				
				if( DO_FIX(rr) == DO_FIX(transparentColor.red)
					&& DO_FIX(gg) == DO_FIX(transparentColor.green)
					&& DO_FIX(bb) == DO_FIX(transparentColor.blue) )
					NSRectFill( pixelBox );
				
				pixelBox.origin.x++;
			}
			
			pixelBox.origin.y++;
		}
	[image unlockFocus];
	
	return image;
}


@end
