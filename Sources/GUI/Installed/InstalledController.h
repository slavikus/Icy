//
//  InstalledController.h
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PackageInfoController;
@class InstallRemoveController;

@interface InstalledController : UITableViewController {
	NSMutableArray* installedPackages;
	NSMutableArray* updatedPackages;
	
	BOOL			showInstalledPackages;
	
	IBOutlet PackageInfoController*		infoController;
	IBOutlet UISegmentedControl*		segControl;
	
	NSDate*			statusFileLastUpdate;
	
	IBOutlet UITabBarController* tabBar;
	
	BOOL			updatedPackagesBuilt;
	UIColor*		cellTextColor;
	
	
	IBOutlet InstallRemoveController* installRemoveController;
}

- (void)_rebuildInstalledPackages;

- (IBAction)doSwitch:(UISegmentedControl*)sender;
- (void)preSetup:(NSArray*)uPackages;

@end
