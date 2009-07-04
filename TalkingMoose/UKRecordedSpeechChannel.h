//
//  UKRecordedSpeechChannel.h
//  TalkingMoose
//
//  Created by Uli Kusterer on 27.08.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UKRecordedSpeechChannel : NSObject
{
	NSSound*		currentSound;
	NSTimeInterval	speechStartTime;
	int				currListEntryIdx;
	NSTimer*		phonemeTimer;
	NSArray*		phonemes;
	id				delegate;
	int				lastPhoneme;
	unsigned int	delegateHasWordCallback:1;		// Not Yet Implemented.
	unsigned int	delegateHasPhonemeCallback:1;
	unsigned int	delegateHasFinishedCallback:1;
	unsigned int	reservedFlags:29;
}

-(BOOL)	isSpeaking;

-(void)	stopSpeaking;

-(void)	startSpeakingSoundFileAtPath: (NSString*)inPath;

-(void)	setDelegate: (id)del;

@end
