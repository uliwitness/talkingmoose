//
//  UKMoosePreGenerateTestAppDelegate.m
//  MoosePreGenerateTest
//
//  Created by Uli Kusterer on 19.06.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "UKMoosePreGenerateTestAppDelegate.h"


@implementation UKMoosePreGenerateTestAppDelegate

-(id) init
{
	self = [super init];
	if( self != nil )
	{
		synth = [[NSSpeechSynthesizer alloc] init];
		[synth setDelegate: self];
		[synth setObject: NSSpeechModePhoneme forProperty: NSSpeechInputModeProperty error: nil];
		currListEntryIdx = -1;
		[NSTimer scheduledTimerWithTimeInterval: 0.01 target: self selector: @selector(speechPhonemeTimer:) userInfo: nil repeats: YES];
	}
	return self;
}


-(void)	dealloc
{
	[synth release];
	synth = nil;
	[phonemeList release];
	phonemeList = nil;
	
	[super dealloc];
}


-(IBAction)	generatePhonemes: (id)sender
{
	[progress startAnimation: nil];
	[synth setObject: NSSpeechModeText forProperty: NSSpeechInputModeProperty error: nil];
	NSString*	theTx = [textField stringValue];
	NSString*	phonStr = [synth phonemesFromText: theTx];
	[phonemeField setStringValue: phonStr];
	[synth setObject: NSSpeechModePhoneme forProperty: NSSpeechInputModeProperty error: nil];
}


-(IBAction) speakText: (id)sender
{
	[progress startAnimation: nil];
	currListEntryIdx = -1;
	[synth setDelegate: self];
	#if PHONEME_STUFF
	[self generatePhonemes: nil];
	#else
	[synth setObject: NSSpeechModeText forProperty: NSSpeechInputModeProperty error: nil];
	#endif
	if( phonemeList )
	{
		[phonemeList release];
		phonemeList = nil;
	}
	phonemeList = [[NSMutableArray alloc] init];
	speechStartTime = [NSDate timeIntervalSinceReferenceDate];
	#if PHONEME_STUFF
	[synth startSpeakingString: [phonemeField stringValue]];
	#else
	[synth startSpeakingString: [textField stringValue]];
	#endif
}


-(void)	speechSynthesizer: (NSSpeechSynthesizer *)sender willSpeakPhoneme: (short)phonemeOpcode
{
	static NSArray*	phonemes = nil;
	if( !phonemes )
		phonemes = [synth objectForProperty: NSSpeechPhonemeSymbolsProperty error: nil];
	for( NSDictionary* currPhoneme in phonemes )
	{
		if( [[currPhoneme objectForKey: NSSpeechPhonemeInfoOpcode] intValue] == phonemeOpcode )
		{
			NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
			NSDictionary* currPhonEntry = [NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithDouble: (currentTime -speechStartTime)], @"time",
														[currPhoneme objectForKey: NSSpeechPhonemeInfoSymbol], @"phoneme",
														[currPhoneme objectForKey: NSSpeechPhonemeInfoOpcode], @"phonemeOpcode",
														nil];
			[phonemeList addObject: currPhonEntry];
			break;
		}
	}
}

-(void)	speechSynthesizer: (NSSpeechSynthesizer *)sender didFinishSpeaking: (BOOL)finishedSpeaking
{
	if( !writingSpeechToFile )
	{
		writingSpeechToFile = YES;
		[synth startSpeakingString: [phonemeField stringValue] toURL: [NSURL fileURLWithPath: [@"~/Documents/SpokenString.aiff" stringByExpandingTildeInPath]]];
	}
	else
	{
		writingSpeechToFile = NO;
		[phonemeList writeToFile: [@"~/Documents/SpokenStringPhonemes.plist" stringByExpandingTildeInPath] atomically: YES];
	}
	[progress stopAnimation: nil];
}


-(IBAction)	playbackOnceSpokenString: (id)sender
{
	NSSound*	theSound = [[[NSSound alloc] initWithContentsOfFile: [@"~/Documents/SpokenString.aiff" stringByExpandingTildeInPath] byReference: YES] autorelease];
	
	if( phonemeList )
	{
		[phonemeList release];
		phonemeList = nil;
	}
	phonemeList = [[NSArray alloc] initWithContentsOfFile: [@"~/Documents/SpokenStringPhonemes.plist" stringByExpandingTildeInPath]];
	speechStartTime = [NSDate timeIntervalSinceReferenceDate];
	currListEntryIdx = 0;
	[theSound play];
}

-(void)	speechPhonemeTimer: (NSTimer*)aTimer
{
	int numPhonemeEntries = [phonemeList count];
	if( !phonemeList || currListEntryIdx < 0 || currListEntryIdx >= numPhonemeEntries )
	{
		currListEntryIdx = -1;
		return;
	}
	
	NSTimeInterval	currentTime = [NSDate timeIntervalSinceReferenceDate];
	NSDictionary*	highestMatchDict = [phonemeList objectAtIndex: currListEntryIdx];
	int				idx = currListEntryIdx;
	while( idx < numPhonemeEntries )
	{
		NSDictionary*	dict = [phonemeList objectAtIndex: idx];
		if( (currentTime -speechStartTime) >= [[dict objectForKey: @"time"] doubleValue] )
		{
			highestMatchDict = dict;
			currListEntryIdx = idx;
		}
		idx++;
	}
	
	[currPhonemeField setStringValue: [highestMatchDict objectForKey: @"phoneme"]];
}

@end
