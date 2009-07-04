//
//  TestAppController.h
//  PTHotKeysTester
//
//  Created by Quentin Carnicelli on Wed Jul 14 2004.
//  Copyright (c) 2004 Quentin D. Carnicelli. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PTHotKey;

@interface TestAppController : NSObject
{
	IBOutlet NSTextField*	mHotKeyDescriptionField;
	IBOutlet NSTextField*	mResultsField;
	
	PTHotKey*				mHotKey;
}

- (IBAction)hitSetHotKey: (id)sender;

@end
