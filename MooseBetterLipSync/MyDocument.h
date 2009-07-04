//
//  MyDocument.h
//  MooseBetterLipSync
//
//  Created by Uli Kusterer on 04.11.07.
//  Copyright The Void Software 2007 . All rights reserved.
//


#import <Cocoa/Cocoa.h>


@class UKLipSyncDrawingView;
@class UKMouthShape;
@class UKSharedObjectPot;


@interface MyDocument : NSDocument
{
	IBOutlet UKLipSyncDrawingView*	lipView;
	IBOutlet NSPopUpButton*			prevShapePopup;
	IBOutlet NSSlider*				percentOfOtherSlider;
	IBOutlet NSButton*				onlyDrawMergedSwitch;
	UKMouthShape*					shape;
}

-(IBAction)	userChosePreviousShape: (id)sender;
-(IBAction)	selectBackgroundImage: (id)sender;

-(IBAction)	percentOfOtherSliderChanged: (id)sender;
-(IBAction)	onlyDrawMergedSwitchChanged: (id)sender;

-(void)	sharedObjectPotChanged: (UKSharedObjectPot*)thePot session: (NSUInteger)sessionNum;

@end
