//
//  UKMooseDragAreaView.h
//  TalkingMoose
//
//  Created by Uli Kusterer on 16.08.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UKMooseDragAreaView : NSControl
{
	IBOutlet id			target;
	SEL					action;
	NSCursor*			cursor;
}

-(id)			target;
-(void)			setTarget:(id)anObject;

-(SEL)			action;
-(void)			setAction:(SEL)aSelector;

-(void)			setCursor: (NSCursor*)theCursor;
-(NSCursor*)	cursor;

@end
