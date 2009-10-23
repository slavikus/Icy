//
//  PackagesURLSearchOperation.m
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "PackagesURLSearchOperation.h"
#import "OperationQueue.h"

static NSString* sPackagesURLSearchOrder[] = {
	@"Packages.bz2",
	@"Packages.gz",
	@"Packages",
	@"dists/stable/main/binary-iphoneos-arm/Packages.bz2",
	@"dists/stable/main/binary-iphoneos-arm/Packages.gz",
	@"dists/stable/main/binary-iphoneos-arm/Packages",
	@"dists/tangelo/main/binary-iphoneos-arm/Packages.bz2",
	@"dists/tangelo/main/binary-iphoneos-arm/Packages.gz",
	@"dists/tangelo/main/binary-iphoneos-arm/Packages",
	@"dists/unstable/main/binary-iphoneos-arm/Packages.bz2",
	@"dists/unstable/main/binary-iphoneos-arm/Packages.gz",
	@"dists/unstable/main/binary-iphoneos-arm/Packages",
	@"dists/hnd/main/binary-iphoneos-arm/Packages.bz2",				// special case for HackNDev, grr
	nil
};

static NSString* sReleaseURLSearchOrder[] = {
	@"Release",
	@"dists/stable/main/Release",
	@"dists/tangelo/main/Release",
	@"dists/hnd/main/Release",				// special case for HackNDev, grr
	nil
};

@implementation PackagesURLSearchOperation

+ (PackagesURLSearchOperation*)enqueueForSource:(sqlite_int64)rowID delegate:(id)del
{
	PackagesURLSearchOperation* op = [[PackagesURLSearchOperation alloc] initWithSourceID:rowID delegate:del];
	
	[[OperationQueue sharedQueue] performSelector:@selector(addOperation:) withObject:op afterDelay:.0];
	
	return [op autorelease];
}

- initWithSourceID:(sqlite_int64)rowID delegate:(id)del
{
	if (self = [super init])
	{
		mRowID = rowID;
		delegate = del;
	}
	
	return self;
}

- (void)dealloc
{
	[mBaseURL release];

	[super dealloc];
}

- (void)main
{
	// get url
	mDB = [[Database database] retain];
	ResultSet* rs = [[Database database] executeQuery:@"SELECT url FROM sources WHERE RowID = ?", [NSNumber numberWithLongLong:mRowID]];
	if (rs && [rs next])
	{
		mBaseURL = [[NSURL alloc] initWithString:[rs stringForColumn:@"url"]];
	}
	
	[rs close];
	
	// Now find the Release file for this source
	mCurrentSearchIndex = 0;
	finished = NO;
	releaseSearchPhase = YES;
	do
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		[self _tryNext];
		[pool release];
	} while (!finished);

	mCurrentSearchIndex = 0;	
	finished = NO;
	releaseSearchPhase = NO;
	do
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		[self _tryNext];
		[pool release];
	} while (!finished);
	
	
}

#pragma mark -

- (void)urlDownloadDidFinish:(URLDownload *)download
{
	// save the download url location
	if (!releaseSearchPhase)
	{
		[mDB executeUpdate:@"UPDATE sources SET pkgurl = ? WHERE RowID = ?", [download.url absoluteString], [NSNumber numberWithLongLong:mRowID]];
	}
	else
	{
		// we don't remove the downloaded file so it can be re-used as a cache
		if (delegate && [delegate respondsToSelector:@selector(sourcePassedTests:packagesPath:packagesURL:)])
			[delegate sourcePassedTests:[NSNumber numberWithLongLong:mRowID] packagesPath:download.downloadFilePath packagesURL:download.url];
	}
	
	[download release];
	
	finished = YES;
}

- (void)urlDownload:(URLDownload *)download didFailWithError:(NSError *)error
{
	[download release];
}

#pragma mark -

- (void)_tryNext
{
	NSString* nextString = nil;
	
	if (releaseSearchPhase)
		nextString = sReleaseURLSearchOrder[mCurrentSearchIndex];
	else
	{
		if (concretePackagesPaths)
		{
			if (mCurrentSearchIndex < [concretePackagesPaths count])
			{
				nextString = [concretePackagesPaths objectAtIndex:mCurrentSearchIndex];
			}
		}
		else
			nextString = sPackagesURLSearchOrder[mCurrentSearchIndex];
	}
	
	mCurrentSearchIndex++;
	
	if (!nextString)
	{
		finished = YES;
		
		if (!releaseSearchPhase)
		{
			if (delegate && [delegate respondsToSelector:@selector(sourceFailedTests:)])
				[delegate performSelectorOnMainThread:@selector(sourceFailedTests:) withObject:[NSNumber numberWithLongLong:mRowID] waitUntilDone:NO];
		}
		
		return;
	}
	
	NSURL* newURL = [[NSURL alloc] initWithString:nextString relativeToURL:mBaseURL];
	NSLog(@"Trying %@", [newURL absoluteString]);
	URLDownload* dl = [[URLDownload alloc] initWithURL:newURL delegate:self];
	dl.actAsInsect = YES;
	[newURL release];
	
	[dl start];
}

@end
