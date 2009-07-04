/*
 *  NSURL+NDCarbonUtilities.h category
 *  AppleScriptObjectProject
 *
 *  Created by nathan on Wed Dec 05 2001.
 *  Copyright (c) 2001 __CompanyName__. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

@interface NSURL (NDCarbonUtilities)

+ (NSURL *)URLWithFSRef:(const FSRef *)aFsRef;
- (BOOL)getFSRef:(FSRef *)aFsRef;

- (NSURL *)URLByDeletingLastPathComponent;
- (NSString *)fileSystemPathHFSStyle;
- (NSURL *)resolveAliasFile;

@end
