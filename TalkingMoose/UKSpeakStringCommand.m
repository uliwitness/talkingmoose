//
//  UKSpeakStringCommand.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 14.01.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

#import "UKSpeakStringCommand.h"
#import "UKMooseAppDelegate.h"


@implementation UKSpeakStringCommand

-(id)   performDefaultImplementation
{
	NSString*	theString = [[[self evaluatedArguments] objectForKey: @""] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if( [theString length] > 0 )
		[(UKMooseAppDelegate*)[NSApp delegate] speakString: theString];
    
    return nil;
}

@end
