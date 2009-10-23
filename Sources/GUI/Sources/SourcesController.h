//
//  SourcesController.h
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Database.h"

@class CategoriesController;

@interface SourcesController : UITableViewController {
	IBOutlet CategoriesController*	categoriesController;
	NSMutableArray*					sources;
	NSMutableArray*					refreshingSources;
	
	int								totalRefreshes;
	
	NSMutableArray*					pickerSources;
	
	IBOutlet UIBarButtonItem*		pickerPlusButton;
	IBOutlet UIBarButtonItem*		pickerDoneButton;
	IBOutlet UIPickerView*			pickerView;
	IBOutlet UIView*				pickerContainer;
	
	UIColor* cellTextColor;
}

- (IBAction)doRefresh:(id)sender;
- (IBAction)doAdd:(id)sender;

- (IBAction)doPickerAdd:(id)sender;
- (IBAction)doPickerDone:(id)sender;
- (IBAction)doCustomAdd:(id)sender;
- (IBAction)doPickerAddAll:(id)sender;
- (void)_invokePicker:(id)sender;

- (void)reloadSources;
- (void)_addSource:(NSURL*)url;
- (void)_removeSource:(NSDictionary*)source;
- (NSInteger)indexForSource:(sqlite_int64)rowID;
- (NSDictionary*)sourceWithURL:(NSURL*)url;

@end
