//
//  MobileMooseAppDelegate.m
//  MobileMoose
//
//  Created by Uli Kusterer on 12.07.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import "MobileMooseViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "UKSound.h"


@implementation MobileMooseViewController

/*
 Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView {
}
 */


- (void)viewDidLoad
{
	[super viewDidLoad];
	
	srand( time( NULL ) );
	
	UIImage*	baseImg = [UIImage imageNamed: @"base.png"];
	[baseImageView setImage: baseImg];
	CGRect		baseBox = [baseImageView frame];
	baseBox.size = [baseImg size];
	
	CGRect	screenBox = [[self view] frame];
	baseBox.origin.x = truncf((screenBox.size.width -baseBox.size.width) / 2.0f );
	baseBox.origin.y = truncf((screenBox.size.height -baseBox.size.height) / 2.0f );
	
	[baseImageView setFrame: baseBox];
	
	UIImage*	eyesImg = [UIImage imageNamed: @"eyes-ahead.png"];
	[eyesImageView setImage: eyesImg];
	CGRect		box = [eyesImageView frame];
	box.size = [eyesImg size];
	box.origin.x = baseBox.origin.x +92;
	box.origin.y = baseBox.origin.y +40;
	[eyesImageView setFrame: box];
	
	UIImage*	mouthImg = [UIImage imageNamed: @"mouth-0.png"];
	[mouthImageView setImage: mouthImg];
	box = [mouthImageView frame];
	box.size = [mouthImg size];
	box.origin.x = baseBox.origin.x +59;
	box.origin.y = baseBox.origin.y +170;
	[mouthImageView setFrame: box];
	
	int			phraseIdx = abs(rand() % 18) +1;
	NSString*	soundFName = [NSString stringWithFormat: @"SpokenString%d",phraseIdx];
	NSString*	phonFName = [NSString stringWithFormat: @"SpokenString%dPhonemes",phraseIdx];
	
	//NSLog(@"speaking phrase %d",phraseIdx);
	
	[phonemes release];
	phonemes = [[NSArray alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: phonFName ofType: @"plist" inDirectory: @"Phrases"]];
	
	// Start playing our recorded speech:
	snd = [[UKSound alloc] initWithContentsOfURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: soundFName ofType: @"m4a" inDirectory: @"Phrases"]]];
	[snd setDelegate: self];
	//NSLog(@"about to play");
	[snd play];
	//NSLog(@"started playing");
	
	// Must be after sound creation, because priming the sound takes a moment:
	speechStartTime = [NSDate timeIntervalSinceReferenceDate];
	currListEntryIdx = 0;
	[NSTimer scheduledTimerWithTimeInterval: 0.1 target: self selector: @selector(spendTime:) userInfo: nil repeats: YES];
	//NSLog(@"timer primed");
}


- (void)dealloc
{
	[phonemes release];
	[snd release];
	
	[super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if( interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown )
	{
		UKSound*	mooSnd = [[UKSound alloc] initWithContentsOfURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"moo" ofType: @"m4a"]]];
		[mooSnd play];
		//[mooSnd autorelease];
	}
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


-(void)	spendTime: (NSTimer*)tim
{
	int numPhonemeEntries = [phonemes count];
	if( !phonemes || currListEntryIdx < 0 || currListEntryIdx >= numPhonemeEntries )
	{
		currListEntryIdx = -1;
		//NSLog(@"Out of phonemes");
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
	
	//NSLog(@"Current phoneme %@",highestMatchDict);
	
	NSString*		mouthName = nil;
	short			phonemeOpcode = [[highestMatchDict objectForKey: @"phonemeOpcode"] intValue];
	NSString*		vMouthFileNames[5] = {	@"mouth-0.png",
											@"mouth-uh.png",
											@"mouth-oo.png",
											@"mouth-mm.png",
											@"mouth-ee.png" };
	switch( phonemeOpcode )
	{
		case 1:		// Breath intake.
		case 2:		// √Ñ
		case 3:		// √Ñi
		case 4:		// √•
		case 5:		// Ah
		case 9:		// ai
		case 11:	// √•
		case 14:	// a
		case 19:	// tch
		case 23:	// g
		case 24:	// h
		case 25:	// dsch
		case 26:	// k
		case 27:	// l
		case 29:	// n
		case 30:	// ng
		case 32:	// r
		case 35:	// t
		case 16:	// au
			mouthName = vMouthFileNames[1];
			break;
		
		
		case 36:	// [th] (hart)
		case 39:	// j
		case 12:	// uh
		case 13:	// u
		case 17:	// oi
		case 15:	// ou
		case 33:	// s
		case 34:	// sch
		case 38:	// uo, ua etc.
		case 40:	// s (stimmhaft)
		case 41:	// sch (weich)
			mouthName = vMouthFileNames[2];
			break;
		
		case 28:	// m
		case 18:	// b
		case 20:	// d
		case 21:	// [th]
		case 22:	// f
		case 31:	// p
		case 37:	// w
			mouthName = vMouthFileNames[3];
			break;
		
		case 6:		// ih
		case 7:		// e
		case 8:		// i
		case 10:	// i mit e-Anklang
			mouthName = vMouthFileNames[4];
			break;
		
		default:
			mouthName = vMouthFileNames[0];
			break;
	}
	
	//NSLog(@"Applying mouth image %@",mouthName);
	[mouthImageView setImage: [UIImage imageNamed: mouthName]];
	
	if( lastBlinkTime == 0 )
	{
		if( abs(rand() % 10) == 4 )
			lastBlinkTime = [NSDate timeIntervalSinceReferenceDate];
	}
	else
	{
		NSTimeInterval	currentAnimTime = [NSDate timeIntervalSinceReferenceDate] -lastBlinkTime;
		float			currAnimFrameFlt = (currentAnimTime * 52.0) / 6.0;
		int				currentAnimationFrame = currAnimFrameFlt;
		
		if( currentAnimationFrame >= 6 )
		{
			lastBlinkTime = 0;
			[eyesImageView setImage: [UIImage imageNamed: @"eyes-ahead.png"]];
		}
		else
		{
			NSString*	eyeImages[6] = { @"eyes-blink1.png", @"eyes-blink2.png",
											@"eyes-blink3.png", @"eyes-blink2.png",
											@"eyes-blink1.png", @"eyes-ahead.png" };
			UIImage*	currEyeImg = [UIImage imageNamed: eyeImages[currentAnimationFrame] ];
			if( [eyesImageView image] != currEyeImg )
			{
				//NSLog(@"Applying blink image %@",eyeImages[currentAnimationFrame]);
				[eyesImageView setImage: currEyeImg];
			}
		}
	}
}


-(void)	sound: (UKSound *)sound didFinishPlaying: (BOOL)aBool
{
	//NSLog(@"finished playing");
	exit(0);
}

@end
