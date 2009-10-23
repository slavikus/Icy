//
//  NSURLRequest+RipdevExtensions.m
//  Icy
//
//  Created by Slava Karpenko on 3/30/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <sys/sysctl.h>
#import "NSURLRequest+RipdevExtensions.h"

static char			gMachineName[128] = { 0 };

@implementation NSURLRequest (RipdevExtensions)

+ (NSURLRequest*)requestWithCydiaURL:(NSURL*)url
{
	NSMutableURLRequest* req = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];

	// machine name
	if (!gMachineName[0])
	{
		size_t size = sizeof(gMachineName);
		sysctlbyname("hw.machine", gMachineName, &size, NULL, 0);
	}
	
	if (gMachineName[0])
		[req setValue:[NSString stringWithUTF8String:gMachineName] forHTTPHeaderField:@"X-Machine"];
	
	[req setValue:[UIDevice currentDevice].uniqueIdentifier forHTTPHeaderField:@"X-Unique-ID"];
	
	[req setValue:[UIDevice currentDevice].systemVersion forHTTPHeaderField:@"X-Firmware"];

	// we may want to add User-Agent here as well, later

	return req;
}

@end
