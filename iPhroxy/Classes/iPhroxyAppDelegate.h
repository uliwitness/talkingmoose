//
//  iPhroxyAppDelegate.h
//  iPhroxy
//
//  Created by Uli Kusterer on 17.11.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iPhroxyViewController;

@interface iPhroxyAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow				*window;
	IBOutlet iPhroxyViewController	*viewController;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) iPhroxyViewController *viewController;

@end

