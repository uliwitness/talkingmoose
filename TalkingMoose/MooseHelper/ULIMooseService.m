//
//  MooseService.m
//  MooseService
//
//  Created by Uli Kusterer on 12.01.19.
//  Copyright © 2019 The Void Software. All rights reserved.
//

#import "ULIMooseService.h"

@implementation ULIMooseService

// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
- (void)upperCaseString:(NSString *)aString withReply:(void (^)(NSString *))reply {
    NSString *response = [aString uppercaseString];
	NSLog(@"Service received message: %@ --> %@", aString, response);
    reply(response);
}

@end
