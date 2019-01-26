//
//  UKSpeakRandomPhraseCommand.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 14.01.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

#import "UKSpeakRandomPhraseCommand.h"
#import "UKMooseAppDelegate.h"


@implementation UKSpeakRandomPhraseCommand

-(id)   performDefaultImplementation
{
	NSString*	fill = [[self evaluatedArguments] objectForKey: @"filler"];
    NSString*   cat = [[[self evaluatedArguments] objectForKey: @"category"] uppercaseString];
    if( !cat )
        cat = @"PAUSE";
    [(UKMooseAppDelegate*)[NSApp delegate] speakPhraseFromGroup: cat withFillerString: fill];
    
    return nil;
}

@end
