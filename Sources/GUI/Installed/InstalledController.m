//
//  InstalledController.m
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "InstalledController.h"
#import "DPKGParser.h"
#import "PackageInfoController.h"
#import "UpdatesSearchOperation.h"
#import "OperationQueue.h"
#import "InstallRemoveController.h"
#import "IcyAppDelegate.h"

static NSInteger _InstalledPackagesSortFunction(NSDictionary* p1, NSDictionary* p2, void *ctx);
static UIImage* gPackageImage = nil;

@implementation InstalledController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor_Installed"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor"];
	if (tintColor)
	{
		self.navigationController.navigationBar.tintColor = [tintColor colorRepresentation];
		segControl.tintColor = self.navigationController.navigationBar.tintColor;
	}
	else
		segControl.tintColor = [UIColor darkGrayColor];
	
	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor_Installed"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor"];
	if (tintColor)
	{
		self.tableView.backgroundColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor_Installed"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor"];
	if (tintColor)
	{
		if (![tintColor length])
			self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.tableView.separatorColor = [tintColor colorRepresentation];
	}
	
	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor_Installed"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor"];
	if (tintColor)
		cellTextColor = [[tintColor colorRepresentation] retain];
	else
		cellTextColor = nil;
	// ~Theme support

	installedPackages = [[NSMutableArray alloc] initWithCapacity:0];
	
	if (!updatedPackages)
		updatedPackages = [[NSMutableArray alloc] initWithCapacity:0];
	
	if ([updatedPackages count])
	{
		showInstalledPackages = NO;
		[segControl removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
		segControl.selectedSegmentIndex = 1;
		[segControl addTarget:self action:@selector(doSwitch:) forControlEvents:UIControlEventValueChanged];
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(doUpdateAll:)] autorelease];
	}
	else
	{
		showInstalledPackages = YES;
		UIBarButtonItem* editItem = self.editButtonItem;
		UIBarButtonItem* newItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:editItem.target action:editItem.action];
		self.navigationItem.rightBarButtonItem = newItem;
		[newItem release];
	}
	
	[self _rebuildInstalledPackages];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedPackagesUpdated:) name:kIcyUpdatedPackagesUpdatedNotification object:nil];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	// adjust the button states
	if (!showInstalledPackages)
		self.navigationItem.rightBarButtonItem.enabled = [updatedPackages count];
}

- (void)preSetup:(NSArray*)uPackages
{
	if (!updatedPackages)
		updatedPackages = [[NSMutableArray alloc] initWithCapacity:0];
	
	[updatedPackages removeAllObjects];
	[updatedPackages addObjectsFromArray:uPackages];
	
	updatedPackagesBuilt = YES;
	
	if (self.tableView && !showInstalledPackages)
	{
		[self.tableView reloadData];
		self.navigationItem.rightBarButtonItem.enabled = [updatedPackages count];
	}
}

- (void)updatedPackagesUpdated:(NSNotification*)notification
{
	NSArray* packages = [notification object];
	
	[updatedPackages removeAllObjects];
	[updatedPackages addObjectsFromArray:packages];

	if (!showInstalledPackages)
	{
		[self.tableView reloadData];
		self.navigationItem.rightBarButtonItem.enabled = [updatedPackages count] ? YES : NO;
	}
	
	updatedPackagesBuilt = YES;
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
    // Return YES for supported orientations
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
    return showInstalledPackages ? [installedPackages count] : [updatedPackages count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
		
		if (!gPackageImage)
			gPackageImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Package" ofType:@"png"]]] retain];
		cell.image = gPackageImage;
		
		if (cellTextColor)
			cell.textColor = cellTextColor;

		// prepare the subviews
		UILabel* categoryLabel = [[UILabel alloc] initWithFrame:CGRectMake(52, 24, 265, 24)];
		categoryLabel.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
		categoryLabel.textColor = [UIColor darkGrayColor];
		categoryLabel.textAlignment = UITextAlignmentLeft;
		categoryLabel.backgroundColor = [UIColor clearColor];
		
		[cell.contentView addSubview:categoryLabel];
		[categoryLabel release];
    }
	
	NSDictionary* pack = (showInstalledPackages ? [installedPackages objectAtIndex:indexPath.row] : [updatedPackages objectAtIndex:indexPath.row]);
    
    // Set up the cell...
	NSString* name = [pack objectForKey:@"name"];
	if (!name)
		name = [pack objectForKey:@"package"];
	
	cell.text = [NSString stringWithFormat:@"%@ (%@)", name, [pack objectForKey:@"version"]];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	UILabel* cat = nil;
	
	NSString* category = [pack objectForKey:@"section"];
	if (!category)
		category = NSLocalizedString(@"Uncategorized", @"");
	else
	{
		category = [category stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		category = [[NSBundle mainBundle] localizedStringForKey:category value:category table:@"Categories"];
	}

	if ([[cell.contentView subviews] count] > 1)
		cat = [[cell.contentView subviews] objectAtIndex:[[cell.contentView subviews] count]-1];
	if (cat && [cat isKindOfClass:[UILabel class]])
		cat.text = category;

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
	NSDictionary* pack = (showInstalledPackages ? [installedPackages objectAtIndex:indexPath.row] : [updatedPackages objectAtIndex:indexPath.row]);
	
	infoController.package = pack;
	[self.navigationController pushViewController:infoController animated:YES];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return showInstalledPackages;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        NSDictionary* pkg = [installedPackages objectAtIndex:indexPath.row];
		
		installRemoveController.identifiers = [NSArray arrayWithObject:[pkg objectForKey:@"package"]];
		installRemoveController.remove = YES;
	
		[installRemoveController doFlip:self];
		//[self performSelector:@selector(endEditing:) withObject:nil	afterDelay:.0];
		[self.tableView setEditing:NO animated:NO];
    }   
}

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

- (IBAction)doSwitch:(UISegmentedControl*)sender
{
	int idx = 1;
	
	if (sender)
		idx = sender.selectedSegmentIndex;
		
	segControl.selectedSegmentIndex = idx;
	
	showInstalledPackages = !idx;
	
	// let's do a funky animations if there's not many rows
	NSArray* deleteArray = (showInstalledPackages ? updatedPackages : installedPackages);
	NSArray* addArray = (showInstalledPackages ? installedPackages : updatedPackages);

	if ([deleteArray count] <= 25 &&
		[addArray count] <= 25 &&
		sender)
	{
		NSMutableArray* deleteIPs = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray* insertIPs = [NSMutableArray arrayWithCapacity:0];
		NSInteger i;
		
		for (i=0; i < [deleteArray count]; i++)
			[deleteIPs addObject:[NSIndexPath indexPathForRow:i inSection:0]];
		for (i=0; i < [addArray count]; i++)
			[insertIPs addObject:[NSIndexPath indexPathForRow:i inSection:0]];	
		
		[self.tableView beginUpdates];
		if ([deleteIPs count])
			[self.tableView deleteRowsAtIndexPaths:deleteIPs withRowAnimation:UITableViewRowAnimationFade];
		if ([insertIPs count])
			[self.tableView insertRowsAtIndexPaths:insertIPs withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];
	}
	else
	{
		[self.tableView reloadData];
	}
	
	if (!updatedPackagesBuilt)
	{
		updatedPackagesBuilt = YES;
		UpdatesSearchOperation* us = [[UpdatesSearchOperation alloc] init];
		[[OperationQueue sharedQueue] addOperation:us];
		[us release];
	}
	
	// shuffle the buttons
	if (!showInstalledPackages)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(doUpdateAll:)] autorelease];
		//[[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Update All", @"") style:UIBarButtonItemStylePlain target:self action:@selector(doUpdateAll:)] autorelease];
		
		if (![updatedPackages count])
			self.navigationItem.rightBarButtonItem.enabled = NO;
	}
	else
	{
		UIBarButtonItem* editItem = self.editButtonItem;
		UIBarButtonItem* newItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:editItem.target action:editItem.action];
		self.navigationItem.rightBarButtonItem = newItem;
		[newItem release];
	}
}

- (void)dealloc
{
	[installedPackages release];
	[updatedPackages release];
	[statusFileLastUpdate release];
	
    [super dealloc];
}

- (void)_rebuildInstalledPackages
{
	NSDate* fileDate = [[[NSFileManager defaultManager] fileAttributesAtPath:kIcyDPKGStatusDatabasePath traverseLink:YES] fileModificationDate];
	
	if (!statusFileLastUpdate ||
		![fileDate isEqualToDate:statusFileLastUpdate])
	{
		[statusFileLastUpdate release];
		statusFileLastUpdate = [fileDate retain];
		
		DPKGParser* parser = [[DPKGParser alloc] init];
		NSArray* packs = [parser parseDatabaseAtPath:kIcyDPKGStatusDatabasePath];
		[parser release];
		
		[installedPackages removeAllObjects];
		[installedPackages addObjectsFromArray:packs];
		
		[installedPackages sortUsingFunction:_InstalledPackagesSortFunction context:nil];
		
		if (showInstalledPackages)
			[self.tableView reloadData];
	}
}

- (void)doUpdateAll:(id)sender
{
	self.navigationItem.rightBarButtonItem.enabled = NO;
	
	// build an array
	NSMutableArray* ids = [NSMutableArray arrayWithCapacity:0];
	
	for (NSDictionary* p in updatedPackages)
	{
		[ids addObject:[p objectForKey:@"package"]];
	}
	
	if (![ids count])
		return;
		
	installRemoveController.identifiers = ids;
	installRemoveController.remove = NO;
	
	[installRemoveController doFlip:self];
}

@end

#pragma mark -

NSInteger _InstalledPackagesSortFunction(NSDictionary* p1, NSDictionary* p2, void *ctx)
{
	NSString* n1 = [p1 objectForKey:@"name"];
	NSString* n2 = [p2 objectForKey:@"name"];
	
	if (!n1)
		n1 = [p1 objectForKey:@"package"];
	
	if (!n2)
		n2 = [p2 objectForKey:@"package"];
		
	if (!n1)
		n1 = @"";
	
	if (!n2)
		n2 = @"";
		
	return [n1 compare:n2 options:NSCaseInsensitiveSearch];
}
