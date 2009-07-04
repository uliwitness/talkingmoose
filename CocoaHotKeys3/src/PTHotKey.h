//
//  PTHotKey.h
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PTKeyCombo.h"

@interface PTHotKey : NSObject
{
	NSString*		mName;
	PTKeyCombo*		mKeyCombo;
	id				mTarget;
	SEL				mAction;
}

- (id)init;
- (id)initWithName: (NSString*)nm;				// UK 2004-04-15
- (id)initWithName: (NSString*)nm target: (id)tg action: (SEL)ac addToCenter: (BOOL)n; // UK 2004-04-15

- (void)setName: (NSString*)name;
- (NSString*)name;

- (void)setKeyCombo: (PTKeyCombo*)combo;
- (PTKeyCombo*)keyCombo;

- (void)setTarget: (id)target;
- (id)target;
- (void)setAction: (SEL)action;
- (SEL)action;

- (NSString*)stringValue;						// UK 2004-04-15

- (void)writeToStandardDefaults;				// UK 2004-04-15
- (void)writeToDefaults: (NSUserDefaults*)ud;	// UK 2004-04-15

- (void)readFromStandardDefaults;				// UK 2004-04-15
- (void)readFromDefaults: (NSUserDefaults*)ud;	// UK 2004-04-15

- (void)invoke;

@end
