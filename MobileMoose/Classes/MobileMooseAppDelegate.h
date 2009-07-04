//
//  MobileMooseAppDelegate.h
//  MobileMoose
//
//  Created by Uli Kusterer on 12.07.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MobileMooseViewController;

@interface MobileMooseAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow *window;
	IBOutlet MobileMooseViewController *viewController;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) MobileMooseViewController *viewController;

@end

