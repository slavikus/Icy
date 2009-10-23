//
//  SourceRefreshOperation.m
//  Installer
//
//  Created by Slava Karpenko on 3/13/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <unistd.h>
#import "SourceRefreshOperation.h"
#import "OperationQueue.h"
#import "NSFileManager+RipdevExtensions.h"
#import "DPKGParser.h"

#define SLEEP_AMT 1

static CFDataRef SourceRefreshOperation_MessagePortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
static void SourceRefreshOperation_ObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info);

@implementation SourceRefreshOperation

- (SourceRefreshOperation*)initWithDelegate:(id)del
{
	if (self = [super init])
	{
		delegate = del;
		
		mQueue = [[NSMutableArray alloc] initWithCapacity:0];
	}
	
	return self;
}

- (void)dealloc
{
	if (mMessagePort)
	{
		CFMessagePortInvalidate(mMessagePort);
		CFRelease(mMessagePort);
	}
	
	[mQueue release];
	[super dealloc];
}

- (void)main
{
	mDB = [Database database];
	
	[mDB executeUpdate:@"PRAGMA temp_store = MEMORY"];
	
	CFMessagePortContext ctx = { 0 };
	ctx.info = self;
	ctx.retain = &CFRetain;
	ctx.release = &CFRelease;
	
	CFRunLoopSourceRef src = NULL;
	
	mMessagePort = CFMessagePortCreateLocal(kCFAllocatorDefault, kSourceRefreshOperationPortName, SourceRefreshOperation_MessagePortCallBack, &ctx, NO);
	if (mMessagePort)
	{
		src = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, mMessagePort, 0);
		if (src)
		{
			CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopDefaultMode);
		}
	}
	
	CFRunLoopObserverContext octx = { 0 };
	octx.info = self;
	octx.retain = &CFRetain;
	octx.release = &CFRelease;
	
	CFRunLoopObserverRef obs = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeSources, TRUE, 0, SourceRefreshOperation_ObserverCallBack, &octx);
	if (obs)
	{
		CFRunLoopAddObserver(CFRunLoopGetCurrent(), obs, kCFRunLoopDefaultMode);
	}
		
	do
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, .5, FALSE);
		[pool release];
	} while (![self isCancelled]);

	if (src)
	{
		CFRunLoopSourceInvalidate(src);
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, kCFRunLoopDefaultMode);
		CFRelease(src);
	}
	
	if (obs)
	{
		CFRunLoopObserverInvalidate(obs);
		CFRunLoopRemoveObserver(CFRunLoopGetCurrent(), obs, kCFRunLoopDefaultMode);
		CFRelease(obs);
	}
		
	/*
	NSMutableArray* sources = [NSMutableArray arrayWithCapacity:0];
	
	ResultSet* rs = [mDB executeQuery:@"SELECT RowID, lastupdate FROM sources"];
	
	while ([rs next])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		sqlite_int64 sourceID = [rs intForColumn:@"rowid"];
		NSDate* lastupdate = [rs dateForColumn:@"lastupdate"];
		NSString* destPath = [kIcyIndexesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.idx", (int)sourceID]];
			
		if (![[NSFileManager defaultManager] fileExistsAtPath:destPath])
		{
			[pool release];
			continue;
		}
		
		// check lastupdate
		NSDictionary* attrs = [[NSFileManager defaultManager] fileAttributesAtPath:destPath traverseLink:NO];
		NSDate* lastmod = [attrs fileModificationDate];
		
		if (![lastupdate isEqualToDate:lastmod])
		{
			[sources addObject:[NSDictionary dictionaryWithObjectsAndKeys:destPath, @"path", [NSNumber numberWithLongLong:sourceID], @"id", lastmod, @"date", nil]];
		}

		[pool release];
	}
	
	[rs close];
	
	for (NSDictionary* source in sources)
	{
		[mDB beginTransaction];
		[self parsePackagesFile:[source objectForKey:@"path"] forSourceID:[[source objectForKey:@"id"] longLongValue]];
		[mDB executeUpdate:@"UPDATE sources SET lastupdate = ? WHERE RowID = ?", [source objectForKey:@"date"], [source objectForKey:@"id"]];
		[mDB commit];
	}
	
	*/
	
	NSLog(@"Source refreshes thread is done.");
	
	if (delegate && [delegate respondsToSelector:@selector(sourceRefreshFinished)])
		[delegate performSelectorOnMainThread:@selector(sourceRefreshFinished) withObject:nil waitUntilDone:YES];
}

- (void)checkForWork
{
	if (![mQueue count])
		return;
		
	NSNumber* sourceID = [[mQueue objectAtIndex:0] retain];
	[mQueue removeObjectAtIndex:0];
	
	ResultSet* rs = [mDB executeQuery:@"SELECT RowID, lastupdate FROM sources WHERE RowID = ?", sourceID];
	
	if ([rs next])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		sqlite_int64 sid = [rs intForColumn:@"rowid"];
		NSDate* lastupdate = [[rs dateForColumn:@"lastupdate"] retain];
		NSString* destPath = [kIcyIndexesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.idx", (int)sid]];
		
		[rs close];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:destPath])
		{
			NSDictionary* attrs = [[NSFileManager defaultManager] fileAttributesAtPath:destPath traverseLink:NO];
			NSDate* lastmod = [attrs fileModificationDate];
			
			if (![lastupdate isEqualToDate:lastmod])
			{
				[mDB beginTransaction];
				[self parsePackagesFile:destPath forSourceID:sid];
				[mDB executeUpdate:@"UPDATE sources SET lastupdate = ? WHERE RowID = ?", lastmod, sourceID];
				[mDB commit];
			}
		}
		
		[lastupdate release];

		[pool release];
	}
	
	[self performSelectorOnMainThread:@selector(notifyDelegateWithSourceID:) withObject:sourceID waitUntilDone:YES];

	[sourceID release];
}

- (void)handlePortMessage:(SInt32)msgID withData:(NSData*)data
{
	NSNumber* sourceID = [NSNumber numberWithUnsignedInt:(unsigned int)msgID];
	
	if (![mQueue containsObject:sourceID])
	{
		[mQueue addObject:sourceID];
	}
}

- (void)parsePackagesFile:(NSString*)path forSourceID:(sqlite_int64)sourceID
{
	NSAutoreleasePool* superPool = [[NSAutoreleasePool alloc] init];

	DPKGParser* pa = [[DPKGParser alloc] init];
	NSArray* packages = [pa parseDatabaseAtPath:path ignoreStatus:YES];
	[pa release];
	
	[mDB executeUpdate:@"DELETE FROM packages WHERE source = ?", [NSNumber numberWithLongLong:sourceID]];
	
	if (!packages)
	{
		[self performSelectorOnMainThread:@selector(notifyDelegateWithSourceID:) withObject:[NSNumber numberWithLongLong:sourceID] waitUntilDone:YES];
		[superPool release];
		return;
	}
	
	NSBundle* bundle = [NSBundle mainBundle];
	
	NSDate* dbModDate = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] fileModificationDate];
	
	sqlite3_stmt* deleteFromPackagesStmt = NULL;
	sqlite3_stmt* insertIntoPackagesStmt = NULL;
	sqlite3_stmt* insertIntoMetaStmt = NULL;
	sqlite3_stmt* insertIntoMemoriesStmt = NULL;
	
	sqlite3* db = [mDB db];
	
	NSCharacterSet* whitespaceNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Prepare our statements in advance
	int rc = sqlite3_prepare_v2(db, "DELETE FROM packages WHERE identifier = ?", -1, &deleteFromPackagesStmt, NULL);
	if (rc != SQLITE_OK)
		NSLog(@"Error in preparing statement deleteFromPackagesStmt: %d", rc);
	rc = sqlite3_prepare_v2(db, "INSERT INTO packages (source,identifier,category,name,version) VALUES(?,?,?,?,?)", -1, &insertIntoPackagesStmt, NULL);
	if (rc != SQLITE_OK)
		NSLog(@"Error in preparing statement insertIntoPackagesStmt: %d", rc);
	rc = sqlite3_prepare_v2(db, "INSERT INTO meta (identifier,tag,data) VALUES(?,?,?)", -1, &insertIntoMetaStmt, NULL);
	if (rc != SQLITE_OK)
		NSLog(@"Error in preparing statement insertIntoMetaStmt: %d", rc);
	rc = sqlite3_prepare_v2(db, "INSERT INTO memories (identifier,package,name,version,created) VALUES(?,?,?,?,?)", -1, &insertIntoMemoriesStmt, NULL);
	if (rc != SQLITE_OK)
		NSLog(@"Error in preparing statement insertIntoMemoriesStmt: %d", rc);

	for (NSDictionary* p in packages)
	{
		if (![p objectForKey:@"package"])
			continue;
			
		/* if ([p objectForKey:@"tag"] &&
			[[p objectForKey:@"tag"] rangeOfString:@"cydia::commercial"].length)
				continue;
		*/
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		const char* currentIdentifier = [[p objectForKey:@"package"] UTF8String];
		
		// DELETE FROM packages WHERE identifier = ?
		sqlite3_bind_text(deleteFromPackagesStmt, 1, currentIdentifier, -1, SQLITE_STATIC);
		do
		{
			rc = sqlite3_step(deleteFromPackagesStmt);
			if (rc == SQLITE_BUSY)
				usleep(SLEEP_AMT);
		} while (rc == SQLITE_BUSY);
		
		if (rc != SQLITE_OK && rc != SQLITE_DONE)
			NSLog(@"sqlite3_step(DELETE FROM packages WHERE identifier = %@) = %d", [p objectForKey:@"package"], rc);
		sqlite3_reset(deleteFromPackagesStmt);
		
		// Add the package
		// INSERT INTO packages (source,identifier,category,name,version) VALUES(?,?,?,?,?)
		NSString* category = [p objectForKey:@"section"];
		if (!category)
			category = NSLocalizedString(@"Uncategorized", @"");
		else
		{
			category = [category stringByTrimmingCharactersInSet:whitespaceNewlineSet];
			category = [bundle localizedStringForKey:category value:category table:@"Categories"];
		}
		
		NSString* name = [p objectForKey:@"name"];
		NSString* version = [p objectForKey:@"version"];
			
		sqlite3_bind_int64(insertIntoPackagesStmt, 1, sourceID);
		sqlite3_bind_text(insertIntoPackagesStmt, 2, currentIdentifier, -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoPackagesStmt, 3, [category UTF8String], -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoPackagesStmt, 4, name?[name UTF8String]:currentIdentifier, -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoPackagesStmt, 5, version?[version UTF8String]:"0.1", -1, SQLITE_STATIC);
		do
		{
			rc = sqlite3_step(insertIntoPackagesStmt);
			if (rc == SQLITE_BUSY)
				usleep(SLEEP_AMT);
		} while (rc == SQLITE_BUSY);
		if (rc != SQLITE_OK && rc != SQLITE_DONE)
			NSLog(@"sqlite3_step(INSERT INTO packages (%d,%s, ...) = %d", (int)sourceID, currentIdentifier, rc);
		sqlite3_reset(insertIntoPackagesStmt);
		
		// insert into memories
		// INSERT INTO memories (identifier,package,name,version,created) VALUES(?,?,?,?,?)
		sqlite3_bind_text(insertIntoMemoriesStmt, 1, [[NSString stringWithFormat:@"%s.%@", currentIdentifier, version?version:@"0"] UTF8String], -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoMemoriesStmt, 2, currentIdentifier, -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoMemoriesStmt, 3, name?[name UTF8String]:currentIdentifier, -1, SQLITE_STATIC);
		sqlite3_bind_text(insertIntoMemoriesStmt, 4, version?[version UTF8String]:"0.1", -1, SQLITE_STATIC);
		sqlite3_bind_double(insertIntoMemoriesStmt, 5, [dbModDate timeIntervalSince1970]);
		do
		{
			rc = sqlite3_step(insertIntoMemoriesStmt);
		} while (rc == SQLITE_BUSY);
		sqlite3_reset(insertIntoMemoriesStmt);
		
		// Now add meta
		for (NSString* key in p)
		{
			NSString* value = [p objectForKey:key];
			
			if ([key isEqualToString:@"section"])
				value = [bundle localizedStringForKey:value value:value table:@"Categories"];
			
			sqlite3_bind_text(insertIntoMetaStmt, 1, currentIdentifier, -1, SQLITE_STATIC);
			sqlite3_bind_text(insertIntoMetaStmt, 2, [key UTF8String], -1, SQLITE_STATIC);
			sqlite3_bind_text(insertIntoMetaStmt, 3, [value UTF8String], -1, SQLITE_STATIC);
			do
			{
				rc = sqlite3_step(insertIntoMetaStmt);
				if (rc == SQLITE_BUSY)
					usleep(SLEEP_AMT);
			} while (rc == SQLITE_BUSY);
			
			if (rc != SQLITE_OK && rc != SQLITE_DONE)
				NSLog(@"sqlite3_step(INSERT INTO meta (%d,%s,%@,...) = %d", (int)sourceID, currentIdentifier, key, rc);
			sqlite3_reset(insertIntoMetaStmt);
		}
		
		[pool release];
	}

	sqlite3_finalize(deleteFromPackagesStmt);
	sqlite3_finalize(insertIntoPackagesStmt);
	sqlite3_finalize(insertIntoMetaStmt);
	sqlite3_finalize(insertIntoMemoriesStmt);
	
	[superPool release];
}

- (void)notifyDelegateWithSourceID:(NSNumber*)sourceID
{
	if (delegate && [delegate respondsToSelector:@selector(sourceRefreshDone:withError:)])
		[delegate sourceRefreshDone:sourceID withError:nil];
}

@end

CFDataRef SourceRefreshOperation_MessagePortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
	SourceRefreshOperation* op = (SourceRefreshOperation*)info;
	
	[op handlePortMessage:msgid withData:(NSData*)data];
	
	return NULL;
}

static void SourceRefreshOperation_ObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
	// perform
	SourceRefreshOperation* op = (SourceRefreshOperation*)info;
	
	[op checkForWork];
}
