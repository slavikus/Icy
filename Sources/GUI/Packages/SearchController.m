//
//  SearchController.m
//  Icy
//
//  Created by Slava Karpenko on 3/26/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "SearchController.h"
#import "Database.h"
#import "PackageInfoController.h"
#import "SearchController.h"
#import "IcyAppDelegate.h"

static UIImage* gPackageImage = nil;

@implementation SearchController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor_Search"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor"];
	if (tintColor)
	{
		tableView.backgroundColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor_Search"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor"];
	if (tintColor)
	{
		if (![tintColor length])
			tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		tableView.separatorColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor_Search"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor"];
	if (tintColor)
		cellTextColor = [[tintColor colorRepresentation] retain];
	else
		cellTextColor = nil;
	// ~Theme support

	packages = [[NSMutableArray alloc] initWithCapacity:0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	self.navigationItem.title = NSLocalizedString(@"Search All", @"");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	
	if (![searchBar.text length])
		[searchBar becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [packages count];;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:CellIdentifier];
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

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(updateSearch) withObject:nil afterDelay:0.75];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb
{
	[sb resignFirstResponder];
	[self updateSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)sb
{
	[sb resignFirstResponder];
	[self updateSearch];
}

- (void)updateSearch
{
	NSString* searchText = searchBar.text;
	
	if (!searchText || [searchText length] < 2)
	{
		[packages removeAllObjects];
		[tableView reloadData];
		return;
	}

	[packages removeAllObjects];
	
	Database* db = [Database sharedDatabase];
	
	ResultSet* rs = [db executeQuery:@"SELECT packages.RowID, packages.name, packages.version, packages.identifier FROM packages where packages.identifier in (select meta.identifier from meta WHERE (meta.tag='name' OR meta.tag='description') AND meta.data like ?) ORDER BY name ASC;", [NSString stringWithFormat:@"%%%@%%", searchText]];
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
	
	[tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	infoController.package = [packages objectAtIndex:indexPath.row];
	[self.navigationController pushViewController:infoController animated:YES];
}

@end
