//
//  DEBRemoveOperation.h
//  Icy
//
//  Created by Slava Karpenko on 3/22/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>

@class InstallRemoveController;
@interface DEBRemoveOperation : NSOperation <UIActionSheetDelegate> {
	NSString* mPackageID;
	InstallRemoveController* mController;
	
	BOOL		forceEssential;
	BOOL		waitingOnEssentialDecision;
}

- initWithPackageID:(NSString*)packageID installUninstallController:(InstallRemoveController*)iuController;
- (NSDictionary*)_findInArray:(NSArray*)array packageID:(NSString*)packageID;

@end
