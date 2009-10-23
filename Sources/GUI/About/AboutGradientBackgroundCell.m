//
//  AboutGradientBackgroundCell.m
//  Icy
//
//  Created by Slava Karpenko on 3/26/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "AboutGradientBackgroundCell.h"


@implementation AboutGradientBackgroundCell

- (id)initWithCoder:(NSCoder*)coder
{
    if (self = [super initWithCoder:coder]) {
        [self _commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier])
	{
		[self _commonInit];
	}
	
	return self;
}

- (void)_commonInit
{
	NSString* imageName = @"GradientBackground";
	
	if (self.frame.size.height > 80)
		imageName = @"GradientBackgroundLarge";
		
	UIImage* gradient = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:imageName ofType:@"png"]]];

	self.contentView.backgroundColor = [UIColor colorWithPatternImage:gradient];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)dealloc {
    [super dealloc];
}


@end
