//
//  DEBRemoveOperation.m
//  Icy
//
//  Created by Slava Karpenko on 3/22/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "DEBRemoveOperation.h"
#import "DPKGParser.h"
#import "DPKGInvocation.h"
#import "MobileInstallationBuilder.h"
#import "UpdatesSearchOperation.h"
#import "OperationQueue.h"
#import "InstallRemoveController.h"

#define  DEBRemoveOperationErrorDomain @"com.ripdev.icy.deb-remove"
enum {
	kDEBErrorHasOrphans = 1,
	kDEBErrorIsRestricted,
	kDEBErrorRemoveFailed,
	
};

SystemSoundID gDoneSoundID = 0;

@implementation DEBRemoveOperation

- initWithPackageID:(NSString*)packageID installUninstallController:(InstallRemoveController*)iuController
{
	if (self = [super init])
	{
		mPackageID = [packageID copy];
		mController = iuController;
	}
	
	return self;
}

- (void)dealloc
{
	[mPackageID release];
	[super dealloc];
}

#pragma mark -

- (void)main
{
	if ([mPackageID isEqualToString:@"dpkg"] ||
		[mPackageID isEqualToString:@"firmware"])
	{
		NSDictionary* userErr = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" can't be removed as it is absolutely required for Icy to function.", @""), mPackageID] forKey:NSLocalizedDescriptionKey];
		NSError* error = [NSError errorWithDomain:DEBRemoveOperationErrorDomain code:kDEBErrorIsRestricted userInfo:userErr];
		
		[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
		return;
	}

	DPKGParser* parser = [[DPKGParser alloc] init];
	NSArray* installedPackages = [parser parseDatabaseAtPath:kIcyDPKGStatusDatabasePath];
	
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Analyzing dependencies...", @"") waitUntilDone:YES];
	
	BOOL hasPotentialPoorHomelessOrphans = NO;
	NSMutableArray* dePacks = [NSMutableArray arrayWithCapacity:0];
	
	NSDictionary* pack = [self _findInArray:installedPackages packageID:mPackageID];
	NSArray* packDepends = nil;
	
	if (pack && [pack objectForKey:@"depends"])
		packDepends = [parser dependencyFromString:[pack objectForKey:@"depends"]];

	for (NSDictionary* p in installedPackages)
	{
		if ([packDepends containsObject:[p objectForKey:@"package"]])
		{
			continue;
		}
		
		NSString* deps = [p objectForKey:@"depends"];
		if (deps)
		{
			NSArray* depends = [parser dependencyFromString:deps];
			if (depends && [depends containsObject:mPackageID])
			{
				hasPotentialPoorHomelessOrphans = YES;
				
				if (![dePacks containsObject:[p objectForKey:@"package"]])
					[dePacks addObject:[p objectForKey:@"package"]];
			}
		}

		if (!hasPotentialPoorHomelessOrphans)
		{
			deps = [p objectForKey:@"pre-depends"];
			if (deps)
			{
				NSArray* depends = [parser dependencyFromString:deps];
				if (depends && [depends containsObject:mPackageID])
				{
					hasPotentialPoorHomelessOrphans = YES;
					if (![dePacks containsObject:[p objectForKey:@"package"]])
						[dePacks addObject:[p objectForKey:@"package"]];
				}
			}
		}
	}

	[parser release];
	parser = nil;
	
	if (hasPotentialPoorHomelessOrphans)
	{
		NSString* depPackages = [dePacks componentsJoinedByString:@", "];
		
		NSDictionary* userErr = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" can't be removed as there are other packages that depend on it:\n%@", @""), mPackageID, depPackages] forKey:NSLocalizedDescriptionKey];
		NSError* error = [NSError errorWithDomain:DEBRemoveOperationErrorDomain code:kDEBErrorHasOrphans userInfo:userErr];
		
		[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
		return;
	}
	
	// check for essential flag
	if (pack)
	{
		if ([pack objectForKey:@"essential"])
		{
			if ([[pack objectForKey:@"essential"] compare:@"yes" options:NSCaseInsensitiveSearch] == NSOrderedSame)
			{
				// This is an essential package...
				forceEssential = NO;
				waitingOnEssentialDecision = YES;
				
				UIActionSheet* essentialSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"This package is marked as Essential and is considered crucial for the system operation. You can still forcibly remove it but doing so may render your system unusable. Please only do so if you know what you are doing.", @"")  delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:NSLocalizedString(@"Force Remove", @"") otherButtonTitles:nil];
				[essentialSheet showInView:mController.view];
				[essentialSheet release];
			}
		}
	}
	
	if (waitingOnEssentialDecision)
	{
		while (waitingOnEssentialDecision)
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
			
			[pool release];
		}
		
		if (!forceEssential)
		{
			[mController performSelectorOnMainThread:@selector(doReturn:) withObject:nil waitUntilDone:NO];
			return;
		}
	}
	
	
	[mController performSelectorOnMainThread:@selector(advancePhase) withObject:nil waitUntilDone:YES];
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:mPackageID waitUntilDone:YES];
	
	// Now, let's remove
	DPKGInvocation* i = [[DPKGInvocation alloc] init];
	NSArray* args = nil;
	
	if (forceEssential)
		args = [NSArray arrayWithObjects:@"--force-remove-essential,depends", @"-P", mPackageID, nil];
	else
		args = [NSArray arrayWithObjects:@"--force-depends", @"-P", mPackageID, nil];
		
	NSString* err = nil;
	int rc = [i invoke:args errorInfo:&err];
	[i release];
	i = nil;
	
	if (rc != 0)
	{
		NSDictionary* userErr = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" cannot be removed (DPKG returned error #%d). More information can probably be found in the console log.", @""), mPackageID, rc], NSLocalizedDescriptionKey,
																			err, NSLocalizedFailureReasonErrorKey,
																			mPackageID, @"packageID", nil];
		NSError* error = [NSError errorWithDomain:DEBRemoveOperationErrorDomain code:kDEBErrorRemoveFailed userInfo:userErr];
		[mController performSelectorOnMainThread:@selector(failWithError:) withObject:error waitUntilDone:YES];
		return;
	}
	
	// Clean up
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Cleaning up...", @"") waitUntilDone:YES];
	[mController performSelectorOnMainThread:@selector(advancePhase) withObject:nil waitUntilDone:YES];
	
	[[[MobileInstallationBuilder alloc] init] release];
	UpdatesSearchOperation* us = [[UpdatesSearchOperation alloc] init];
	[[OperationQueue sharedQueue] performSelectorOnMainThread:@selector(addOperation:) withObject:us waitUntilDone:YES];
	[us release];
	
	sleep(1);
	
	if (!gDoneSoundID)
	{
		NSString* soundPath = [[NSBundle mainBundle] pathForResource:@"Done" ofType:@"caf"];
		if (soundPath)
		{
			NSURL* afUrl = [NSURL fileURLWithPath:soundPath];
			AudioServicesCreateSystemSoundID((CFURLRef)afUrl, &gDoneSoundID);
		}
	}

	if (gDoneSoundID)
		AudioServicesPlaySystemSound(gDoneSoundID);
		
	[mController performSelectorOnMainThread:@selector(setLabel:) withObject:NSLocalizedString(@"Done", @"") waitUntilDone:YES];
	[mController performSelectorOnMainThread:@selector(doReturn:) withObject:nil waitUntilDone:NO];
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

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex  // after animation
{
	forceEssential = !buttonIndex;
	
	waitingOnEssentialDecision = NO;
}
@end
