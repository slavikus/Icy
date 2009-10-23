//
//  AboutController.m
//  Icy
//
//  Created by Slava Karpenko on 3/26/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "AboutController.h"
#import "AboutGradientBackgroundCell.h"
#import "IcyAppDelegate.h"

@implementation AboutController

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
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor_About"];
	if (!tintColor)
		tintColor = [ICY_APP.themeDefinition objectForKey:@"NavigationBarTintColor"];
	if (tintColor)
	{
		self.navigationController.navigationBar.tintColor = [tintColor colorRepresentation];
	}
	// ~Theme support

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	UIImage* dotty = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DottyBackground" ofType:@"png"]]];
	
	self.tableView.backgroundColor = [UIColor colorWithPatternImage:dotty];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	
	self.navigationItem.title = [NSString stringWithFormat:@"Icy %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
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
    return 2;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 1)
		return 4;
	
	return 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
 
	if (indexPath.section)
	{
		UITableViewCell *cell = nil;
		if (indexPath.row == 1)
		{
			cell = ripdevCell;
		}
		else if (indexPath.row == 3)
		{
			cell = creditsCell;
		}
		else
		{    
			cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
			}
			
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
	
		return cell;
	}
	
	UITableViewCell* prefsCell = [tableView dequeueReusableCellWithIdentifier:@"gradient"];
	if (prefsCell == nil)
	{
		prefsCell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"gradient"] autorelease];
		prefsCell.selectionStyle = UITableViewCellSelectionStyleNone;
		prefsCell.textColor = [UIColor whiteColor];
		prefsCell.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
		prefsCell.text = @" ";
		
		UILabel* lbl = ([[prefsCell.contentView subviews] count]) ? [[prefsCell.contentView subviews] objectAtIndex:0] : nil;
		if ([lbl isKindOfClass:[UILabel class]])
		{
			lbl.shadowColor = [UIColor blackColor];
			lbl.shadowOffset = CGSizeMake(-1,-1);
		}
	}
	
	UISwitch* sw = [[UISwitch alloc] initWithFrame:CGRectZero];
	[sw addTarget:self action:@selector(doAutoRefresh:) forControlEvents:UIControlEventValueChanged];
	
	[sw setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"AutoRefreshOnWiFi"] animated:NO];
	
	prefsCell.accessoryView = sw;
	[sw release];
	prefsCell.text = NSLocalizedString(@"Auto refresh on Wi-Fi", @"");
	
	return prefsCell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section)
	{
		if (indexPath.row == 1)
			return ripdevCell.frame.size.height;
		else if (indexPath.row == 3)
			return creditsCell.frame.size.height;
		
		return 30.;
	}
	
	return 40.;
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
    [super dealloc];
}

- (IBAction)doSendFeedback:(id)sender
{
	NSString* subject = [NSString stringWithFormat:@"Icy %@ for %@ %@ Feedback", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion];
	
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:support@ripdev.com?subject=%@", [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	
	[[UIApplication sharedApplication] openURL:url];
	
}

- (IBAction)doOpenWWW:(id)sender
{
	NSURL* url = [NSURL URLWithString:@"http://ripdev.com"];
	
	[[UIApplication sharedApplication] openURL:url];
}

- (void)doAutoRefresh:(UISwitch*)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"AutoRefreshOnWiFi"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

