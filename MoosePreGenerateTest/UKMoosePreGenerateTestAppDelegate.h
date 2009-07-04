//
//  UKMoosePreGenerateTestAppDelegate.h
//  MoosePreGenerateTest
//
//  Created by Uli Kusterer on 19.06.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UKMoosePreGenerateTestAppDelegate : NSObject
{
	NSSpeechSynthesizer*	synth;
	IBOutlet NSTextField*	textField;
	IBOutlet NSTextField*	phonemeField;
	IBOutlet NSTextField*	currPhonemeField;
	NSTimeInterval			speechStartTime;
	NSMutableArray*			phonemeList;
	int						currListEntryIdx;
	BOOL					writingSpeechToFile;
	IBOutlet NSProgressIndicator*	progress;
}

-(IBAction)	generatePhonemes: (id)sender;
-(IBAction) speakText: (id)sender;
-(IBAction)	playbackOnceSpokenString: (id)sender;

@end
