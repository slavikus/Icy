//
//  NSNumber+RipdevExtensions.m
//  Icy
//
//  Created by Slava Karpenko on 3/10/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "NSNumber+RipdevExtensions.h"


@implementation NSNumber (RipdevExtensions)

- (NSString *)byteSizeDescription {
	double dBytes = [self doubleValue];

	if(dBytes == 0) {
		return @"0 bytes";
	} else if(dBytes <= pow(2, 10)) {
		return [NSString stringWithFormat:@"%0.0f bytes", dBytes];
	} else if(dBytes <= pow(2, 20)) {
		return [NSString stringWithFormat:@"%0.1f KB", dBytes / pow(1024, 1)];
	} else if(dBytes <= pow(2, 30)) {
		return [NSString stringWithFormat:@"%0.1f MB", dBytes / pow(1024, 2)];
	} else if(dBytes <= pow(2, 40)) {
		return [NSString stringWithFormat:@"%0.1f GB", dBytes / pow(1024, 3)];
	} else {
		return [NSString stringWithFormat:@"%0.1f TB", dBytes / pow(1024, 4)];
	}
}

@end
