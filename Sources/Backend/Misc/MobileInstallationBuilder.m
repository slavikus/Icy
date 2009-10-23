//
//  MobileInstallationBuilder.m
//  Icy
//
//  Created by Slava Karpenko on 3/22/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <notify.h>
#import "MobileInstallationBuilder.h"

#if defined(__i386__)
	#define kIcyMobileInstallationCache @"/Users/slava/Desktop/com.apple.mobile.installation.plist"
#else
	#define kIcyMobileInstallationCache @"/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
#endif

#define kIcyApplicationsPath @"/Applications"

@interface MobileInstallationBuilder (MobileInstallationBuilderPrivate)
- (void)rebuild;
@end


@implementation MobileInstallationBuilder

- init
{
	if (self = [super init])
	{
		[self rebuild];
	}
	
	return self;
}

- (void)rebuild
{
	NSData* data = [NSData dataWithContentsOfMappedFile:kIcyMobileInstallationCache];
	
	if (!data)
		return;
		
	NSMutableDictionary* miCache = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
	if (!miCache)
		return;
	
	NSArray* apps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kIcyApplicationsPath error:nil];
	if (!apps)
		return;
	
	NSMutableDictionary* systemAppsDict = [miCache objectForKey:@"System"];
	NSMutableArray* systemAppsArray = [miCache objectForKey:@"System"];
	
	if (![systemAppsDict isKindOfClass:[NSDictionary class]])
		systemAppsDict = nil;
		
	if (![systemAppsArray isKindOfClass:[NSArray class]])
		systemAppsArray = nil;
		
	[systemAppsDict removeAllObjects];
	[systemAppsArray removeAllObjects];
			
	for (NSString* app in apps)
	{
		NSString* path = [kIcyApplicationsPath stringByAppendingPathComponent:app];
		if ([[path pathExtension] isEqualToString:@"app"])
		{
			NSMutableDictionary* infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
			
			if (infoPlist && [infoPlist objectForKey:@"CFBundleIdentifier"])
			{
				[infoPlist setObject:path forKey:@"Path"];
				[infoPlist setObject:@"System" forKey:@"ApplicationType"];
				
				[systemAppsDict setObject:infoPlist forKey:[infoPlist objectForKey:@"CFBundleIdentifier"]];
				[systemAppsArray addObject:infoPlist];
			}
			
			[infoPlist release];
		}
	}
	
	// Save out
	data = [NSPropertyListSerialization dataFromPropertyList:miCache format:NSPropertyListBinaryFormat_v1_0 errorDescription:nil];
	if (data)
		[data writeToFile:kIcyMobileInstallationCache options:NSAtomicWrite error:nil];
		
	notify_post("com.apple.mobile.application_installed");
}

@end
