//
//  CategoriesController.m
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "CategoriesController.h"
#import "SearchController.h"
#import "RecentsController.h"
#import "IcyAppDelegate.h"
#import "NSString+RipdevExtensions.h"

static UIImage* gCategoriesImage = nil;
static UIImage* gRecentsImage = nil;

@implementation CategoriesController

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor_Categories"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor"];
	if (tintColor)
	{
		self.navigationController.navigationBar.tintColor = [tintColor colorRepresentation];
	}
	
	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor_Categories"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor"];
	if (tintColor)
	{
		self.tableView.backgroundColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor_Categories"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor"];
	if (tintColor)
	{
		if (![tintColor length])
			self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.tableView.separatorColor = [tintColor colorRepresentation];
	}
	
	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor_Categories"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor"];
	if (tintColor)
		cellTextColor = [[tintColor colorRepresentation] retain];
	else
		cellTextColor = nil;
	// ~Theme support

	categories = [[NSMutableArray alloc] initWithCapacity:0];
	excludedCategories = [[NSMutableArray alloc] initWithCapacity:0];
	
	categoryImages = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	self.reloadNeeded = YES;

    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(doEdit:)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(doSearch:)] autorelease];
}

- (void)dealloc
{
	[categoryImages release];
	[cellTextColor release];
	[categories release];
	[excludedCategories release];
    [super dealloc];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
	onScreen = YES;
	if (reloadNeeded)
	{
		[self _rebuildCategories];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	onScreen = NO;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)doSearch:(id)sender
{
	[self.navigationController pushViewController:searchController animated:YES];
}

#pragma mark -

- (BOOL)reloadNeeded
{
	return reloadNeeded;
}

- (void)setReloadNeeded:(BOOL)need
{
	reloadNeeded = need;
	
	if (reloadNeeded)
	{
		// Pop back to us if needed
		//[self.navigationController popToRootViewControllerAnimated:NO];
		if ([categories count])
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];

		if (onScreen)
			[self _rebuildCategories];
		else
		{
			UIViewController* c = [self.navigationController topViewController];
			if (c == packagesController)
			{
				packagesController.rebuildPackages = YES;
				[c viewWillAppear:NO];
			}
		}
		//recentsController.rebuildPackages = YES;
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [categories count] + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		if (cellTextColor)
			cell.textColor = cellTextColor;
		if (!gCategoriesImage)
			gCategoriesImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Category" ofType:@"png"]]] retain];
		if (!gRecentsImage)
			gRecentsImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Recent" ofType:@"png"]]] retain];
	}

	if (editMode)
	{
		UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectZero];
		[sw addTarget:self action:@selector(doEnableDisable:) forControlEvents:UIControlEventValueChanged];
		[sw setTag:indexPath.row];
		cell.accessoryView = sw;
		[sw release];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	else
	{
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	}
	
	if (indexPath.row)
	{
		cell.text = [categories objectAtIndex:indexPath.row-1];
		
		// check whether we have looked up this category
		NSString* reversedCatName = [[NSBundle mainBundle] localizedStringForKey:cell.text value:cell.text table:@"CategoriesReverse"];
		UIImage* catImage = [categoryImages objectForKey:reversedCatName];
		if (!catImage)
		{
			NSString* catNameFile = [NSString stringWithFormat:@"Category_%@", reversedCatName];
			
			NSLog(@"Attempting look up for \"%@\" (%@)", reversedCatName, catNameFile);
			
			NSString* catImagePath = [[NSBundle mainBundle] pathForResource:catNameFile ofType:@"png"];
			if (catImagePath)
			{
				catImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:catImagePath]] retain];
				
				[categoryImages setObject:catImage forKey:reversedCatName];
			}
			else
				[categoryImages setObject:[NSNull null] forKey:reversedCatName];
		}
		else if ([catImage isKindOfClass:[NSNull class]])
			catImage = nil;
		
		cell.image = catImage ? catImage : gCategoriesImage;
		
		if (editMode)
		{
			[((UISwitch*)cell.accessoryView) setOn:![excludedCategories containsObject:cell.text] animated:NO];
		}
	}
	else
	{
		cell.text = NSLocalizedString(@"Recent Packages", @"");
		cell.image = gRecentsImage;
		if (editMode)
		{
			[((UISwitch*)cell.accessoryView) setOn:YES animated:NO];
			((UISwitch*)cell.accessoryView).enabled = NO;
		}
	}
		
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editMode)
		return;
		
	if (indexPath.row)
	{
		packagesController.category = [categories objectAtIndex:indexPath.row-1];
		packagesController.rebuildPackages = YES;
		[self.navigationController pushViewController:packagesController animated:YES];
	}
	else
	{
		recentsController.rebuildPackages = YES;
		[self.navigationController pushViewController:recentsController animated:YES];
	}
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

#pragma mark -

- (void)_rebuildCategories
{
	reloadNeeded = NO;
	
	NSString* q = nil;
	
	if (editMode)
		q = @"SELECT DISTINCT category FROM packages ORDER BY category ASC";
	else
		q = @"SELECT DISTINCT category FROM packages WHERE category NOT IN (SELECT name FROM excluded_categories) ORDER BY category ASC";
	
	[categories removeAllObjects];
	
	Database* db = [Database database];
	ResultSet* rs = [db executeQuery:q];
	if (rs)
	{
		while ([rs next])
		{
			NSString* categoryName = [rs stringForColumn:@"category"];
			
			if (![categoryName length])
				categoryName = NSLocalizedString(@"Uncategorized", @"");
			[categories addObject:categoryName];
		}
	}
	
	[rs close];
	
	[self.tableView reloadData];
}

#pragma mark -

- (void)doEdit:(id)sender
{
	editMode = !editMode;
	
	if (editMode)
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doEdit:)] autorelease];
	else
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(doEdit:)] autorelease];

	[self _rebuildCategories];

	if (editMode)
	{
		[excludedCategories removeAllObjects];
		
		Database* db = [Database database];
		ResultSet* rs = [db executeQuery:@"SELECT name FROM excluded_categories"];
		if (rs)
		{
			while ([rs next])
			{
				NSString* categoryName = [rs stringForColumn:@"name"];
				
				if (![categoryName length])
					categoryName = NSLocalizedString(@"Uncategorized", @"");
				[excludedCategories addObject:categoryName];
				
				if (![categories containsObject:categoryName])
					[categories addObject:categoryName];
			}
		}
		
		[rs close];
	}
	
	[self.tableView reloadData];
}

- (void)doEnableDisable:(id)sender
{
	NSInteger idx = [sender tag];
	
	if (!idx)
		return;
		
	NSString* catName = [categories objectAtIndex:idx-1];
	BOOL on = ((UISwitch*)sender).on;
	
	if (on)
	{
		[[Database sharedDatabase] executeUpdate:@"DELETE FROM excluded_categories WHERE name = ?", catName];
		[excludedCategories removeObject:catName];
	}
	else
	{
		[[Database sharedDatabase] executeUpdate:@"INSERT INTO excluded_categories (name) VALUES(?)", catName];
		[excludedCategories addObject:catName];
	}
}

@end

