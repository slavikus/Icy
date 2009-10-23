//
//  PackageInfoController.m
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "PackageInfoController.h"
#import "Database.h"
#import "NSNumber+RipdevExtensions.h"
#import "NSString+RipdevVersionCompare.h"
#import "InstallRemoveController.h"
#import "DPKGParser.h"
#import "DepictionController.h"
#import "DependenciesController.h"
#import "IcyAppDelegate.h"

@implementation PackageInfoController

@dynamic package;

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	[super viewDidLoad];
	
	/*
	UIImage* bgImage = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DottyBackground" ofType:@"png"]]];
	if (bgImage)
	{
		UIColor* bgColor = [UIColor colorWithPatternImage:bgImage];
		underView.backgroundColor = bgColor;
	}
	*/
	
	// create dependencies controller button
	if (!dependenciesButton)
	{
		dependenciesButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
		CGRect rect = dependenciesButton.frame;
		rect.origin.x = depictionButton.frame.origin.x;
		rect.origin.y = dependencies.frame.origin.y - 4.;
		dependenciesButton.frame = rect;
		dependenciesButton.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin);
		[self.view addSubview:dependenciesButton];		// we don't retain as the button will live as long as our view

		[dependenciesButton addTarget:self action:@selector(doShowDependencies:) forControlEvents:UIControlEventTouchUpInside];
	}

	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"PackageInfoBackgroundColor"];
	if (tintColor)
	{
		self.view.backgroundColor = [tintColor colorRepresentation];
	}
	else
		self.view.backgroundColor = [UIColor viewFlipsideBackgroundColor];
	// ~Theme support
}

- (void)viewWillAppear:(BOOL)animated    // Called when the view is about to made visible. Default does nothing
{
	if (shouldRefreshOnShow)
	{	
		shouldRefreshOnShow = NO;
		self.package = package;
	}
		
	[super viewWillAppear:animated];
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[package release];
	[dependenciesController release];
	
    [super dealloc];
}

#pragma mark -

- (void)setPackage:(NSDictionary*)pack
{
	[package release];
	package = [pack retain];
	
	self.navigationItem.title = [pack objectForKey:@"name"]?[pack objectForKey:@"name"]:[pack objectForKey:@"package"];
	
	// Set up other fields
	name.text = self.navigationItem.title;
	version.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Version", @""), [pack objectForKey:@"version"]];
	description.text = [self getProperty:@"description"];
	size.text = [self getProperty:@"size"];
	
	NSString* tag = [self getProperty:@"tag"];
	if (tag && [tag rangeOfString:@"cydia::commercial"].length)
	{
		description.text = [NSString stringWithFormat:@"%@\n\n%@", description.text, NSLocalizedString(@"!! This is a commercial package. If you have not previously purchased it, it will not be able to download.", @"")];
	}
	
	NSString* auth = [self getProperty:@"author"];
	if (auth)
	{
		NSRange openBrace = [auth rangeOfString:@" <"];
		if (openBrace.length)
		{
			auth = [auth substringToIndex:openBrace.location];
		}
		
		author.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Author", @""), auth];
		authorMailButton.alpha = 1.;
	}
	else
	{
		author.text = nil;
		authorMailButton.alpha = .0;
	}
	
	NSString* maint = [self getProperty:@"maintainer"];
	if (maint)
	{
		NSRange openBrace = [maint rangeOfString:@" <"];
		if (openBrace.length)
		{
			maint = [maint substringToIndex:openBrace.location];
		}

		maintainer.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Maintainer", @""), maint];
		maintainerMailButton.alpha = 1.;
	}
	else
	{
		maintainer.text = nil;
		maintainerMailButton.alpha = .0;
	}
	
	int totalDeps = 0;
	
	NSString* deps = [self getProperty:@"depends"];
	if (deps)
		totalDeps += [[deps componentsSeparatedByString:@","] count];

	deps = [self getProperty:@"pre-depends"];
	if (deps)
		totalDeps += [[deps componentsSeparatedByString:@","] count];
		
	if (totalDeps)
	{
		dependencies.text = [NSString stringWithFormat:@"%d %@", totalDeps, totalDeps > 1 ? NSLocalizedString(@"Direct Dependencies", @"") : NSLocalizedString(@"Direct Dependency", @"")];
		dependenciesButton.hidden = NO;
	}
	else
	{
		dependencies.text = nil;
		dependenciesButton.hidden = YES;
	}
	
	if ([self getProperty:@"depiction"] || [self getProperty:@"homepage"] || [self getProperty:@"website"])
	{
		depictionButton.hidden = NO;
	}
	else
	{
		depictionButton.hidden = YES;
	}
	
	if ([pack objectForKey:@"status"])
	{
		// this is an installed package
		UIBarButtonItem* iButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Remove", @"") style:UIBarButtonItemStyleDone target:self action:@selector(doRemove:)];
		self.navigationItem.rightBarButtonItem = iButton;
		[iButton release];
	}
	else
	{
		// check whether this package is already installed
		DPKGParser* parser = [[DPKGParser alloc] init];
		NSArray* packs = [parser parseDatabaseAtPath:kIcyDPKGStatusDatabasePath];
		[parser release];
		
		BOOL found = NO;
		NSString* myPackage = [self getProperty:@"package"];
		NSString* foundVersion = nil;
		
		for (NSDictionary* p in packs)
		{
			if ([[p objectForKey:@"package"] isEqualToString:myPackage])
			{
				// already installed, let's break
				foundVersion = [p objectForKey:@"version"];
				found = YES;
				break;
			}
		}
		
		NSString* buttonTitle = NSLocalizedString(@"Install", @"");
		if (found)
		{
			if ([foundVersion compareWithVersion:[pack objectForKey:@"version"] operation:@"lt"])
				buttonTitle = NSLocalizedString(@"Upgrade", @"");
			else
				buttonTitle = NSLocalizedString(@"Reinstall", @"");
				
			version.text = [NSString stringWithFormat:@"%@: %@ (%@ %@)", NSLocalizedString(@"Version", @""), [pack objectForKey:@"version"], NSLocalizedString(@"have", @""), foundVersion];
		}

		UIBarButtonItem* iButton = [[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleDone target:self action:@selector(doInstall:)];
		self.navigationItem.rightBarButtonItem = iButton;
		[iButton release];
	}
}

- (NSDictionary*)package
{
	return package;
}

#pragma mark -

- (IBAction)doInstall:(id)sender
{
	installRemoveController.identifiers = [NSArray arrayWithObject:[self getProperty:@"package"]];
	installRemoveController.remove = NO;
	
	[installRemoveController doFlip:self];
	shouldRefreshOnShow = YES;
}

- (IBAction)doRemove:(id)sender
{
	installRemoveController.identifiers = [NSArray arrayWithObject:[package objectForKey:@"package"]];
	installRemoveController.remove = YES;
	
	[installRemoveController doFlip:self];
}

- (IBAction)doMailAuthor:(id)sender
{
	NSString* maint = [self getProperty:@"author"];
	if (maint)
	{
		NSRange openBrace = [maint rangeOfString:@" <"];
		if (openBrace.length)
		{
			NSString* email = nil;
			
			email = [maint substringFromIndex:openBrace.location+openBrace.length];
			email = [email substringToIndex:[email length]-1];
			
			NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@", email, [[NSString stringWithFormat:@"Regarding package \"%@\"", self.navigationItem.title] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
			[[UIApplication sharedApplication] openURL:url];
		}
	}
}

- (IBAction)doMailMaintainer:(id)sender
{
	NSString* maint = [self getProperty:@"maintainer"];
	if (maint)
	{
		NSRange openBrace = [maint rangeOfString:@" <"];
		if (openBrace.length)
		{
			NSString* email = nil;
			
			email = [maint substringFromIndex:openBrace.location+openBrace.length];
			email = [email substringToIndex:[email length]-1];
			
			NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@", email, [[NSString stringWithFormat:@"Regarding package \"%@\"", self.navigationItem.title] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
			[[UIApplication sharedApplication] openURL:url];
		}
	}
}

#pragma mark -

- (IBAction)doDepiction:(id)sender
{
	NSString* depictionURL = [self getProperty:@"depiction"];
	
	if (!depictionURL)
		depictionURL = [self getProperty:@"homepage"];
	
	if (!depictionURL)
		depictionURL = [self getProperty:@"website"];
	
	if (depictionURL)
		depictionController.url = [NSURL URLWithString:depictionURL];
	
	depictionController.navigationItem.title = self.navigationItem.title;
	
	[self.navigationController pushViewController:depictionController animated:YES];
}

#pragma mark -

- (NSString*)getProperty:(NSString*)_name
{
	if ([package objectForKey:_name])
	{
		if ([_name isEqualToString:@"size"])
		{
			return [[NSNumber numberWithInt:[[package objectForKey:_name] intValue]] byteSizeDescription];
		}
		else
			return [package objectForKey:_name];
	}
		
	Database* db = [Database sharedDatabase];
	ResultSet* rs = [db executeQuery:@"SELECT data FROM meta WHERE identifier = ? AND tag = ?", [package objectForKey:@"identifier"], _name];
	NSString* result = nil;
	
	if (rs && [rs next])
	{
		result = [rs stringForColumn:@"data"];
		
		if ([_name isEqualToString:@"size"])
			result = [[NSNumber numberWithInt:[rs intForColumn:@"data"]] byteSizeDescription];
	}
	
	[rs close];
	
	return result;
}

#pragma mark -

- (void)doShowDependencies:(id)sender
{
	if (!dependenciesController)
		dependenciesController = [[DependenciesController alloc] initWithStyle:UITableViewStylePlain];
	
	dependenciesController.package = [self getProperty:@"package"];
	//[dependenciesController doToggle:self.navigationController.view];
	[self.navigationController pushViewController:dependenciesController animated:YES];
}

@end
