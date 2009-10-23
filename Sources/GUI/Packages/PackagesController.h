//
//  PackagesController.h
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PackageInfoController;
@class SearchController;

@interface PackagesController : UITableViewController {
	NSString* category;
	
	NSMutableArray* packages;
	
	IBOutlet PackageInfoController* infoController;
	IBOutlet SearchController*		searchController;
	
	BOOL		rebuildPackages;
	UIColor*	cellTextColor;
}

@property (nonatomic, retain) NSString* category;
@property (nonatomic, assign) BOOL rebuildPackages;

- (void)_rebuildPackages;

@end
