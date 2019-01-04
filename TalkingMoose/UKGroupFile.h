//
//  UKGroupFile.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Mon Apr 05 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface UKGroupFile : NSObject
{
	NSMutableDictionary*		mooseInfo;		// The dictionary into which data is read. See below.
    NSMutableDictionary*        imageCache;     // Cached images for faster drawing.
	unsigned int				changeCount;	// 0 if file unchanged, otherwise > 0.
	int							numPhrases;
	NSMutableDictionary*		mooseInfoForDisplay;	// Cached cleaned-up version of mooseInfo for display in tables etc.
}

+(NSMutableDictionary*) dictionaryFromGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat;
+(NSMutableDictionary*)	dictionaryFromGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat;
+(BOOL)					cleanUpGroupFile: (NSString*)fpath;

-(id)					initFromGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat;
-(id)					initFromGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat;

-(void)					parseGroupFile: (NSString*)fpath withDefaultCategory: (NSString*)defCat;
-(void)					parseGroupString: (NSString*)str withDefaultCategory: (NSString*)defCat;

-(NSString*)			lineForKey: (NSString*)key index: (int)idx;
-(NSImage*)				imageFileForKey: (NSString*)key index: (int)idx;
-(NSString*)			filenameForKey: (NSString*)key index: (int)idx;
-(NSString*)			filenameFromString: (NSString*)fname extension: (NSString*)ext;
-(NSImage*)				imageFileFromString: (NSString*)fname;

-(NSMutableDictionary*) dictionary;
-(NSMutableDictionary*) dictionaryForDisplay;
-(NSMutableDictionary*) takeOverDictionary;

-(id)		objectForKey: (NSString*)key;
-(void)		setObject: (id)obj forKey: (NSString*)key;
-(id)		valueForKey: (NSString*)key;
-(void)		setValue: (id)obj forKey: (NSString*)key;

-(BOOL)		isChanged;
-(void)		resetChangeCount;

-(void)		deleteEmptyCategories;
-(void)		shuffleCategory: (NSString*)categoryName;

// The following two do not retain any comments or empty lines/groups that may have been in the file:
-(BOOL)		writeToFile: (NSString*)fpath atomically: (BOOL)yorn;
-(BOOL)		writeToFile: (NSString*)fpath atomically: (BOOL)yorn withPrefix: (NSString*)prefix;	// The prefix is written to the file before the actual data. It should only consist of comments or other valid text for a group file. It *must* end in a line break ("\n").

-(NSString*)	filePath;

-(int)			numPhrases;

@end

extern NSDictionary*	UKGroupFileExtractCommandFromPhrase( NSString* inPhrase );

extern NSString*	UKGroupFileCommandNameKey;
extern NSString*	UKGroupFileCommandArgsKey;



/*
	The mooseInfo dictionary has the following format:
	
	The keys are the category names, the values contain arrays of the lines in
	that category as NSStrings.
	
	If the data was read from a file, one key, @"CONTENTSPATH", contains a string
	with the path of the file.
*/
