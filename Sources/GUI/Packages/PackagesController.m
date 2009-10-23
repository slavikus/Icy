//
//  PackagesController.m
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "PackagesController.h"
#import "Database.h"
#import "PackageInfoController.h"
#import "SearchController.h"
#import "IcyAppDelegate.h"

static UIImage* gPackageImage = nil;

@implementation PackagesController
@synthesize category;
@synthesize rebuildPackages;

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
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor_Packages"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor"];
	if (tintColor)
	{
		self.tableView.backgroundColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor_Packages"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor"];
	if (tintColor)
	{
		if (![tintColor length])
			self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.tableView.separatorColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor_Packages"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor"];
	if (tintColor)
		cellTextColor = [[tintColor colorRepresentation] retain];
	// ~Theme support

	packages = [[NSMutableArray alloc] initWithCapacity:0];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(doSearch:)] autorelease];
}

- (void)doSearch:(id)sender
{
	[self.navigationController pushViewController:searchController animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	if ([self.category isEqualToString:@"%"])
		self.navigationItem.title = NSLocalizedString(@"All Packages", @"");
	else
		self.navigationItem.title = self.category;
	
	if (self.rebuildPackages)
		[self _rebuildPackages];
	//[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [packages count];
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
		if (!gPackageImage)
			gPackageImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Package" ofType:@"png"]]] retain];
		cell.image = gPackageImage;
     }
    
    // Set up the cell...
	NSDictionary* package = [packages objectAtIndex:indexPath.row];
	
	cell.text = [NSString stringWithFormat:@"%@ (%@)", [package objectForKey:@"name"], [package objectForKey:@"version"]];

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	infoController.package = [packages objectAtIndex:indexPath.row];
	[self.navigationController pushViewController:infoController animated:YES];
	
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


- (void)dealloc {
	[cellTextColor release];
	[packages release];
    [super dealloc];
}

#pragma mark  -

- (void)_rebuildPackages
{
	[packages removeAllObjects];
	
	Database* db = [Database database];
	
	ResultSet* rs = [db executeQuery:@"SELECT RowID, name, version, identifier FROM packages WHERE category = ? ORDER BY name ASC", self.category];
	if (rs)
	{
		while ([rs next])
		{
			NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithCapacity:0];
			NSString* name = [rs stringForColumn:@"name"];
			NSString* version = [rs stringForColumn:@"version"];
			NSString* identifier = [rs stringForColumn:@"identifier"];
			
			[dict setObject:[NSNumber numberWithLongLong:[rs intForColumn:@"rowid"]] forKey:@"id"];
			if (name)
				[dict setObject:name forKey:@"name"];
			if (identifier)
				[dict setObject:identifier forKey:@"identifier"];
			if (version)
				[dict setObject:version forKey:@"version"];
			
			[packages addObject:dict];
			[dict release];
		}
	}
	
	[rs close];
	
	[self.tableView reloadData];
	
	self.rebuildPackages = NO;
	
}

@end

