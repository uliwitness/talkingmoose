//
//  MobileMooseViewController.h
//  MobileMoose
//
//  Created by Uli Kusterer on 12.07.08.
//  Copyright The Void Software 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UKSound.h"


@interface MobileMooseViewController : UIViewController <UKSoundDelegate>
{
	IBOutlet UIImageView*		mouthImageView;
	IBOutlet UIImageView*		baseImageView;
	IBOutlet UIImageView*		eyesImageView;
	NSArray*					phonemes;
	UKSound*					snd;
	NSTimeInterval				speechStartTime;
	int							currListEntryIdx;
	NSTimeInterval				lastBlinkTime;
}

@end

