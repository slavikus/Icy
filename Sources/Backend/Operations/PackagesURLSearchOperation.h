//
//  PackagesURLSearchOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/13/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "URLDownload.h"
#import "Database.h"

@interface PackagesURLSearchOperation : NSOperation {
	sqlite_int64	mRowID;
	NSUInteger	mCurrentSearchIndex;
	NSURL*			mBaseURL;
	Database*		mDB;
	
	id				delegate;
	BOOL			finished;
	BOOL			releaseSearchPhase;
	NSMutableArray*	concretePackagesPaths;
}

+ (PackagesURLSearchOperation*)enqueueForSource:(sqlite_int64)rowID delegate:(id)del;
- initWithSourceID:(sqlite_int64)rowID delegate:(id)del;

- (void)_tryNext;
@end

@interface NSObject (PackagesURLSearchOperationDelegate)

- (void)sourceFailedTests:(NSNumber*)rowID;
- (void)sourcePassedTests:(NSNumber*)rowID packagesPath:(NSString*)path packagesURL:(NSURL*)url;

@end

