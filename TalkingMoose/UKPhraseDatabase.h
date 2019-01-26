//
//  UKPhraseDatabase.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class  UKGroupFile;


@interface UKPhraseDatabase : NSObject <NSOutlineViewDataSource>
{
	UKGroupFile*	phraseFiles;
	NSString*		mostRecentPhrase;
}

-(NSString*)	randomPhraseFromGroup: (NSString*)key;
-(NSString*)	mostRecentPhrase;
-(void)			setMostRecentPhrase: (NSString*)mrp;

-(void)			loadPhrasesInFolder: (NSString*)foldPath;	// Whole folder of phrase files.
-(void)			loadPhrasesInFile: (NSString*)currPath;		// Single phrase file.

@end
