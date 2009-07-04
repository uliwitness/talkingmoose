//
//  UKPhraseDatabase.m
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKPhraseDatabase.h"
#import "UKGroupFile.h"
#import "NSFileManager+CreateDirectoriesForPath.h"


@implementation UKPhraseDatabase

-(id)   init
{
	if( (self = [super init]) )
	{
		phraseFiles = [[UKGroupFile alloc] init];
		
		NSFileManager*	fm = [NSFileManager defaultManager];
		NSString*		stdPhrasePath = [@"~/Library/Application Support/Moose/Standard Phrases" stringByExpandingTildeInPath];
		NSString*		stdPhrasePathOff = [@"~/Library/Application Support/Moose/Standard Phrases (Off)" stringByExpandingTildeInPath];
		NSString*		builtinPhrasePath = [[NSBundle mainBundle] pathForResource: @"Phrases" ofType: nil];
		if( ![fm fileExistsAtPath: stdPhrasePath] )
			[fm createDirectoriesForPath: stdPhrasePath];
		NSArray*	builtinPhrases = [fm directoryContentsAtPath: builtinPhrasePath];
		int			x = 0, numFiles = [builtinPhrases count];
		for( x = 0; x < numFiles; x++)
		{
			NSString*	currFileName = [builtinPhrases objectAtIndex: x];
			if( [currFileName characterAtIndex: 0] == '.' )	// Ignore any errant DS_Store etc.
				continue;
			NSString*	currFile = [stdPhrasePath stringByAppendingPathComponent: currFileName];
			NSString*	currFileOff = [stdPhrasePathOff stringByAppendingPathComponent: currFileName];
			NSString*	srcFile = [builtinPhrasePath stringByAppendingPathComponent: currFileName];
			if( ![fm fileExistsAtPath: currFile] && ![fm fileExistsAtPath: currFileOff] )
				[fm copyPath: srcFile toPath: currFile handler: nil];
			// +++ NEED TO RE-COPY OLD FILES ON UPDATE!
		}
		
		[self loadPhrasesInFolder: stdPhrasePath];
		[self loadPhrasesInFolder: @"/Library/Application Support/Moose/Phrases"];
		[self loadPhrasesInFolder: @"~/Library/Application Support/Moose/Phrases"];
	}
	
	return self;
}


-(void) loadPhrasesInFolder: (NSString*)foldPath
{
	NSString*			phraseFolder = [foldPath stringByExpandingTildeInPath];
	NSEnumerator*		enny = [[[NSFileManager defaultManager] subpathsAtPath: phraseFolder] objectEnumerator];
	NSString*			currPath = nil;
	
	while( (currPath = [enny nextObject]) )
	{
		if( [currPath characterAtIndex:0] == '.' )
			continue;
		if( ![[currPath pathExtension] isEqualToString: @"txt"]
			&& ![[currPath pathExtension] isEqualToString: @"phraseFile"] )
			continue;
		
		currPath = [phraseFolder stringByAppendingPathComponent: currPath];
		
		[self loadPhrasesInFile: currPath];
	}
	
	[[phraseFiles dictionary] removeObjectForKey: @"CONTENTSPATH"];
	
	// Now randomize the order of entries in the database:
	NSEnumerator*   catEnny = [[phraseFiles dictionary] keyEnumerator];
	NSString*		theCat = nil;
	
	while( (theCat = [catEnny nextObject]) )
		[phraseFiles shuffleCategory: theCat];
}


-(void)	loadPhrasesInFile: (NSString*)currPath
{
	[UKGroupFile cleanUpGroupFile: currPath];
	int		oldNumPhrases = [phraseFiles numPhrases];
	[phraseFiles parseGroupFile: currPath withDefaultCategory: @"PAUSE"];
	UKLog(@"Loaded %d phrases from file %@.",([phraseFiles numPhrases] -oldNumPhrases),currPath);
}


-(void) dealloc
{
	[phraseFiles release];
	[mostRecentPhrase release];
	
	[super dealloc];
}


-(NSString*)	randomPhraseFromGroup: (NSString*)key
{
	NSArray*		phrases = [phraseFiles objectForKey: key];
	NSString*		prefsKey = [@"Phrases:CurrIndex:" stringByAppendingString: key];
	int				currIndex = [[[NSUserDefaults standardUserDefaults] objectForKey: prefsKey] intValue];
	
	// Make sure random number lies in range:
	if( currIndex >= [phrases count] )
		currIndex = 0;
	
	[mostRecentPhrase release];
	mostRecentPhrase = [[phrases objectAtIndex: currIndex] retain];
	
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: (currIndex +1)] forKey: prefsKey];
	
	return mostRecentPhrase;
}


-(NSString*)	mostRecentPhrase
{
	return mostRecentPhrase;
}


-(void)			setMostRecentPhrase: (NSString*)mrp
{
	if( mrp != mostRecentPhrase )
	{
		[mostRecentPhrase release];
		mostRecentPhrase = [mrp retain];
	}
}


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if( item == nil )
	{
		NSArray*	items = [[phraseFiles dictionary] allValues];
        
		return [items objectAtIndex: index];
	}
	else
		return [item objectAtIndex: index];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if( ![item isKindOfClass: [NSArray class]] )
        return NO;
    
	return( [[phraseFiles dictionary] objectForKey: @"PHRASES"] != item );
}


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if( item == nil )
		return [[[phraseFiles dictionary] allKeys] count];
	else
		return [item count];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if( [item isKindOfClass: [NSArray class]] )
	{
        NSString* key = [[[phraseFiles dictionary] allKeysForObject: item] objectAtIndex: 0];
        
        if( [key isEqualToString: @"PHRASES"] )
            return @"(ignore)";
        else
            return key;
    }
	else
		return item;
}


@end
