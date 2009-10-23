//
//  SourcesTabBarItem.m
//  Icy
//
//  Created by Slava Karpenko on 4/19/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "SourcesTabBarItem.h"
#import <objc/runtime.h>

@implementation SourcesTabBarItem

@dynamic progressEnabled;

- (BOOL)progressEnabled
{
	return progress != nil;
}

- (void)setProgressEnabled:(BOOL)enabled
{
	if ([self progressEnabled] == enabled)
		return;
	
	if (progress)
	{
		[progress removeFromSuperview];
		progress = nil;
		return;
	}
		
	progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	
	UIView* view = nil;
	if (object_getInstanceVariable(self, "_view", (void**)&view))
	{
		CGRect r = progress.frame;
		
		r.origin.y = 5;
		r.origin.x = view.frame.size.width - r.size.width - 3;
		progress.frame = r;
		[view addSubview:progress];
		[progress startAnimating];
	}

	[progress release];
}

@end
