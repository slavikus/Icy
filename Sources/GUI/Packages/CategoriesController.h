//
//  CategoriesController.h
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Database.h"
#import "PackagesController.h"

@class SearchController;
@class RecentsController;

@interface CategoriesController : UITableViewController {
	IBOutlet PackagesController*	packagesController;
	IBOutlet SearchController*		searchController;
	IBOutlet RecentsController*		recentsController;
	
	NSMutableArray*					categories;
	NSMutableArray*					excludedCategories;
	BOOL							reloadNeeded;
	BOOL							onScreen;
	
	BOOL							editMode;
	
	UIColor*						cellTextColor;
	
	NSMutableDictionary*			categoryImages;
}

@property (assign) BOOL reloadNeeded;

- (void)_rebuildCategories;

@end
