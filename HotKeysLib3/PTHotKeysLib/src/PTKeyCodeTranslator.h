//
//  PTKeyCodeTranslator.h
//  Chercher
//
//  Created by Finlay Dobbie on Sat Oct 11 2003.
//  Copyright (c) 2003 Cliché Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>

@interface PTKeyCodeTranslator : NSObject
{
    KeyboardLayoutRef	keyboardLayout;
    UCKeyboardLayout	*uchrData;
    void		*KCHRData;
    SInt32		keyLayoutKind;
    UInt32		keyTranslateState;
    UInt32		deadKeyState;
}

+ (id)currentTranslator;

- (id)initWithKeyboardLayout:(KeyboardLayoutRef)aLayout;
- (NSString *)translateKeyCode:(short)keyCode;

- (KeyboardLayoutRef)keyboardLayout;

@end
