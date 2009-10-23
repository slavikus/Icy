//
//  DependenciesController.m
//  Icy
//
//  Created by Slava Karpenko on 4/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "DependenciesController.h"
#import "DPKGParser.h"
#import "Database.h"
#import "IcyAppDelegate.h"

static UIImage* gPackageImage = nil;
static NSInteger Dependencies_ArraySort(NSDictionary* d1, NSDictionary* d2, void *);

@implementation DependenciesController

@dynamic package;

- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {		
	/*	CGRect frame;
		
		frame = self.tableView.frame;
		frame.origin.y = 0;
		frame.size.height -= 50;
		
		self.tableView.frame = frame;
	*/	
		deps = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}


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
		self.tableView.separatorColor = [tintColor colorRepresentation];
	}
	// ~Theme support

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
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
    return [deps count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
	    
    // Set up the cell...
	NSUInteger pkgIdx = indexPath.row;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
		if (!gPackageImage)
			gPackageImage = [[UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Package" ofType:@"png"]]] retain];
		cell.image = gPackageImage;
		
		// prepare the subviews
		UILabel* categoryLabel = [[UILabel alloc] initWithFrame:CGRectMake(52, 24, 265, 24)];
		categoryLabel.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
		categoryLabel.textColor = [UIColor darkGrayColor];
		categoryLabel.textAlignment = UITextAlignmentLeft;
		categoryLabel.backgroundColor = [UIColor clearColor];
		
		[cell.contentView addSubview:categoryLabel];
		[categoryLabel release];
     }

	NSDictionary* package = [deps objectAtIndex:pkgIdx];
	
	UILabel* cat = nil;
	
	if ([[cell.contentView subviews] count] > 1)
		cat = [[cell.contentView subviews] objectAtIndex:1];
	if (cat && [cat isKindOfClass:[UILabel class]])
		cat.text = [package objectForKey:@"section"];
	
	if ([package objectForKey:@"version"])
		cell.text = [NSString stringWithFormat:@"%@ (%@)", [package objectForKey:@"name"], [package objectForKey:@"version"]];
	else
		cell.text = [package objectForKey:@"name"];
	cell.accessoryType = [package objectForKey:@"installed"] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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
	[deps release];
    [super dealloc];
}

/*
#pragma mark -

- (void)doReturn:(id)sender
{
	[self doToggle:self.view.superview];
}

- (IBAction)doToggle:(UIView*)sender
{
    UIView *mainView = sender;
    UIView *flipsideView = self.view;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:.7];
    [UIView setAnimationTransition:(![flipsideView superview] ? UIViewAnimationTransitionCurlUp : UIViewAnimationTransitionCurlDown) forView:mainView cache:YES];
 	
    if (![flipsideView superview]) {
        [mainView addSubview:flipsideView];
    } else {
        [flipsideView removeFromSuperview];
	}
    [UIView commitAnimations];
}
*/

#pragma mark -

- (void)setPackage:(NSString*)package
{
	[deps removeAllObjects];
	DPKGParser* p = [[DPKGParser alloc] init];
	NSArray* installed = [p parseDatabaseAtPath:kIcyDPKGStatusDatabasePath];
	NSMutableArray* seenPackages = [NSMutableArray arrayWithCapacity:0];
	[self _addPackageDeps:package withInstalledPackages:installed andParser:p seenPackages:seenPackages];
	[p release];
	
	[deps sortUsingFunction:Dependencies_ArraySort context:nil];
	
	[self.tableView reloadData];
}

- (NSString*)package
{
	return nil;
}

- (void)_addPackageDeps:(NSString*)packageID withInstalledPackages:(NSArray*)installedPackages andParser:(DPKGParser*)parser seenPackages:(NSMutableArray*)seenPackages
{
	if ([seenPackages containsObject:packageID])
	{
		return;
	}
	
	[seenPackages addObject:packageID];

	NSDictionary* pack = [self _findPackage:packageID];
	
	if (!pack)
		return;
		
	if (![pack objectForKey:@"depends"] && ![pack objectForKey:@"pre-depends"])
		return;

	NSMutableArray* allDeps = [NSMutableArray arrayWithCapacity:2];
	if ([pack objectForKey:@"pre-depends"])
		[allDeps addObject:[pack objectForKey:@"pre-depends"]];

	if ([pack objectForKey:@"depends"])
		[allDeps addObject:[pack objectForKey:@"depends"]];
	
	if ([allDeps count])
	{
		NSArray* d = [parser dependencyFromString:[allDeps componentsJoinedByString:@", "] full:YES];
		for (NSDictionary* dep in d)
		{
			NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
			NSString* depID = [dep objectForKey:@"package"];
			
			if (![self _findInArray:deps packageID:depID])
			{
				NSMutableDictionary* depPackage = [self _findPackage:depID];
				if (depPackage)
				{
					if ([self _findInArray:installedPackages packageID:depID])
						[depPackage setObject:[NSNumber numberWithBool:YES] forKey:@"installed"];
						
					if ([dep objectForKey:@"version"])
						[depPackage setObject:[dep objectForKey:@"version"] forKey:@"version"];
					else
						[depPackage removeObjectForKey:@"version"];
						
					[deps addObject:depPackage];
				}
				else
				{
					NSMutableDictionary* newDict = [[NSMutableDictionary alloc] initWithCapacity:0];
					
					[newDict setObject:NSLocalizedString(@"", @"") forKey:@"section"];
					[newDict setObject:depID forKey:@"name"];
					[newDict setObject:depID forKey:@"package"];
					if ([dep objectForKey:@"version"])
						[newDict setObject:[dep objectForKey:@"version"] forKey:@"version"];
					
					[deps addObject:newDict];
					
					[newDict release];
				}
			}
			
			[self _addPackageDeps:depID withInstalledPackages:installedPackages andParser:parser seenPackages:seenPackages];
			[innerPool release];
		}
	}
}

- (NSDictionary*)_findInArray:(NSArray*)array packageID:(NSString*)packageID
{
	if (!array)
		return nil;

	for (NSDictionary* entry in array)
	{
		if ([[entry objectForKey:@"package"] isEqualToString:packageID])
			return entry;
	}
	
	return nil;
}

- (NSMutableDictionary*)_findPackage:(NSString*)packageID
{
	NSMutableDictionary* result = nil;
	
	Database* db = [Database database];
	ResultSet* rs = [db executeQuery:@"SELECT tag,data FROM meta WHERE identifier = ?", packageID];
	while (rs && [rs next])
	{
		if (!result)
		{
			result = [NSMutableDictionary dictionaryWithCapacity:0];
		}
		
		[result setObject:[rs stringForColumn:@"data"] forKey:[rs stringForColumn:@"tag"]];
	}
	
	[rs close];
	
	if (![result objectForKey:@"name"])
		[result setObject:[result objectForKey:@"package"] forKey:@"name"];

	return result;
}
@end

static NSInteger Dependencies_ArraySort(NSDictionary* d1, NSDictionary* d2, void *context)
{
	NSString* n1 = [d1 objectForKey:@"name"];
	NSString* n2 = [d2 objectForKey:@"name"];
	
	return [n1 compare:n2 options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch)];
}
