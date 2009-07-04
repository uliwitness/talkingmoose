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
	NSString*		mIdentifier;
	NSString*		mName;
	PTKeyCombo*		mKeyCombo;
	id				mTarget;
	SEL				mAction;
}

- (id)initWithIdentifier: (id)identifier keyCombo: (PTKeyCombo*)combo;
- (id)init;
- (id)initWithName: (NSString*)nm;				// UK 2004-04-15
- (id)initWithName: (NSString*)nm target: (id)tg action: (SEL)ac addToCenter: (BOOL)n; // UK 2004-04-15

- (void)setIdentifier: (id)ident;
- (id)identifier;

- (void)setName: (NSString*)name;
- (NSString*)name;

- (void)setKeyCombo: (PTKeyCombo*)combo;
- (PTKeyCombo*)keyCombo;

- (void)setTarget: (id)target;
- (id)target;
- (void)setAction: (SEL)action;
- (SEL)action;

- (void)invoke;

- (NSString*)stringValue;						// UK 2004-04-15

- (void)writeToStandardDefaults;				// UK 2004-04-15
- (void)writeToDefaults: (NSUserDefaults*)ud;	// UK 2004-04-15

- (void)readFromStandardDefaults;				// UK 2004-04-15
- (void)readFromDefaults: (NSUserDefaults*)ud;	// UK 2004-04-15

@end
