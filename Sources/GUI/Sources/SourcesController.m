//
//  SourcesController.m
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "SourcesController.h"
#import "ResultSet.h"
#import "Database.h"

#import "PackagesURLSearchOperation.h"
#import "SourceRefreshOperation.h"
#import "SourceIndexDownloadOperation.h"

#import "CategoriesController.h"
#import "OperationQueue.h"

#import "UpdatesSearchOperation.h"

#import "SourcesTabBarItem.h"

#import "IcyAppDelegate.h"

@interface UIAlertView (Extended)
	- (UITextField*)addTextFieldWithValue:(NSString*)value label:(NSString*)label;
	- (UITextField*)textFieldAtIndex:(NSUInteger)index;
	- (NSUInteger)textFieldCount;
	- (UITextField*)textField;
@end

@implementation SourcesController

- (void)viewDidLoad {
    [super viewDidLoad];

	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor_Sources"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor"];
	if (tintColor)
	{
		self.navigationController.navigationBar.tintColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor_Sources"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableBackgroundColor"];
	if (tintColor)
	{
		self.tableView.backgroundColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor_Sources"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableSeparatorColor"];
	if (tintColor)
	{
		if (![tintColor length])
			self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.tableView.separatorColor = [tintColor colorRepresentation];
	}

	tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor_Sources"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"TableTextColor"];
	if (tintColor)
		cellTextColor = [[tintColor colorRepresentation] retain];
	else
		cellTextColor = nil;
	// ~Theme support

    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated // Updates the appearance of the Edit|Done button item as necessary. Clients who override it must call super first.
{
	[super setEditing:editing animated:animated];
	
	if (editing)
	{
		UIBarButtonItem* add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doAdd:)];
		self.navigationItem.leftBarButtonItem = add;
		[add release];
	}
	else
	{
		UIBarButtonItem* refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(doRefresh:)];
		self.navigationItem.leftBarButtonItem = refresh;
		[refresh release];
	}
}

- (void)checkSources:(id)sender
{
	int sourceCount = -1;
	if (!sources)
		[self reloadSources];

	sourceCount = [sources count];
	
	Database* db = [Database sharedDatabase];

	if (sourceCount != 0)
		return;
		
	// Alrighty, let's pre-fill default sources
	NSArray* defaultSources = [NSArray arrayWithContentsOfURL:[NSURL URLWithString:@"http://apt.ripdev.com/sources.plist"]];
	if (defaultSources)
	{
		[db beginTransaction];
		// process sources
		for (NSDictionary* src in defaultSources)
		{
			if ([src objectForKey:@"e"] && [[src objectForKey:@"e"] boolValue])
			{
				if ([[Database sharedDatabase] executeUpdate:@"INSERT INTO sources ( url,pkgurl ) VALUES ( ?,? )", [src objectForKey:@"u"], [src objectForKey:@"p"]] == SQLITE_OK)
				{
					sqlite_int64 rowID = [[Database sharedDatabase] lastInsertRowId];
					
					NSNumber* rid = [[NSNumber alloc] initWithLongLong:rowID];
					NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:rid, @"id", [NSURL URLWithString:[src objectForKey:@"u"]], @"url", [NSURL URLWithString:[src objectForKey:@"p"]], @"pkgurl", nil];
					[rid release];
					[sources addObject:dict];
					[dict release];
				}
			}
		}
		
		[db commit];
	}

	[self.tableView reloadData];
	[self doRefresh:nil];
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
	if (!sources)
		[self reloadSources];
		
    return [sources count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
		
		cell.font = [UIFont systemFontOfSize:[UIFont buttonFontSize]];
		cell.image = [UIImage imageWithData:[NSData dataWithContentsOfMappedFile:[[NSBundle mainBundle] pathForResource:@"Sources" ofType:@"png"]]];
    }
    
    // Set up the cell...
	NSDictionary* source = [sources objectAtIndex:indexPath.row];
	cell.text = [[source objectForKey:@"url"] host];
	
	if ([source objectForKey:@"pkgurl"])
		cell.textColor = cellTextColor ? cellTextColor : [UIColor blackColor];
	else
		cell.textColor = [UIColor grayColor];
		
	if (refreshingSources && [refreshingSources containsObject:[source objectForKey:@"id"]])
	{
		UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		cell.accessoryView = spinner;
		[spinner startAnimating];
		[spinner release];
	}
	else
		cell.accessoryView = nil;

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.navigationItem.leftBarButtonItem.enabled;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		[self _removeSource:[sources objectAtIndex:indexPath.row]];
		[sources removeObjectAtIndex:indexPath.row];
		
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
	id moveableSource = [[sources objectAtIndex:sourceIndexPath.row] retain];
	[sources removeObjectAtIndex:sourceIndexPath.row];
	[sources insertObject:moveableSource atIndex:destinationIndexPath.row];
	[moveableSource release];
	
	// Re-index order
	Database* db = [Database database];
	
	[db beginTransaction];
	
	NSUInteger ord = 0;
	for (NSDictionary* src in sources)
	{
		NSNumber* sourceID = [src objectForKey:@"id"];
		
		[db executeUpdate:@"UPDATE sources SET ord = ? WHERE RowID = ?", [NSNumber numberWithUnsignedInt:ord++], sourceID];
	}
	
	[db commit];
}

- (void)dealloc {
	[refreshingSources release];
	[sources release];
    [super dealloc];
}

#pragma mark -

- (IBAction)doRefresh:(id)sender
{
	totalRefreshes = 0;
	
	if (sources && ![sources count])
		return;
	
	self.navigationItem.rightBarButtonItem.enabled = NO;
	self.navigationItem.leftBarButtonItem.enabled = NO;
	
	SourcesTabBarItem* tbi = (SourcesTabBarItem*)self.navigationController.tabBarItem;
	if ([tbi isKindOfClass:[SourcesTabBarItem class]])
	{
		tbi.progressEnabled = YES;
	}
	
	// Check if refresh operation is already alive
	CFMessagePortRef srPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSourceRefreshOperationPortName);
	if (srPort)
	{
		CFRelease(srPort);
	}
	else
	{
		SourceRefreshOperation* srefresh = [[SourceRefreshOperation alloc] initWithDelegate:self];
		[srefresh setQueuePriority:NSOperationQueuePriorityVeryHigh];
		[[OperationQueue sharedQueue] addOperation:srefresh];
		[srefresh release];
	}
	
	NSMutableArray* ops = [NSMutableArray arrayWithCapacity:[sources count]+1];
	{
		ResultSet* rs = [[Database sharedDatabase] executeQuery:@"SELECT RowID, pkgurl FROM sources"];
		
		while ([rs next])
		{
			NSURL* url = nil;
			
			if ([rs stringForColumn:@"pkgurl"])
				url = [NSURL URLWithString:[rs stringForColumn:@"pkgurl"]];
			else
				continue;
				
			SourceIndexDownloadOperation* op = [[SourceIndexDownloadOperation alloc] initWithSourceID:[rs intForColumn:@"rowid"] url:url delegate:self];
			[ops addObject:op];
			[op release];
		}
		
		[rs close];
	}
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	for (NSOperation* op in ops)
	{
		[[OperationQueue sharedQueue] addOperation:op];
	}	
}

- (IBAction)doAdd:(id)sender
{
	[self _invokePicker:sender];
}

- (IBAction)doCustomAdd:(id)sender
{
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Add Source", @"") message:NSLocalizedString(@"Please enter the source URL:", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Add", @""), nil];
	
	[alert addTextFieldWithValue:@"http://" label:nil];
	[alert textField].keyboardType = UIKeyboardTypeURL;
	[alert textField].autocorrectionType = UITextAutocorrectionTypeNo;
	
	[alert show];
	[alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex)
	{
		NSString* urlStr = [alertView textField].text;
		
		if (![urlStr hasSuffix:@"/"])
			urlStr = [urlStr stringByAppendingString:@"/"];
			
		NSURL* url = [NSURL URLWithString:urlStr];
		
		if (url && [url host])
		{
			[self _addSource:url];
		}
	}
}

#pragma mark -

- (void)reloadSources
{
	[sources release];
	
	// do full reload
	sources = [[NSMutableArray alloc] initWithCapacity:0];
	
	ResultSet* rs = [[Database sharedDatabase] executeQuery:@"SELECT RowID,url,pkgurl FROM sources ORDER BY ord ASC"];
	if (rs)
	{
		while ([rs next])
		{
			NSNumber* rowID = [[NSNumber alloc] initWithUnsignedInt:[rs intForColumn:@"rowid"]];
			NSURL* url = [[NSURL alloc] initWithString:[rs stringForColumn:@"url"]];
			NSString* purl = [rs stringForColumn:@"pkgurl"];
			
			id pkgurl = nil;
			
			if (!purl || ![purl length])
				pkgurl = [[NSNull null] retain];
			else
				pkgurl = [[NSURL alloc] initWithString:purl];
			
			NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:rowID, @"id", url, @"url", pkgurl, @"pkgurl", nil];
			
			[rowID release];
			[url release];
			[pkgurl release];
			
			[sources addObject:dict];
			[dict release];
		}
		
		[rs close];
	}
	
	[self.tableView reloadData];
}

- (NSDictionary*)sourceWithURL:(NSURL*)url
{
	NSDictionary* result = nil;
	
	ResultSet* rs = [[Database sharedDatabase] executeQuery:@"SELECT RowID,url,pkgurl FROM sources WHERE url = ?", [url absoluteString]];
	if (rs)
	{
		if ([rs next])
		{
			NSNumber* rowID = [[NSNumber alloc] initWithUnsignedInt:[rs intForColumn:@"rowid"]];
			NSURL* url = [[NSURL alloc] initWithString:[rs stringForColumn:@"url"]];
			NSURL* pkgurl = nil;
			
			if ([rs stringForColumn:@"pkgurl"])
				pkgurl = [[NSURL alloc] initWithString:[rs stringForColumn:@"pkgurl"]];
			else
				pkgurl = (NSURL*)[NSNull null];
				
			result = [[[NSDictionary alloc] initWithObjectsAndKeys:rowID, @"id", url, @"url", pkgurl, @"pkgurl", nil] autorelease];
			
			[rowID release];
			[url release];
			[pkgurl release];
			
		}
		
		[rs close];
	}
	
	return result;
}

- (void)_addSource:(NSURL*)url
{
	BOOL found = NO;
	
	// first check whether a source with this URL is already present
	ResultSet* rs = [[Database sharedDatabase] executeQuery:@"SELECT rowid FROM sources WHERE url = ?", [url absoluteString]];
	if (rs && [rs next])
	{
		found = YES;
	}
	
	[rs close];
	rs = nil;
	
	if (found)
	{
		NSLog(@"Source with URL %@ is already present.", url);
		return;
	}
	
	if ([[Database sharedDatabase] executeUpdate:@"INSERT INTO sources ( url ) VALUES ( ? )", url] == SQLITE_OK)
	{
		sqlite_int64 rowID = [[Database sharedDatabase] lastInsertRowId];
		
		NSNumber* rid = [[NSNumber alloc] initWithLongLong:rowID];
		NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:rid, @"id", url, @"url", nil];
		[rid release];
		[sources addObject:dict];
		[dict release];
		
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[sources count]-1 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
		
		// run test
		[PackagesURLSearchOperation enqueueForSource:rowID delegate:self];
	}
}

- (void)_removeSource:(NSDictionary*)source
{
	[[Database sharedDatabase] executeUpdate:@"DELETE FROM sources WHERE RowID = ?", [source objectForKey:@"id"]];
	// Our trigger will remove associated packages and meta-info as well.
	
	NSString* destPath = [kIcyIndexesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.idx", [[source objectForKey:@"id"] intValue]]];
	[[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
	
	categoriesController.reloadNeeded = YES;
}

- (NSInteger)indexForSource:(sqlite_int64)rowID
{
	for (NSDictionary* source in sources)
	{
		if ([[source objectForKey:@"id"] longLongValue] == rowID)
		{
			return [sources indexOfObject:source];
		}
	}
	
	return NSNotFound;
}

#pragma mark -

- (void)sourcePassedTests:(NSNumber*)rowID packagesPath:(NSString*)path packagesURL:(NSURL*)url
{
	NSInteger index = [self indexForSource:[rowID longLongValue]];
	if (index != NSNotFound)
	{
		NSDictionary* source = [sources objectAtIndex:index];
		
		NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:[source objectForKey:@"id"], @"id", [source objectForKey:@"url"], @"url", url, @"pkgurl", nil];
		
		[sources replaceObjectAtIndex:index withObject:dict];
		[self.tableView reloadData];
		
		// queue source refresh
		SourceRefreshOperation* srefresh = [[SourceRefreshOperation alloc] initWithDelegate:self];
		[[OperationQueue sharedQueue] addOperation:srefresh];
		[srefresh release];
	}
}

- (void)sourceFailedTests:(NSNumber*)rowID
{
	// find the source
	NSInteger index = [self indexForSource:[rowID longLongValue]];
	
	if (index != NSNotFound)
	{
		NSDictionary* source = [sources objectAtIndex:index];
		NSIndexPath* idx = [NSIndexPath indexPathForRow:index inSection:0];
		NSURL* url = [[source objectForKey:@"url"] retain];
		
		[self _removeSource:source];
		[sources removeObjectAtIndex:idx.row];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:idx] withRowAnimation:UITableViewRowAnimationFade];
		
		UIAlertView* alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bad Source", @"") message:[NSString stringWithFormat:NSLocalizedString(@"The source for the URL \"%@\" doesn't seems to be valid. It was not added.", @""), [url absoluteString]] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
		[alert show];
		[url release];
		[alert release];
	}
}

#pragma mark -

- (void)sourceRefreshStarted:(NSNumber*)rowID
{
	NSInteger index = [self indexForSource:[rowID longLongValue]];
	
	if (!refreshingSources)
		refreshingSources = [[NSMutableArray alloc] initWithCapacity:0];
			
	if (![refreshingSources containsObject:rowID])
		[refreshingSources addObject:rowID];
			
	if (index != NSNotFound)
	{
		UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		
		UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
		
		cell.accessoryView = spinner;
		[spinner startAnimating];
		[spinner release];
	}
}

- (void)sourceRefreshDone:(NSNumber*)rowID withError:(NSError*)error
{
	if (refreshingSources && [refreshingSources containsObject:rowID])
	{
		[refreshingSources removeObject:rowID];
		
		if (error && [error code] == 404)
		{
			[PackagesURLSearchOperation enqueueForSource:[rowID longLongValue] delegate:self];
		}
		
		if (![refreshingSources count])
		{
			[self sourceRefreshFinished];
			return;
		}
	}
	
	NSInteger index = [self indexForSource:[rowID longLongValue]];
	
	if (index != NSNotFound)
	{
		UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
		
		cell.accessoryView = nil;
	}
	
	if (!error)
		categoriesController.reloadNeeded = YES;
}

- (void)sourceRefreshFinished
{
	NSInteger i;
	
	for (i=0;i<[sources count];i++)
	{
		UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
		if (cell.accessoryView)
			cell.accessoryView = nil;
	}
	
	self.navigationItem.rightBarButtonItem.enabled = YES;
	self.navigationItem.leftBarButtonItem.enabled = YES;
		SourcesTabBarItem* tbi = (SourcesTabBarItem*)self.navigationController.tabBarItem;
	if ([tbi isKindOfClass:[SourcesTabBarItem class]])
	{
		tbi.progressEnabled = NO;
	}


	// Let categories controller know the reload is required
	categoriesController.reloadNeeded = YES;
	
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"last-refresh"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// spin off the updates checker
	UpdatesSearchOperation* us = [[UpdatesSearchOperation alloc] init];
	[[OperationQueue sharedQueue] addOperation:us];
	[us release];
}

#pragma mark -

- (void)_invokePicker:(id)sender
{
	CGRect frame = pickerContainer.frame;
	CGRect windowFrame = self.view.window.frame;
	
	if (!pickerSources)
		pickerSources = [[NSMutableArray alloc] initWithCapacity:0];
		
	[pickerSources removeAllObjects];
	
	frame.origin.y = windowFrame.origin.y + windowFrame.size.height;
	
	pickerContainer.frame = frame;
	pickerContainer.backgroundColor = [UIColor clearColor];
	
	[self.view.window addSubview:pickerContainer];
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];

	frame.origin.y = windowFrame.origin.y + windowFrame.size.height - frame.size.height;
	pickerContainer.frame = frame;
	
	[UIView commitAnimations];

	// Now load the sources
	NSArray* defaultSources = [NSArray arrayWithContentsOfURL:[NSURL URLWithString:@"http://apt.ripdev.com/sources.plist"]];
	if (defaultSources)
	{
		// process sources
		for (NSDictionary* src in defaultSources)
		{
			if (![self sourceWithURL:[NSURL URLWithString:[src objectForKey:@"u"]]])
			{
				[pickerSources addObject:src];
			}
		}
	}
		
	[pickerView reloadComponent:0];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	// fade animation
	pickerContainer.backgroundColor = [UIColor colorWithWhite:.0 alpha:.9];
}

- (IBAction)doPickerAdd:(id)sender
{
	NSUInteger idx = [pickerView selectedRowInComponent:0];
	
	if (!idx)
	{
		[self doCustomAdd:sender];
	}
	else
	{
		NSDictionary* src = [pickerSources objectAtIndex:idx-1];
		if (src)
		{
			if ([[Database sharedDatabase] executeUpdate:@"INSERT INTO sources ( url,pkgurl ) VALUES ( ?,? )", [src objectForKey:@"u"], [src objectForKey:@"p"]] == SQLITE_OK)
			{
				sqlite_int64 rowID = [[Database sharedDatabase] lastInsertRowId];
				
				NSNumber* rid = [[NSNumber alloc] initWithLongLong:rowID];
				NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:rid, @"id", [NSURL URLWithString:[src objectForKey:@"u"]], @"url", [NSURL URLWithString:[src objectForKey:@"p"]], @"pkgurl", nil];
				[rid release];
				[sources addObject:dict];
				[dict release];
				
				[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[sources count]-1 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
			
				[pickerSources removeObjectAtIndex:idx-1];
				[pickerView reloadComponent:0];
			}
		}
	}
}

- (IBAction)doPickerAddAll:(id)sender
{
	[[Database sharedDatabase] beginTransaction];
	for (NSDictionary* src in pickerSources)
	{
		if ([[Database sharedDatabase] executeUpdate:@"INSERT INTO sources ( url,pkgurl ) VALUES ( ?,? )", [src objectForKey:@"u"], [src objectForKey:@"p"]] == SQLITE_OK)
		{
			sqlite_int64 rowID = [[Database sharedDatabase] lastInsertRowId];
			
			NSNumber* rid = [[NSNumber alloc] initWithLongLong:rowID];
			NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:rid, @"id", [NSURL URLWithString:[src objectForKey:@"u"]], @"url", [NSURL URLWithString:[src objectForKey:@"p"]], @"pkgurl", nil];
			[rid release];
			[sources addObject:dict];
			[dict release];
		}
	}
	
	[[Database sharedDatabase] commit];
	
	[pickerSources removeAllObjects];
	
	[self.tableView reloadData];
	[pickerView reloadComponent:0];
}


- (IBAction)doPickerDone:(id)sender
{
	CGRect frame = pickerContainer.frame;
	CGRect windowFrame = self.view.window.frame;
	
	pickerContainer.backgroundColor = [UIColor clearColor];
	
	[self.view.window addSubview:pickerContainer];
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop2:finished:context:)];

	frame.origin.y = windowFrame.origin.y + windowFrame.size.height;
	pickerContainer.frame = frame;
	
	[UIView commitAnimations];
}

- (void)animationDidStop2:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	[pickerContainer removeFromSuperview];
}

#pragma mark -

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return 1 + [pickerSources count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	if (component == 0)
	{
		if (row == 0)
			return NSLocalizedString(@"Custom...", @"");
			
		return [[pickerSources objectAtIndex:row-1] objectForKey:@"t"];
	}
	
	return @"";
}

@end

