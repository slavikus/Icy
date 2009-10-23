//
//  UpdatesSearchOperation.m
//  Icy
//
//  Created by Slava Karpenko on 3/23/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "UpdatesSearchOperation.h"
#import "Database.h"
#import "DPKGParser.h"
#import "NSString+RipdevVersionCompare.h"

@implementation UpdatesSearchOperation

- (void)main
{
	NSMutableArray* updatedPackages = [NSMutableArray arrayWithCapacity:0];
	
	// Search for updates, doh.
	DPKGParser* parser = [[DPKGParser alloc] init];
	NSArray* installedPackages = [parser parseDatabaseAtPath:kIcyDPKGStatusDatabasePath];
	[parser release];
	
	if (!installedPackages)
	{
		return;
	}
	
	NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
	mDB = [Database database];
	for (NSDictionary* pack in installedPackages)
	{
		[self _checkUpdate:pack withArray:updatedPackages];
	}
	[innerPool release];
	
	NSNotification* notification = [NSNotification notificationWithName:kIcyUpdatedPackagesUpdatedNotification object:updatedPackages userInfo:nil];
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
}

- (void)_checkUpdate:(NSDictionary*)pack withArray:(NSMutableArray*)updatedPackages
{
	NSString* installedPackageID = [pack objectForKey:@"package"];
	NSString* installedPackageVersion = [pack objectForKey:@"version"];
	
	NSDictionary* dbPack = [self _findPackage:installedPackageID];
	
	if (dbPack)
	{
		NSString* dbPackageVersion = [dbPack objectForKey:@"version"];
		
		if (dbPackageVersion && installedPackageVersion &&
			[dbPackageVersion compareWithVersion:installedPackageVersion operation:@"gt"])
		{
			[updatedPackages addObject:dbPack];
		}
		
	}
}

- (NSDictionary*)_findPackage:(NSString*)packageID
{
	NSMutableDictionary* result = nil;
	
	if (!packageID || ![packageID length])
		return nil;
	
	ResultSet* rs = [mDB executeQuery:@"SELECT tag,data FROM meta WHERE identifier = ?", packageID];
	while (rs && [rs next])
	{
		if (!result)
			result = [NSMutableDictionary dictionaryWithCapacity:0];
		
		[result setObject:[rs stringForColumn:@"data"] forKey:[rs stringForColumn:@"tag"]];
	}
	
	[rs close];
	
	return result;
}

@end
