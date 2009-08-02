//
//  iPhroxyViewController.h
//  iPhroxy
//
//  Created by Uli Kusterer on 17.11.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface iPhroxyViewController : UIViewController
{
	IBOutlet UILabel				*portNumField;
	NSFileHandle					*fileHandle;
}

@property (retain) UILabel*			portNumField;
@property (retain) NSFileHandle*	fileHandle;

-(void)	startProxyServer;

@end

