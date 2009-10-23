//
//  RecentsController.h
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PackageInfoController;
@class SearchController;

@interface RecentsController : UITableViewController {
	NSMutableArray* packages;
	NSMutableArray* sections;
	
	IBOutlet PackageInfoController* infoController;
	IBOutlet SearchController*		searchController;
	
	BOOL		rebuildPackages;
	UIColor*	cellTextColor;
}

@property (nonatomic, assign) BOOL rebuildPackages;

- (void)_rebuildPackages:(NSUInteger)offset;
- (void)_rebuildCategories:(NSUInteger)from;

@end
