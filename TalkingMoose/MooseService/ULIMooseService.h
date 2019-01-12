//
//  MooseService.h
//  MooseService
//
//  Created by Uli Kusterer on 12.01.19.
//  Copyright © 2019 The Void Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ULIMooseServiceProtocol.h"

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface ULIMooseService : NSObject <ULIMooseServiceProtocol>
@end
