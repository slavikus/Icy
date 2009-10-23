//
//  SearchController.h
//  Icy
//
//  Created by Slava Karpenko on 3/26/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PackageInfoController;
@interface SearchController : UIViewController {
	IBOutlet UISearchBar* searchBar;
	IBOutlet UITableView* tableView;
	IBOutlet PackageInfoController* infoController;
	
	NSMutableArray* packages;
	UIColor* cellTextColor;
}

- (void)updateSearch;

@end
