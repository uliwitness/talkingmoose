//
//  UKSplotchChatterbot.h
//  CocoaMoose
//
//  Created by Uli Kusterer on Sun Aug 08 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>


@class UKSplotchChatterbot;


@protocol UKSplotchChatterbotDelegate

-(void)			splotchChatterbot: (UKSplotchChatterbot*)sender gaveAnswer: (NSString*)theAnswer;
-(NSString*)	randomPhraseForSplotchChatterbot: (UKSplotchChatterbot*)sender;

@end



@interface UKSplotchChatterbot : NSObject
{
	IBOutlet NSTextField*						answerField;
	NSArray*									mainDictionary;		// "Dictionary" in the linguistic sense, it's actually an array.
	NSMutableDictionary*						words;
	IBOutlet id<UKSplotchChatterbotDelegate>	delegate;
}

-(NSString*)		getReplyForQuestion: (NSString*) question byPerson: (NSString*) person;
-(NSString*)		expandQuestion: (NSString*)s;
-(NSDictionary*)	matchLineToTemplate: (NSString*)msg;

-(void)				takeStringValueFrom: (id)sender;

@end


