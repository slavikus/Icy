//
//  RecentsController.m
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "RecentsController.h"
#import "Database.h"
#import "PackageInfoController.h"
#import "SearchController.h"
#import "NSDate+RipdevExtensions.h"
#import "IcyAppDelegate.h"

static UIImage* gPackageImage = nil;

@implementation RecentsController
@synthesize rebuildPackages;

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
	else
		cellTextColor = nil;
	// ~Theme support

	packages = [[NSMutableArray alloc] initWithCapacity:0];
	sections = [[NSMutableArray alloc] initWithCapacity:0];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(doSearch:)] autorelease];
}

- (void)doSearch:(id)sender
{
	[self.navigationController pushViewController:searchController animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	self.navigationItem.title = NSLocalizedString(@"Recent Packages", @"");
	
	if (self.rebuildPackages)
	{
		[packages removeAllObjects];
		[sections removeAllObjects];
		[self.tableView reloadData];
		[NSThread detachNewThreadSelector:@selector(buildRecent:) toTarget:self withObject:nil];
	}
}

- (void)buildRecent:(id)sender
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[self _rebuildPackages:0];
	[pool release];
}

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
	NSUInteger sectionCount = [sections count];
	
    return sectionCount ? sectionCount : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section    // fixed font style. use custom view (UILabel) if you want something different
{
	if (![sections count])
		return nil;
		
	NSString* title = [[sections objectAtIndex:section] objectForKey:@"title"];
	if (!title)
	{
		title = [[[sections objectAtIndex:section] objectForKey:@"ts"] relativeDateString];
		[[sections objectAtIndex:section] setObject:title forKey:@"title"];
	}
	
	return title;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (![sections count])
		return 0;
		
    NSUInteger packageFrom = [[[sections objectAtIndex:section] objectForKey:@"start"] unsignedIntValue];
	NSUInteger packageTo = [packages count];
	
	if (section < [sections count]-1)
		packageTo = [[[sections objectAtIndex:section+1] objectForKey:@"start"] unsignedIntValue];
	
	if (section == [sections count]-1)
	{
		packageTo++;
	}
		
	return packageTo - packageFrom;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
	    
    // Set up the cell...
	NSUInteger pkgIdx = indexPath.row;
	if ([sections count])
	{
		pkgIdx += [[[sections objectAtIndex:indexPath.section] objectForKey:@"start"] unsignedIntValue];
	}
	
	if (pkgIdx >= [packages count])
	{
		UITableViewCell* mcell = [tableView dequeueReusableCellWithIdentifier:@"more"];
		if (mcell == nil) {
			mcell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"more"] autorelease];
			mcell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
			mcell.text = NSLocalizedString(@"More...", @"");
			mcell.textAlignment = UITextAlignmentCenter;
			mcell.textColor = [UIColor colorWithRed:.0 green:.0 blue:.7 alpha:1.];
			mcell.accessoryType = UITableViewCellAccessoryNone;
			mcell.image = nil;

			((UILabel*)([[mcell.contentView subviews] objectAtIndex:0])).textAlignment = UITextAlignmentCenter;
		 }
		 
		 return mcell;
	}

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		cell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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

	NSDictionary* package = [packages objectAtIndex:pkgIdx];
	
	UILabel* cat = nil;
	
	if ([[cell.contentView subviews] count] > 1)
		cat = [[cell.contentView subviews] objectAtIndex:[[cell.contentView subviews] count]-1];
	if (cat && [cat isKindOfClass:[UILabel class]])
		cat.text = [package objectForKey:@"section"];
	
	cell.text = [NSString stringWithFormat:@"%@ (%@)", [package objectForKey:@"name"], [package objectForKey:@"version"]];

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger pkgIdx = indexPath.row;
	if ([sections count])
	{
		pkgIdx += [[[sections objectAtIndex:indexPath.section] objectForKey:@"start"] unsignedIntValue];
	}
	
	if (pkgIdx >= [packages count])
	{
		// load more
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
		[self _rebuildPackages:[packages count]];
		return;
	}
	
	infoController.package = [packages objectAtIndex:pkgIdx];
	[self.navigationController pushViewController:infoController animated:YES];
}

- (void)dealloc {
	[cellTextColor release];
	[sections release];
	[packages release];
    [super dealloc];
}

#pragma mark  -

- (void)_rebuildPackages:(NSUInteger)offset
{
	NSUInteger packagesBefore = [packages count];
	
	Database* db = [Database database];
	
	ResultSet* rs = [db executeQuery:@"select packages.rowid AS id,package,category,created,memories.version AS version,memories.name AS name from memories, packages where packages.identifier = package AND category NOT IN (SELECT name FROM excluded_categories) group by package order by created desc limit ?,50", [NSNumber numberWithUnsignedInt:offset]];
	if (rs)
	{
		while ([rs next])
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			
			NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithCapacity:0];
			NSString* name = [rs stringForColumn:@"name"];
			NSString* version = [rs stringForColumn:@"version"];
			NSString* identifier = [rs stringForColumn:@"package"];
			NSString* sec = [rs stringForColumn:@"category"];
			
			[dict setObject:[NSNumber numberWithLongLong:[rs intForColumn:@"id"]] forKey:@"id"];
			if (name)
				[dict setObject:name forKey:@"name"];
			if (identifier)
				[dict setObject:identifier forKey:@"identifier"];
			if (version)
				[dict setObject:version forKey:@"version"];
			if (sec)
				[dict setObject:sec forKey:@"section"];
			
			NSDate* created = [NSDate dateWithTimeIntervalSince1970:[rs doubleForColumn:@"created"]];
			[dict setObject:created forKey:@"created"];
			
			[packages addObject:dict];
			[dict release];
			
			[pool release];
		}
	}
	
	[rs close];
	
	[self _rebuildCategories:packagesBefore];
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	
	self.rebuildPackages = NO;
}

- (void)_rebuildCategories:(NSUInteger)from
{
	NSTimeInterval lastTS = 0;
	NSUInteger i;
	
	NSDateFormatter *mdf = [[NSDateFormatter alloc] init];
	
	[mdf setDateFormat:@"yyyy-MM-dd"];
	NSDate *midnight = [mdf dateFromString:[mdf stringFromDate:[NSDate date]]];
	[mdf release];
	NSTimeInterval midnightInterval = [midnight timeIntervalSince1970];

	if (from)
		lastTS = [[[packages objectAtIndex:from-1] objectForKey:@"created"] timeIntervalSince1970];
	
	for (i=from;i < [packages count]; i++)
	{
		NSTimeInterval ts = [[[packages objectAtIndex:i] objectForKey:@"created"] timeIntervalSince1970];
		double limit = (60.*60.);
		
		if (ts < midnightInterval)
		{
			limit = (60.*60.*24.);
		}
		
		if (abs(ts - lastTS) >= limit)
		{
			// make a new section
			NSMutableDictionary* newSec = [[NSMutableDictionary alloc] initWithCapacity:0];
			
			[newSec setObject:[[packages objectAtIndex:i] objectForKey:@"created"] forKey:@"ts"];
			[newSec setObject:[NSNumber numberWithUnsignedInt:i] forKey:@"start"];
			
			[sections addObject:newSec];
			
			[newSec release];
			
			lastTS = ts;
		}
	}
}

@end

