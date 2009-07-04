//
//  UKDisableSpeechCommand.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 14.01.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

#import "UKDisableSpeechCommand.h"
#import "UKMooseAppDelegate.h"


@implementation UKDisableSpeechCommand

-(id)   performDefaultImplementation
{
    [(UKMooseAppDelegate*)[NSApp delegate] setMooseSilenced: YES];
    
    return nil;
}

@end
