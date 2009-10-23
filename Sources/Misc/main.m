//
//  main.m
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright Ripdev 2009. All rights reserved.
//

#include <dlfcn.h>
#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import "SchemaBuilder.h"

int main(int argc, char *argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (access("/Applications/WinterBoard.app/WinterBoard.dylib", (R_OK|X_OK)) == 0)
        dlopen("/Applications/WinterBoard.app/WinterBoard.dylib", RTLD_LAZY | RTLD_GLOBAL);

	// Create folders
	if (![[NSFileManager defaultManager] fileExistsAtPath:kIcyCachePath] || ![[NSFileManager defaultManager] fileExistsAtPath:kIcyIndexesPath])
	{
		NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"mobile", NSFileOwnerAccountName, @"mobile", NSFileGroupOwnerAccountName, nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:kIcyCachePath withIntermediateDirectories:YES attributes:attrs error:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:kIcyIndexesPath withIntermediateDirectories:YES attributes:attrs error:nil];
	}
	
	// build schema
	//sqlite3_enable_shared_cache(1);
	[[[SchemaBuilder alloc] init] release];

    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}

