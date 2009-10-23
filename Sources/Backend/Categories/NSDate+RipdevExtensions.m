//
//  NSDate+RipdevExtensions.m
//  Icy
//
//  Created by Slava Karpenko on 4/1/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "NSDate+RipdevExtensions.h"


@implementation NSDate (RipdevExtensions)

- (NSString*)relativeDateString
{
	// find midnight of today
	NSDateFormatter *mdf = [[NSDateFormatter alloc] init];
	
	[mdf setDateFormat:@"yyyy-MM-dd"];
	NSDate *midnight = [mdf dateFromString:[mdf stringFromDate:[NSDate date]]];
	
	[mdf release];

	NSUInteger midnightInterval = [midnight timeIntervalSinceReferenceDate];
	NSUInteger thisInterval = [self timeIntervalSinceReferenceDate];
	NSUInteger nowInterval = [[NSDate date] timeIntervalSinceReferenceDate];
	
	if (thisInterval >= midnightInterval)		// today, let's go for finer granularity!
	{
		NSUInteger hours = (nowInterval - thisInterval) / (60*60);
		NSUInteger minutes = (((nowInterval - thisInterval) / 60) % 60);
		
		if (hours)
		{
			return [NSString stringWithFormat:hours > 1 ? NSLocalizedString(@"%d Hours Ago", @"") : NSLocalizedString(@"%d Hour Ago", @""), hours];
		}
		
		return [NSString stringWithFormat:minutes > 1 ? NSLocalizedString(@"%d Minutes Ago", @"") : NSLocalizedString(@"%d Minute Ago", @""), minutes];
	}
	
	if (thisInterval >= (midnightInterval - (24*60*60)))
	{
		return NSLocalizedString(@"Yesterday", @"");
	}
	else if (thisInterval >= (midnightInterval - (2*24*60*60)))
	{
		return NSLocalizedString(@"Two Days Ago", @"");
	}
	
	NSUInteger days = (nowInterval - thisInterval) / (24*60*60);
	
	return [NSString stringWithFormat:NSLocalizedString(@"%d Days Ago", @""), days];
}

@end
