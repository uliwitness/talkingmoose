//
//  MooseView.m
//  MobileMoose
//
//  Created by Uli Kusterer on 12.07.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "MooseView.h"


@implementation MooseView


- (id)initWithCoder:(NSCoder*)coder
{
	if (self = [super initWithCoder: coder])
	{
		
	}
	return self;
}


-(void)	dealloc
{
	[super dealloc];
}


- (void)drawRect:(CGRect)rect
{
	[[UIColor whiteColor] set];
	UIRectFill( [self bounds] );
}

@end
