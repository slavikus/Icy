//
//  SourceIndexDownloadOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface SourceIndexDownloadOperation : NSOperation {
	sqlite_int64 sourceID;
	NSURL* url;
	id delegate;
}

- initWithSourceID:(sqlite_int64)sourceID url:(NSURL*)_url delegate:(id)_del;

// Private methods
- (int)exec:(char**)argv redirectTo:(NSString*)redirectPath;
- (NSString*)unBzip2:(NSString*)path;
- (NSString*)unGzip:(NSString*)path;

- (void)notifyDelegateWithError:(NSError*)error;

@end
