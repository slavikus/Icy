//
//  DEBInstallOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/20/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>

@class InstallRemoveController;

@interface DEBInstallOperation : NSOperation {
	NSArray*					mPackageIDs;
	InstallRemoveController*	mController;
	
	NSMutableArray*				mPackageList;
	NSArray*					mInstalledPackages;
	NSMutableArray*				mProcessedPackages;
	
	BOOL						mDownloadError;
	NSUInteger					mFileSize;
	NSUInteger					mDownloadedBytes;
}

- initWithPackageID:(NSString*)packageID installUninstallController:(InstallRemoveController*)iuController;
// Package IDs is an array of NSString* values
- initWithPackageIDs:(NSArray*)packageIDs installUninstallController:(InstallRemoveController*)iuController;

- (NSDictionary*)_findInArray:(NSArray*)array packageID:(NSString*)packageID;
- (NSDictionary*)_findPackage:(NSString*)packageID;
- (BOOL)_queuePackage:(NSString*)packageID;
- (BOOL)_queueDependencies:(NSDictionary*)package forKey:(NSString*)key;
- (BOOL)_install:(NSDictionary*)package;
- (BOOL)_checkConflict:(NSDictionary*)conf;

@end
