/*
 *  NDResourceFork.h
 *  AppleScriptObjectProject
 *
 *  Created by nathan on Wed Dec 05 2001.
 *  Copyright (c) 2001 Nathan Day. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

@interface NDResourceFork : NSObject
{
	short		fileReference;
}

+ (id)resourceForkForReadingAtURL:(NSURL *)aURL;
+ (id)resourceForkForWritingAtURL:(NSURL *)aURL;
+ (id)resourceForkForReadingAtPath:(NSString *)aPath;
+ (id)resourceForkForWritingAtPath:(NSString *)aPath;

- (id)initForReadingAtURL:(NSURL *)aURL;
- (id)initForWritingAtURL:(NSURL *)aURL;
- (id)initForReadingAtPath:(NSString *)aPath;
- (id)initForWritingAtPath:(NSString *)aPath;
- (id)initForPermission:(char)aPermission AtURL:(NSURL *)aURL;
- (id)initForPermission:(char)aPermission AtPath:(NSString *)aPath;

- (BOOL)addData:(NSData *)aData type:(ResType)aType Id:(short)anID name:(NSString *)aName;
- (NSData *)dataForType:(ResType)aType Id:(short)anID;

/*
 * string methods handle converting between an NSString and a pascal string
 * as stored in a resource fork
 */
- (BOOL)addString:(NSString *)aString type:(ResType)aType Id:(short)anID name:(NSString *)aName;
- (NSString *)stringForType:(ResType)aType Id:(short)anID;

- (BOOL)removeType:(ResType)aType Id:(short)anID;

@end

BOOL	NSStringToStr255( NSString* strobj, StringPtr outStr );
