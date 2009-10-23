//
//  DEBInstallOperation.m
//  Icy
//
//  Created by Slava Karpenko on 3/20/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <sys/stat.h>
#import "DEBInstallOperation.h"
#import "InstallRemoveController.h"
#import "DPKGParser.h"
#import "NSString+RipdevVersionCompare.h"
#import "Database.h"
#import "URLDownload.h"
#import "DPKGInvocation.h"
#import "MobileInstallationBuilder.h"
#import "UpdatesSearchOperation.h"
#import "OperationQueue.h"

#define  DEBInstallOperationErrorDomain @"com.ripdev.icy.deb-install"
enum {
	kDEBErrorUnknownPackage = 1,
	kDEBErrorInstallFailed,
	kDEBErrorConflictFound
};

extern SystemSoundID gDoneSoundID;

@implementation DEBInstallOperation

- initWithPackageID:(NSString*)packageID installUninstallController:(InstallRemoveController*)iuController
{
	return [self initWithPackageIDs:[NSArray arrayWithObject:packageID] installUninstallController:iuController];
}

- initWithPackageIDs:(NSArray*)packageIDs installUninstallController:(InstallRemoveController*)iuController
{
	if (self = [super init])
	{
		mPackageIDs = [packageIDs retain];
		mController = iuController;
	}
	
	return self;
}

- (void)dealloc
{
	[mPackageList release];
	[mPackageIDs release];
	[mInstalledPackages release];
	[mProcessedPackages release];
	[super dealloc];
}

#pragma mark -

- (void)main
{
	// Perform sanity checks for apt-key and make a dummy script if it is not found
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/apt-key"])
	{
		NSString* aptKeyScript = @"#!/bin/bash\n\n\n";
		
		[aptKeyScript writeToFile:@"/usr/bin/apt-key" atomically:NO encoding:NSUTF8StringEncoding error:nil];
		chmod("/usr/bin/apt-key", 0755);
	}
	
	//NSLog(@"Package install started for %@", mPackageIDs);
	mPackageList = [[NSMutableArray alloc] initWithCapacity:0];
	mProcessedPackages = [[NSMutableArray alloc] initWithCapacity:0];

	DPKGParser* parser = [[DPKGParser alloc] init];
	mInstalledPackages = [[parser parseDatabaseAtPath:kIcyDPKGStatusDatabasePath] retain];
	[parser release];
		
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Analyzing dependencies...", @"") waitUntilDone:YES];

	for (NSString* packageID in mPackageIDs)
	{
		if (![self _queuePackage:packageID])
		{
			NSLog(@"ERROR for package: %@", packageID);
			
			if ([self isCancelled])
			{
				[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Cancelled.", @"") waitUntilDone:YES];
				sleep(2);
				[mController performSelectorOnMainThread:@selector(doReturn:) withObject:nil waitUntilDone:NO];
			}
			
			return;
		}
	}
	
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:nil waitUntilDone:YES];
	[mController performSelectorOnMainThread:@selector(advancePhase) withObject:nil waitUntilDone:YES];
	
	//NSLog(@"Packages to install:\n%@", mPackageList);
	
	[self performSelectorOnMainThread:@selector(tellControllerShowProgressBar:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:YES];
	if ([mPackageList count] > 1)
		[self performSelectorOnMainThread:@selector(tellControllerShowProgressBar2:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:YES];
	
	// Download all the packages. Let's build the url list
	NSUInteger i = 0;
	for (NSMutableDictionary* package in mPackageList)
	{
		NSURL* url = [package objectForKey:@"url"];
		
		mDownloadError = NO;
		[self performSelectorOnMainThread:@selector(tellControllerUpdateProgress:) withObject:[NSNumber numberWithFloat:.0] waitUntilDone:NO];
		
		//NSLog(@"Downloading %@", [url absoluteString]);
		
		[mController performSelectorOnMainThread:@selector(setLabel:) withObject:[[url path] lastPathComponent] waitUntilDone:YES];
		
		i++;
		float pos = ((float)i / (float)[mPackageList count]);
		[self performSelectorOnMainThread:@selector(tellControllerUpdateProgress2:) withObject:[NSNumber numberWithFloat:pos] waitUntilDone:YES];
		
		mFileSize = [[package objectForKey:@"size"] intValue];
		mDownloadedBytes = 0;
		
		URLDownload* dl = [[URLDownload alloc] initWithURL:url delegate:self];
		
		[dl start];
		[package setObject:dl.downloadFilePath forKey:@"_dl"];
		[dl release];
		
		if (mDownloadError)
			break;
			
		if ([self isCancelled])
		{
			[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Cancelled.", @"") waitUntilDone:YES];
			sleep(2);
			[mController performSelectorOnMainThread:@selector(doReturn:) withObject:nil waitUntilDone:NO];
			
			return;
		}
	}
	
	if (mDownloadError)
		return;

	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(tellControllerShowProgressBar2:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
	if ([mPackageList count] <= 1)
		[self performSelectorOnMainThread:@selector(tellControllerShowProgressBar:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
	
	if (!mDownloadError)
	{
		[mController performSelectorOnMainThread:@selector(advancePhase) withObject:nil waitUntilDone:YES];

		// Install
		[self performSelectorOnMainThread:@selector(tellControllerUpdateProgress:) withObject:[NSNumber numberWithFloat:.0] waitUntilDone:NO];
		
		BOOL installError = NO;
		
		i = 0;
		for (NSMutableDictionary* package in mPackageList)
		{
			i++;
			float pos = ((float)i / (float)[mPackageList count]);
			[self performSelectorOnMainThread:@selector(tellControllerUpdateProgress:) withObject:[NSNumber numberWithFloat:pos] waitUntilDone:YES];
			
			if (![self _install:package])
			{
				installError = YES;
				break;
			}
		}
		
		// Hide progress bar 1
		[self performSelectorOnMainThread:@selector(tellControllerShowProgressBar:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
	
		if (installError)
			return;
			
		// Clean up
		[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Cleaning up...", @"") waitUntilDone:YES];
		[mController performSelectorOnMainThread:@selector(advancePhase) withObject:nil waitUntilDone:YES];
		
		for (NSMutableDictionary* package in mPackageList)
		{
			NSString* path = [package objectForKey:@"_dl"];
			if (path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		}
	}
	
	[[[MobileInstallationBuilder alloc] init] release];
	
	UpdatesSearchOperation* us = [[UpdatesSearchOperation alloc] init];
	[[OperationQueue sharedQueue] performSelectorOnMainThread:@selector(addOperation:) withObject:us waitUntilDone:YES];
	[us release];

	sleep(1);
	
	if (!gDoneSoundID)
	{
		NSString* soundPath = [[NSBundle mainBundle] pathForResource:@"Done" ofType:@"caf"];
		if (soundPath)
		{
			NSURL* afUrl = [NSURL fileURLWithPath:soundPath];
			AudioServicesCreateSystemSoundID((CFURLRef)afUrl, &gDoneSoundID);
		}
	}

	if (gDoneSoundID)
		AudioServicesPlaySystemSound(gDoneSoundID);
	
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Done", @"") waitUntilDone:YES];
	[mController performSelectorOnMainThread:@selector(doReturn:) withObject:nil waitUntilDone:NO];
}

- (void)tellControllerShowProgressBar:(NSNumber*)show
{
	[mController showProgressBar:[show boolValue]];
}

- (void)tellControllerUpdateProgress:(NSNumber*)progress
{
	[mController setProgress:[progress floatValue]];
}

- (void)tellControllerShowProgressBar2:(NSNumber*)show
{
	[mController showProgressBar2:[show boolValue]];
}

- (void)tellControllerUpdateProgress2:(NSNumber*)progress
{
	[mController setProgress2:[progress floatValue]];
}

- (BOOL)_queuePackage:(NSString*)packageID
{
	// check if this package is already queued
	if ([mProcessedPackages containsObject:packageID])
	{
		//NSLog(@"Package %@ is already processed, skipping...", packageID);
		return YES;
	}
	
	[mProcessedPackages addObject:packageID];
	
	if ([self _findInArray:mPackageList packageID:packageID])
	{
		//NSLog(@"Package %@ is already queued, skipping...", packageID);
		return YES;
	}
	
	// fetch the package from the database
	NSDictionary* package = [self _findPackage:packageID];

	// check whether this package is already installed
	NSDictionary* installedPackage = [self _findInArray:mInstalledPackages packageID:packageID];
	if (installedPackage)
	{
		// check versions
		NSString* installedVersion = [installedPackage objectForKey:@"version"];
		NSString* currentVersion = [package objectForKey:@"version"];
		
		if (installedVersion)
		{
			if (!currentVersion)
			{
				return YES;				// already have it installed, so why bother
			}
			
			if ([currentVersion compareWithVersion:installedVersion operation:@"le"])
			{
				// no need to queue it
				return YES;
			}
		}
	}

	if (!package)
	{
		NSDictionary* userErr = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" was not found.", @""), packageID], NSLocalizedDescriptionKey, packageID, @"packageID", nil];
		NSError* error = [NSError errorWithDomain:DEBInstallOperationErrorDomain code:kDEBErrorUnknownPackage userInfo:userErr];
		
		[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
		return NO;
	}
	
	if ([self isCancelled])
		return NO;
		
	// check conflicts
	if ([package objectForKey:@"conflicts"])
	{
		DPKGParser* p = [[DPKGParser alloc] init];
		NSArray* conflicts = [p dependencyFromString:[package objectForKey:@"conflicts"] full:YES];
		[p release];
		
		for (NSDictionary* conf in conflicts)
		{
			if ([self _checkConflict:conf])
			{
				// error
				NSDictionary* userErr = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" cannot be installed as there is a conflict with another installed package, \"%@\". Please uninstall it first.", @""), packageID, [conf objectForKey:@"package"]], NSLocalizedDescriptionKey, packageID, @"packageID", nil];
				NSError* error = [NSError errorWithDomain:DEBInstallOperationErrorDomain code:kDEBErrorConflictFound userInfo:userErr];
				
				[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
				
				return NO;
			}
		}
	}
	
	// check cross-conflicts
	DPKGParser* p = [[DPKGParser alloc] init];
	for (NSDictionary* ipack in mInstalledPackages)
	{
		if ([ipack objectForKey:@"conflicts"])
		{
			NSArray* conflicts = [p dependencyFromString:[ipack objectForKey:@"conflicts"] full:YES];
			
			for (NSDictionary* conf in conflicts)
			{
				BOOL hasConflict = NO;
				
				if ([[conf objectForKey:@"package"] isEqualToString:packageID])
				{
					if ([conf objectForKey:@"version"])
					{
						// parse version comparison directive
						NSString* versionString = [conf objectForKey:@"version"];
						NSString* installedVersion = [package objectForKey:@"version"];
						
						// decypher versionString
						NSRange actualVersionRange = [versionString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" 1234567890"]];
						if (actualVersionRange.length)
						{
							NSString* actualVersion = [[versionString substringFromIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							NSString* compareOperation = [[versionString substringToIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							
							hasConflict = [installedVersion compareWithVersion:actualVersion operation:compareOperation];
						}
					}
					else
						hasConflict = YES;
				}

				if (hasConflict)
				{
					// error
					NSDictionary* userErr = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" cannot be installed as there is a conflict with another installed package, \"%@\". Please uninstall it first.", @""), packageID, [ipack objectForKey:@"package"]], NSLocalizedDescriptionKey, packageID, @"packageID", nil];
					NSError* error = [NSError errorWithDomain:DEBInstallOperationErrorDomain code:kDEBErrorConflictFound userInfo:userErr];
					
					[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
					
					return NO;
				}
			}
		}
	}
	[p release];
	
	// determine dependencies
	// queue dependencies will throw an error, we just abort the queue
	if (![self _queueDependencies:package forKey:@"pre-depends"])
		return NO;
		
	if (![self _queueDependencies:package forKey:@"depends"])
		return NO;
		
	// Now dependencies are queued, so let's queue our package
	if (![self _findInArray:mPackageList packageID:packageID])
	{
		[mPackageList addObject:package];
	}
	
	return YES;
}

- (BOOL)_checkConflict:(NSDictionary*)conf
{
	NSDictionary* installedPackage = [self _findInArray:mInstalledPackages packageID:[conf objectForKey:@"package"]];
	if (installedPackage)
	{
		if ([conf objectForKey:@"version"])
		{
			// parse version comparison directive
			NSString* versionString = [conf objectForKey:@"version"];
			NSString* installedVersion = [installedPackage objectForKey:@"version"];
			
			// decypher versionString
			NSRange actualVersionRange = [versionString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" 1234567890"]];
			if (actualVersionRange.length)
			{
				NSString* actualVersion = [[versionString substringFromIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				NSString* compareOperation = [[versionString substringToIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				
				return [installedVersion compareWithVersion:actualVersion operation:compareOperation];
			}
		}
		
		return YES;
	}
	
	return NO;
}

- (BOOL)_queueDependencies:(NSDictionary*)package forKey:(NSString*)key
{
	NSString* depends = [package objectForKey:key];
		
	if (!depends)				// no dependencies
		return YES;
		
	DPKGParser* p = [[DPKGParser alloc] init];
	NSArray* deps = [p dependencyFromString:depends full:YES];
	[p release];

	if (deps)
	{
		for (NSDictionary* dep in deps)
		{
			// check versions and stuff
			NSString* depID = [dep objectForKey:@"package"];
			NSString* dependsVersionReq = nil;
			NSString* dependsVersionReqOp = nil;
			
			NSDictionary* installedDep = [self _findInArray:mInstalledPackages packageID:depID];
			// if we already have this installed, let's check whether the version matches
			
			if ([dep objectForKey:@"version"])
			{
				// parse version comparison directive
				NSString* versionString = [dep objectForKey:@"version"];
				
				// decypher versionString
				NSRange actualVersionRange = [versionString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" 1234567890"]];
				if (actualVersionRange.length)
				{
					dependsVersionReq = [[versionString substringFromIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					dependsVersionReqOp = [[versionString substringToIndex:actualVersionRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				}
			}
			
			BOOL reqFulfilled = NO;
			
			// If we already have this package installed, let's see if the version requirement matches
			if (installedDep)
			{
				if (dependsVersionReq)
					reqFulfilled = [[installedDep objectForKey:@"version"] compareWithVersion:dependsVersionReq operation:dependsVersionReqOp];
				else
					reqFulfilled = YES;
			}
			
			if (!reqFulfilled)
			{
				// check in the database
				NSDictionary* depDict = [self _findPackage:depID];
				
				if (dependsVersionReq)
				{
					if (!depDict || ![[depDict objectForKey:@"version"] compareWithVersion:dependsVersionReq operation:dependsVersionReqOp])
					{
						NSDictionary* userErr = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" was not found.", @""), [NSString stringWithFormat:@"%@ (%@ %@)", depID, dependsVersionReqOp, dependsVersionReq]] forKey:NSLocalizedDescriptionKey];
						NSError* error = [NSError errorWithDomain:DEBInstallOperationErrorDomain code:kDEBErrorUnknownPackage userInfo:userErr];
						
						[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
						return NO;
					}
				}
			}

			if (![self _queuePackage:depID])
			{
				return NO;
			}
		}
	}
	
	return YES;
}

- (NSDictionary*)_findPackage:(NSString*)packageID
{
	NSMutableDictionary* result = nil;
	
	Database* db = [Database database];
	ResultSet* rs = [db executeQuery:@"SELECT tag,data FROM meta WHERE identifier = ?", packageID];
	while (rs && [rs next])
	{
		if (!result)
		{
			result = [NSMutableDictionary dictionaryWithCapacity:0];
		}
		
		[result setObject:[rs stringForColumn:@"data"] forKey:[rs stringForColumn:@"tag"]];
	}
	
	[rs close];
	
	// Fetch the package URL
	rs = [db executeQuery:@"SELECT sources.url AS url FROM sources,packages WHERE sources.RowID = packages.source AND packages.identifier = ?", packageID];
	if (rs && [rs next])
	{
		NSURL* baseURL = nil;
		
		if ([rs stringForColumn:@"url"])
			baseURL = [NSURL URLWithString:[rs stringForColumn:@"url"]];
		
		NSURL* url = nil;
		
		if (baseURL && [result objectForKey:@"filename"])
		{
			// fix up url so it's relative to the repo
			NSString* filename = [result objectForKey:@"filename"];
			if ([filename hasPrefix:@"/"] && [filename length] > 1)
				filename = [filename substringFromIndex:1];
				
			url = [NSURL URLWithString:filename relativeToURL:baseURL];
		}
		
		if (url)
			[result setObject:url forKey:@"url"];
	}
	[rs close];
	
	return result;
}

- (NSDictionary*)_findInArray:(NSArray*)array packageID:(NSString*)packageID
{
	if (!array)
		return nil;

	for (NSDictionary* entry in array)
	{
		if ([[entry objectForKey:@"package"] isEqualToString:packageID])
			return entry;
	}
	
	return nil;
}

#pragma mark -

- (void)urlDownloadDidFinish:(URLDownload *)download
{
	mDownloadError = NO;
}

- (void)urlDownload:(URLDownload *)download didFailWithError:(NSError *)error
{
	mDownloadError = YES;
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@ (%@)", [error localizedDescription], [download.url absoluteString]] forKey:NSLocalizedDescriptionKey];
	NSError* newError = [NSError errorWithDomain:[error domain] code:[error code] userInfo:userInfo];
	
	[mController performSelectorOnMainThread:@selector(failWithError:) withObject:newError waitUntilDone:YES];
}

- (void)urlDownload:(URLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	if (mFileSize)
	{
		mDownloadedBytes += length;
		
		float frac = ((float)mDownloadedBytes / (float)mFileSize);
		
		[self performSelectorOnMainThread:@selector(tellControllerUpdateProgress:) withObject:[NSNumber numberWithFloat:frac] waitUntilDone:NO];
	}
	
	if ([self isCancelled])
		[download cancelDownload];
}

#pragma mark -

- (BOOL)_install:(NSDictionary*)package
{
	NSString* status = [package objectForKey:@"name"]?[package objectForKey:@"name"]:[package objectForKey:@"package"];
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:status waitUntilDone:YES];
	
	//sleep(1);
	//return YES;
	
	// invoke dpkg
	int rc = 0;
	DPKGInvocation* di = [[DPKGInvocation alloc] init];

	NSArray* args = [NSArray arrayWithObjects:@"--force-depends,architecture", @"-i", [NSString stringWithUTF8String:[[package objectForKey:@"_dl"] fileSystemRepresentation]], nil];
	
	NSString* err = nil;
	rc = [di invoke:args errorInfo:&err];

	[di release];
	
	if (rc != 0)
	{
		NSDictionary* userErr = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" cannot be installed (DPKG returned error #%d). More information can probably be found in the console log.", @""), status, rc], NSLocalizedDescriptionKey,
									err, NSLocalizedFailureReasonErrorKey,
									[package objectForKey:@"package"], @"packageID", nil];
		NSError* error = [NSError errorWithDomain:DEBInstallOperationErrorDomain code:kDEBErrorInstallFailed userInfo:userErr];
		[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
	}
	
	return (rc == 0);
}

@end
