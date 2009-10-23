//
//  DependenciesController.h
//  Icy
//
//  Created by Slava Karpenko on 4/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DPKGParser;

@interface DependenciesController : UITableViewController {

	NSMutableArray*			deps;
}

@property (nonatomic, assign) NSString* package;

//- (IBAction)doToggle:(UIView*)sender;

- (NSDictionary*)_findInArray:(NSArray*)array packageID:(NSString*)packageID;
- (NSMutableDictionary*)_findPackage:(NSString*)packageID;
- (void)_addPackageDeps:(NSString*)packageID withInstalledPackages:(NSArray*)installedPackages andParser:(DPKGParser*)parser seenPackages:(NSMutableArray*)seenPackages;

@end
