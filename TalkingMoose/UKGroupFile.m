//
//  UKGroupFile.m
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKGroupFile.h"
#import "UKHelperMacros.h"


NSString*	UKGroupFileCommandNameKey = @"UKGroupFileCommandName";
NSString*	UKGroupFileCommandArgsKey = @"UKGroupFileCommandArgs";


@implementation UKGroupFile

-(id)   init
{
	if( (self = [super init]) )
    {
		mooseInfo = [[NSMutableDictionary alloc] init];
		imageCache = [[NSMutableDictionary alloc] init];
    }
	
	return self;
}


-(id)   initFromGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat
{
	self = [self init];
	if( self )
	{
		[self parseGroupFile: fpath withDefaultCategory: defCat];
		imageCache = [[NSMutableDictionary alloc] init];
		changeCount = 0;
	}
	
	return self;
}


-(id)   initFromGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat;
{
	self = [self init];
	if( self )
	{
		[self parseGroupString: str withDefaultCategory: defCat];
		imageCache = [[NSMutableDictionary alloc] init];
		changeCount = 0;
	}
	
	return self;
}


-(void) dealloc
{
	DESTROY(mooseInfoForDisplay);
	DESTROY(mooseInfo);
	DESTROY(imageCache);
	
	[super dealloc];
}


-(NSString*)	filePath
{
	return [mooseInfo objectForKey: @"CONTENTSPATH"];
}


-(NSMutableDictionary*) takeOverDictionary
{
	NSMutableDictionary*   mi = mooseInfo;
	
	mooseInfo = nil;
	[mi autorelease];
	
	return mi;
}


-(NSString*)   lineForKey: (NSString*)key index: (int)idx
{
	return [[mooseInfo objectForKey: key] objectAtIndex: idx];
}

-(NSImage*)		imageFileForKey: (NSString*)key index: (int)idx
{
	NSString*   bgFilename = [self filenameForKey: key index: idx];
    NSImage*    img = nil;

    img = [imageCache objectForKey: bgFilename];
    if( !img )
    {
        img = [[[NSImage alloc] initWithContentsOfFile: bgFilename] autorelease];
        /*if( img )
            img = [img scaledImageToFitSize: [img size]];*/
        [img setCacheMode: NSImageCacheAlways];
        
        if( img )
            [imageCache setObject: img forKey: bgFilename];
    }
    
    return img;
}

-(NSImage*)		imageFileFromString: (NSString*)fname
{
	NSString*   bgFilename = [self filenameFromString: fname extension: nil];
	NSImage*    img = nil;
    
    img = [imageCache objectForKey: bgFilename];
    if( !img )
    {
        img = [[[NSImage alloc] initWithContentsOfFile: bgFilename] autorelease];
        /*if( img )
            img = [img scaledImageToFitSize: [img size]];*/
        [img setCacheMode: NSImageCacheAlways];
        
        if( img )
			[imageCache setObject: img forKey: bgFilename];
    }
    
    return img;
}


-(NSString*)		filenameFromString: (NSString*)fname extension: (NSString*)ext
{
	NSString*		fpath = [mooseInfo objectForKey: @"CONTENTSPATH"];
	NSString*		suffix = ext ? ext : [self lineForKey: @"EXTENSION" index: 0];
	
	return [fpath stringByAppendingFormat: @"/%@%@", fname, suffix];
}

-(NSString*)		filenameForKey: (NSString*)key index: (int)idx
{
	NSString*		fname = [self lineForKey: key index: idx];
	
	return [self filenameFromString: fname extension: nil];
}


-(NSMutableDictionary*) dictionary
{
	return mooseInfo;
}


-(NSMutableDictionary*)	dictionaryForDisplay
{
	if( !mooseInfoForDisplay )
	{
		NSMutableDictionary*	md = [[mooseInfo mutableCopy] autorelease];
		[md removeObjectForKey: @"CONTENTSPATH"];
		ASSIGN(mooseInfoForDisplay,md);
	}
	
	return mooseInfoForDisplay;
}


+(NSMutableDictionary*) dictionaryFromGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat
{
	UKGroupFile*	gf = [[[UKGroupFile alloc] init] autorelease];
	
	[gf parseGroupFile: fpath withDefaultCategory: defCat];
	
	return [gf takeOverDictionary];
}

-(void) parseGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat
{
	NSError*				theError = nil;
	NSString*				infoText = [NSString stringWithContentsOfFile: fpath encoding: NSUTF8StringEncoding error: &theError];
	[self parseGroupString: infoText withDefaultCategory: defCat];
	[mooseInfo setObject: [fpath stringByDeletingLastPathComponent] forKey: @"CONTENTSPATH"];
}

+(NSMutableDictionary*)	dictionaryFromGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat
{
	UKGroupFile*	gf = [[[UKGroupFile alloc] init] autorelease];
	
	[gf parseGroupString: str withDefaultCategory: defCat];
	
	return [gf takeOverDictionary];
}

-(void)		parseGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat
{
	NSArray*				arr = [str componentsSeparatedByString: @"\n"];
	if( [arr count] == 1 )
		arr = [str componentsSeparatedByString: @"\r"];
	NSEnumerator*			enny = [arr objectEnumerator];
	NSString*				currLine = nil;
	NSString*				currentCategory = defCat;
	NSMutableArray*			currentCategoryLines = nil;
	NSCharacterSet*			titleSet = [NSCharacterSet characterSetWithCharactersInString: @"ABCDEFGHIJKLMNOPQRSTUVWXYZ "];
	NSCharacterSet*			wsnlcs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	int						linesAdded = 0;
	
	currentCategoryLines = [mooseInfo objectForKey: defCat];
	if( !currentCategoryLines )
	{
		currentCategoryLines = [NSMutableArray array];
		[mooseInfo setObject: currentCategoryLines forKey: defCat];  // Create the default category for lines at start without category label.
		linesAdded++;
	}
	
	while( (currLine = [enny nextObject]) )
	{
		if( [currLine length] == 0 )
			continue;
		
		if( [currLine characterAtIndex: 0] == '#' ) // Comment line? Skip.
			continue;
		
		if( [[currLine stringByTrimmingCharactersInSet: wsnlcs] length] == 0 )  // Empty line? Skip.
			continue;
		
		NSString*   trimmedLine = [currLine stringByTrimmingCharactersInSet: titleSet];
		if( [trimmedLine length] == 0 )	// All uppercase?
		{
			// Category designator. Switch to that category:
			currentCategory = currLine;
			currentCategoryLines = [mooseInfo objectForKey: currentCategory];
			if( !currentCategoryLines ) // New category? Create!
			{
				currentCategoryLines = [NSMutableArray array];
				[mooseInfo setObject: currentCategoryLines forKey: currentCategory];
				linesAdded++;
			}
		}
		else	// Regular line?
		{
			[currentCategoryLines addObject: currLine]; // Add to current category.
			linesAdded++;
			numPhrases++;
		}
	}
	
	if( linesAdded > 0 )
		changeCount++;
}


int		UKShuffleCompareFunction( id a, id b, void* c )
{
	return ((rand() & 1) == 1) ? 1 : -1;
}


-(void) shuffleCategory: (NSString*)categoryName
{
	NSMutableArray*		arr = [mooseInfo objectForKey: categoryName];
	[arr sortUsingFunction: UKShuffleCompareFunction context:nil];
}


-(void)	deleteEmptyCategories
{
	NSEnumerator*			enny = [[mooseInfo allKeys] objectEnumerator];
	NSString*				currKey = nil;
	NSMutableDictionary*	newMooseInfo = [[NSMutableDictionary alloc] initWithCapacity: [mooseInfo count]];
	
	while(( currKey = [enny nextObject] ))
	{
		NSArray*	objs = [mooseInfo objectForKey: currKey];
		if( ![objs isKindOfClass: [NSArray class]] || [objs count] > 0 )
			[newMooseInfo setObject: objs forKey: currKey];
	}
	
	[mooseInfo release];
	mooseInfo = newMooseInfo;
}


-(id)   objectForKey: (NSString*)key
{
	return [mooseInfo objectForKey: key];
}

-(void)   setObject: (id)obj forKey: (NSString*)key
{
	[mooseInfo setObject: obj forKey: key];
	changeCount++;
}


-(id)   valueForKey: (NSString*)key
{
	return [mooseInfo objectForKey: key];
}

-(void)   setValue: (id)obj forKey: (NSString*)key
{
	[mooseInfo setObject: obj forKey: key];
	changeCount++;
}


-(BOOL)	isChanged
{
	return( changeCount != 0 );
}

-(void)	resetChangeCount
{
	changeCount = 0;
}


-(BOOL)		writeToFile: (NSString*)fpath atomically: (BOOL)yorn
{
	return [self writeToFile: fpath atomically: yorn withPrefix: @""];
}

-(BOOL)		writeToFile: (NSString*)fpath atomically: (BOOL)yorn withPrefix: (NSString*)prefix
{
	NSEnumerator*		enny = [mooseInfo keyEnumerator];
	NSString*			currKey = nil;
	NSMutableString*	fileContents = [[prefix mutableCopy] autorelease];
	
	while(( currKey = [enny nextObject] ))
	{
		if( [currKey isEqualToString: @"CONTENTSPATH"] )
			continue;
		
		NSArray*	entries = [mooseInfo objectForKey: currKey];
		if( [entries count] <= 0 )
			continue;
		
		[fileContents appendString: currKey];
		[fileContents appendString: @"\n"];
		
		NSEnumerator*	entryEnny = [entries objectEnumerator];
		NSString*		currEntry = nil;
		while(( currEntry = [entryEnny nextObject] ))
		{
			[fileContents appendString: currEntry];
			[fileContents appendString: @"\n"];
		}
		
		[fileContents appendString: @"\n"];
	}
	
	NSError	*	theError = nil;
	return [fileContents writeToFile: fpath atomically: yorn encoding: NSUTF8StringEncoding error: &theError];
}


+(BOOL)		cleanUpGroupFile: (NSString*)fpath
{
	NSError			*	theError = nil;
	NSMutableString	*	str = [NSMutableString stringWithContentsOfFile: fpath encoding: NSUTF8StringEncoding error: &theError];
	
	if( [str replaceOccurrencesOfString:@"\r" withString:@"\n" options: NSLiteralSearch range:NSMakeRange(0,[str length])] > 0 )
		return [str writeToFile: fpath atomically: NO encoding: NSUTF8StringEncoding error: &theError];
	else
		return YES;
}


-(int)		numPhrases
{
	return numPhrases;
}


@end


NSDictionary*	UKGroupFileExtractCommandFromPhrase( NSString* inPhrase )
{
	if( [inPhrase length] < 3 )
		return nil;
		
	if( ![inPhrase hasPrefix: @"%%"] )
		return nil;
	
	NSRange		firstSpaceRange = [inPhrase rangeOfString: @" "];
	if( firstSpaceRange.location == NSNotFound )
		firstSpaceRange = NSMakeRange( [inPhrase length], 0 );
	NSString*	commandName = [inPhrase substringWithRange: NSMakeRange( 2, firstSpaceRange.location -2)];
	NSString*	argsStr = [inPhrase substringWithRange: NSMakeRange( firstSpaceRange.location +firstSpaceRange.length, [inPhrase length] -firstSpaceRange.location -firstSpaceRange.length)];
	NSArray*	args = [argsStr componentsSeparatedByString: @" "];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
							commandName, UKGroupFileCommandNameKey,
							args, UKGroupFileCommandArgsKey, nil];
}
