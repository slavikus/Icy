//
//  UpdatesSearchOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/23/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>

// Notification name being posted on the main thread... [notification object] will contain the updates array
#define kIcyUpdatedPackagesUpdatedNotification		@"com.ripdev.icy.updated-updated"

@class Database;

@interface UpdatesSearchOperation : NSOperation {
	Database*			mDB;
}

- (void)_checkUpdate:(NSDictionary*)pack withArray:(NSMutableArray*)updatedPackages;
- (NSDictionary*)_findPackage:(NSString*)packageID;

@end
