//
//  SourceRefreshOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/13/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "URLDownload.h"
#import "Database.h"

#define kSourceRefreshOperationPortName			CFSTR("com.ripdev.icy.port.source-refresh-processor")

@interface SourceRefreshOperation : NSOperation {
	id				delegate;
	Database*		mDB;
	CFMessagePortRef	mMessagePort;
	
	NSMutableArray*	mQueue;
}

- (SourceRefreshOperation*)initWithDelegate:(id)del;
- (void)parsePackagesFile:(NSString*)path forSourceID:(sqlite_int64)sourceID;

- (void)notifyDelegateWithSourceID:(NSNumber*)sourceID;
- (void)handlePortMessage:(SInt32)msgID withData:(NSData*)data;
- (void)checkForWork;
@end

@interface NSObject (SourceRefreshOperationDelegate)

- (void)sourceRefreshStarted:(NSNumber*)rowID;
- (void)sourceRefreshDone:(NSNumber*)rowID withError:(NSError*)error;
- (void)sourceRefreshFinished;

@end
