//
//  ULIMooseServiceProtocol.h
//  MooseService
//
//  Created by Uli Kusterer on 12.01.19.
//  Copyright © 2019 The Void Software. All rights reserved.
//

/*
	The protocol that the Moose helper will vend as its API.
*/

#import <Foundation/Foundation.h>

@protocol ULIMooseServiceProtocol

-(void)	reloadSettings;

-(void) speakString: (NSString*)currPhrase;

-(void) speakPhraseFromGroup: (NSString*)group withFillerString: (NSString*)fill;

-(void) repeatLastPhrase;

-(void) toggleSilenceMoose;

-(void)	interruptMoose;

@end
