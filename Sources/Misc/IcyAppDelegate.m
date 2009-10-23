//
//  IcyAppDelegate.m
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright Ripdev 2009. All rights reserved.
//

#import <sys/stat.h>
#import "IcyAppDelegate.h"
#import "SchemaBuilder.h"
#import "InstalledController.h"
#import "CategoriesController.h"
#import "UpdatesSearchOperation.h"
#import "OperationQueue.h"
#import "SourcesController.h"
#import "Reachability.h"
#import "NSString+RipdevExtensions.h"
#import "StashController.h"

#define kIcyMinimumRefreshInterval (60.*60.)

static NSString* gStashableDirectories[] = {
#if defined(__i386__)
	@"/tmp/stashTest",
#else
    @"/Applications",
    @"/Library/Ringtones",
    @"/Library/Wallpaper",
    @"/usr/share",
#endif
	nil
};

@implementation IcyAppDelegate

@synthesize window;
@synthesize tabBarController;
@synthesize themeDefinition;

- (void)awakeFromNib
{
	NSString* path = [[NSBundle mainBundle] pathForResource:@"IcyThemeDefinition" ofType:@"plist"];
	
	if (path)
	{
		self.themeDefinition = [NSDictionary dictionaryWithContentsOfFile:path];
	}
	
	if (self.themeDefinition)
	{
		NSString* sbStyle = [themeDefinition objectForKey:@"StatusBarStyle"];
		if (sbStyle)
		{
			if ([sbStyle isEqualToString:@"black"])
				[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
			else if ([sbStyle isEqualToString:@"white"])
				[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
			else if ([sbStyle isEqualToString:@"transparent"])
				[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackTranslucent;
			else
				[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
		}
	}
	else
		[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
		
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	NSString* lastStashVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"StashOSVersion"];
	if (!lastStashVersion || ![lastStashVersion isEqualToString:[UIDevice currentDevice].systemVersion])
	{
		int i;
		NSMutableArray* toStash = nil;
		// check whether we need stashing

		for (i=0; gStashableDirectories[i]; i++)
		{
			struct stat st;
			
			if (lstat([gStashableDirectories[i] fileSystemRepresentation], &st))
			{
				// create directory
				continue;
			}
			
			if ((st.st_mode & S_IFMT) == S_IFLNK)
			{
				continue;
			}
			
			if (!toStash)
				toStash = [NSMutableArray arrayWithCapacity:0];
			
			[toStash addObject:gStashableDirectories[i]];
		}
		
		if (toStash && [toStash count])
		{
			StashController* stash = [[StashController alloc] initWithNibName:@"Stash" bundle:nil];
			
			[stash viewDidLoad];
		
			[[NSUserDefaults standardUserDefaults] setObject:[UIDevice currentDevice].systemVersion forKey:@"StashOSVersion"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[stash stashDirectories:toStash];
		
			return;
		}
	}

    // Add the tab bar controller's current view as a subview of the window
    [window addSubview:tabBarController.view];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedPackagesUpdated:) name:kIcyUpdatedPackagesUpdatedNotification object:nil];
	
	[sourcesController performSelector:@selector(checkSources:) withObject:nil afterDelay:.5];
	
	// refresh update counts
	UpdatesSearchOperation* us = [[UpdatesSearchOperation alloc] init];
	[[OperationQueue sharedQueue] addOperation:us];
	[us release];
	
	// check last refresh date
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoRefreshOnWiFi"])
	{
		NetworkStatus st = [[Reachability sharedReachability] internetConnectionStatus];
		if (st == ReachableViaWiFiNetwork)
		{
			NSDate* lastRefresh = [[NSUserDefaults standardUserDefaults] objectForKey:@"last-refresh"];
			
			if (!lastRefresh || (abs([lastRefresh timeIntervalSinceNow]) >= kIcyMinimumRefreshInterval))
			{
				[sourcesController performSelector:@selector(doRefresh:) withObject:nil afterDelay:1.5];
			}
		}
	}
}


// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
	UIViewController* ctrl = nil;
	NSArray* stack = nil;
	
	if ([viewController isKindOfClass:[UINavigationController class]])
		stack = ((UINavigationController*)viewController).viewControllers;
	
	if ([stack count])
		ctrl = [stack objectAtIndex:0];
	
	if (ctrl && [ctrl isKindOfClass:[InstalledController class]])
	{
		[(UINavigationController*)viewController popToRootViewControllerAnimated:NO];
	}
	else if (ctrl && [ctrl isKindOfClass:[CategoriesController class]] && [stack count] > 2)
	{
		if ([stack count] > 3)
			[(UINavigationController*)viewController popViewControllerAnimated:NO];
		[(UINavigationController*)viewController popViewControllerAnimated:NO];
	}
}

/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/


- (void)dealloc {
    [tabBarController release];
    [window release];
    [super dealloc];
}

- (void)updatedPackagesUpdated:(NSNotification*)notification
{
	NSArray* packages = [notification object];
	
	if ([packages count])
		updatedTabBarItem.badgeValue = [NSString stringWithFormat:@"%d", [packages count]];
	else
		updatedTabBarItem.badgeValue = nil;

	[installedController preSetup:packages];
}

@end

