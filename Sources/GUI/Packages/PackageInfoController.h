//
//  PackageInfoController.h
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InstallRemoveController;
@class DepictionController;
@class DependenciesController;

@interface PackageInfoController : UIViewController {
	IBOutlet UILabel* name;
	IBOutlet UILabel* version;
	IBOutlet UILabel* size;
	IBOutlet UITextView* description;
	IBOutlet UILabel* author;
	IBOutlet UILabel* maintainer;
	IBOutlet UIButton* authorMailButton;
	IBOutlet UIButton* maintainerMailButton;
	IBOutlet UILabel* dependencies;

	IBOutlet UIButton* depictionButton;
	IBOutlet DepictionController* depictionController;

	IBOutlet InstallRemoveController* installRemoveController;
	
	BOOL		shouldRefreshOnShow;
	
	NSDictionary* package;
	
	DependenciesController* dependenciesController;
	UIButton*				dependenciesButton;
}

@property (nonatomic, retain) NSDictionary* package;

- (IBAction)doInstall:(id)sender;
- (IBAction)doRemove:(id)sender;

- (IBAction)doMailAuthor:(id)sender;
- (IBAction)doMailMaintainer:(id)sender;

- (IBAction)doDepiction:(id)sender;

- (NSString*)getProperty:(NSString*)name;

@end
