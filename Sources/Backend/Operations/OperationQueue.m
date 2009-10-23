//
//  OperationQueue.m
//  Installer
//
//  Created by Slava Karpenko on 3/13/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "OperationQueue.h"

static OperationQueue* sOperationQueue;

@implementation OperationQueue
+ (OperationQueue*)sharedQueue
{
	if (!sOperationQueue)
	{
		sOperationQueue = [[OperationQueue alloc] init];
//#if !defined(__i386__)
		[sOperationQueue setMaxConcurrentOperationCount:4];
//#endif
	}
	
	return sOperationQueue;
}

@end
