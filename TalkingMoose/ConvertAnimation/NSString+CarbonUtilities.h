/*
 *  NSString+CarbonUtilities.h category
 *
 *  Created by Nathan Day on Sat Aug 03 2002.
 *  Copyright (c) 2002 Nathan Day. All rights reserved.\
 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@interface NSString (CarbonUtilities)

+ (NSString *)stringWithFSRef:(const FSRef *)aFSRef;
- (BOOL)getFSRef:(FSRef *)aFSRef;

- (NSString *)resolveAliasFile;

@end
