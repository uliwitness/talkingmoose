//
//  UKRecordedSpeechChannel.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 27.08.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "UKRecordedSpeechChannel.h"
#import "UKHelperMacros.h"


@implementation UKRecordedSpeechChannel

-(void)	dealloc
{
	[self stopSpeaking];
	
	[super dealloc];
}

-(BOOL)	isSpeaking
{
	return( currentSound != nil );
}

-(void)	stopSpeaking
{
	if( currentSound && delegateHasFinishedCallback )
		[delegate speechSynthesizer: (NSSpeechSynthesizer*)self didFinishSpeaking: NO];
	[phonemeTimer invalidate];
	DESTROY(phonemeTimer);
	DESTROY( currentSound );
	DESTROY( phonemes );
}

-(void)	startSpeakingSoundFileAtPath: (NSString*)inPath
{
	[phonemeTimer invalidate];
	DESTROY(phonemeTimer);
	
	NSString*		phonemeDictPath = [[inPath stringByDeletingPathExtension] stringByAppendingPathExtension: @"plist"];
	ASSIGN(phonemes,[NSArray arrayWithContentsOfFile: phonemeDictPath]);
	
	[currentSound release];
	currentSound = [[NSSound alloc] initWithContentsOfFile: inPath byReference: YES];
	[currentSound setDelegate: self];
	speechStartTime = [NSDate timeIntervalSinceReferenceDate];
	currListEntryIdx = 0;
	phonemeTimer = [[NSTimer scheduledTimerWithTimeInterval: 0.01 target: self selector: @selector(spendTime:) userInfo: nil repeats: YES] retain];
	[currentSound play];
	if( delegateHasPhonemeCallback )
	{
		lastPhoneme = 0;
		if( phonemes && [phonemes count] > 0 )
			lastPhoneme = [[[phonemes objectAtIndex: 0] objectForKey: @"phonemeOpcode"] intValue];
		[delegate speechSynthesizer: (NSSpeechSynthesizer*)self willSpeakPhoneme: lastPhoneme];
	}
}

-(void)	setDelegate: (id)del
{
	delegate = del;
	//delegateHasWordCallback = [delegate respondsToSelector: @selector(speechSynthesizer:willSpeakWord:ofString:)];
	delegateHasPhonemeCallback = [delegate respondsToSelector: @selector(speechSynthesizer:willSpeakPhoneme:)];
	delegateHasFinishedCallback = [delegate respondsToSelector: @selector(speechSynthesizer:didFinishSpeaking:)];
}


-(void)	spendTime: (NSTimer*)tim
{
	NSUInteger numPhonemeEntries = [phonemes count];
	if( !phonemes || currListEntryIdx < 0 || currListEntryIdx >= numPhonemeEntries )
	{
		currListEntryIdx = -1;
		return;
	}
	
	NSTimeInterval	currentTime = [NSDate timeIntervalSinceReferenceDate];
	NSDictionary*	highestMatchDict = [phonemes objectAtIndex: currListEntryIdx];
	int				idx = currListEntryIdx;
	while( idx < numPhonemeEntries )
	{
		NSDictionary*	dict = [phonemes objectAtIndex: idx];
		if( (currentTime -speechStartTime) >= [[dict objectForKey: @"time"] doubleValue] )
		{
			highestMatchDict = dict;
			currListEntryIdx = idx;
		}
		idx++;
	}
	
	short			phonemeOpcode = [[highestMatchDict objectForKey: @"phonemeOpcode"] intValue];
	if( phonemeOpcode != lastPhoneme && delegateHasPhonemeCallback )
	{
		[delegate speechSynthesizer: (NSSpeechSynthesizer*)self willSpeakPhoneme: phonemeOpcode];
		lastPhoneme = phonemeOpcode;
	}
}


-(void)	sound: (NSSound *)sound didFinishPlaying: (BOOL)aBool
{
	[phonemeTimer invalidate];
	DESTROY(phonemeTimer);
	if( currentSound && delegateHasFinishedCallback )
		[delegate speechSynthesizer: (NSSpeechSynthesizer*)self didFinishSpeaking: YES];
	DESTROY( currentSound );
	DESTROY( phonemes );
}

@end
