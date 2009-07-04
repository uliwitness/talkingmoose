//
//  UKEnableSpeechCommand.m
//  TalkingMoose
//
//  Created by Uli Kusterer on 14.01.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

#import "UKEnableSpeechCommand.h"
#import "UKMooseAppDelegate.h"


@implementation UKEnableSpeechCommand

-(id)   performDefaultImplementation
{
    [(UKMooseAppDelegate*)[NSApp delegate] setMooseSilenced: NO];
    
    return nil;
}

@end
