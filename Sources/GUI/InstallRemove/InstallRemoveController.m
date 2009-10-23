//
//  InstallRemoveController.m
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "InstallRemoveController.h"
#import "DEBInstallOperation.h"
#import "DEBRemoveOperation.h"
#import "OperationQueue.h"
#import "Database.h"
#import "IcyAppDelegate.h"

extern UIImage* _UIImageWithName(NSString* name) WEAK_IMPORT_ATTRIBUTE;

@implementation InstallRemoveController

@synthesize remove;
@dynamic identifiers;
@synthesize delegate;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"InstallBackgroundColor"];
	if (tintColor)
	{
		self.view.backgroundColor = [tintColor colorRepresentation];
	}
	else
		self.view.backgroundColor = [UIColor viewFlipsideBackgroundColor];
	// ~Theme support

	[rootTabBarController retain];
	
	statusMarqueeOrigin = statusMarquee.frame.origin;
	progressViewOrigin = progressView.frame.origin;
	progressView2Origin = progressView2.frame.origin;
	cancelButtonOrigin = cancelButton.frame.origin;
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[dpkgError release];
	[dpkgErrorPackageID release];
	[identifiers release];
	[rootTabBarController release];
    [super dealloc];
}

#pragma mark -

- (IBAction)doCancel:(id)sender
{
	[currentOperation cancel];
}

- (IBAction)doReturn:(id)sender
{
	[activityIndicator stopAnimating];
	
	// see if we need to transition back
	if (self.remove)
	{
		UINavigationController* uic = [rootTabBarController.viewControllers objectAtIndex:2];
		if (uic)
			[uic popToRootViewControllerAnimated:NO];
	}
	
	if ([self.delegate respondsToSelector:@selector(_rebuildInstalledPackages)])
		[self.delegate performSelector:@selector(_rebuildInstalledPackages)];
	
	[self doFlip:sender];
}

- (IBAction)doFlip:(id)sender
{
    UIView *mainView = rootTabBarController.view;
    UIView *flipsideView = self.view;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:1];
    [UIView setAnimationTransition:([mainView superview] ? UIViewAnimationTransitionFlipFromRight : UIViewAnimationTransitionFlipFromLeft) forView:rootWindow cache:YES];
    
	self.delegate = nil;
	
    if ([mainView superview] != nil) {
		self.delegate = sender;
        //[self viewWillAppear:YES];
        [rootTabBarController viewWillDisappear:YES];
        [mainView removeFromSuperview];
        [rootWindow addSubview:flipsideView];
        [rootTabBarController viewDidDisappear:YES];
        //[self viewDidAppear:YES];
    } else {
        [rootTabBarController viewWillAppear:YES];
        //[self viewWillDisappear:YES];
        [flipsideView removeFromSuperview];
		[rootWindow addSubview:mainView];
		//[self viewDidDisappear:YES];
        [rootTabBarController viewDidAppear:YES];
    }
    [UIView commitAnimations];
}

#pragma mark -

- (NSArray*)identifiers
{
	return identifiers;
}

- (void)setIdentifiers:(NSArray*)ident
{
	[identifiers release];
	identifiers = [ident retain];
	
	mCurrentPhase = 0;
	statusPreparing.alpha = .2;
	statusDownloading.alpha = .2;
	statusInstalling.alpha = .2;
	statusFinishing.alpha = .2;
	statusRemoving.alpha = .2;
	
	CGRect frame = statusMarquee.frame;
	frame.origin.x = statusMarqueeOrigin.x - 34.;
	statusMarquee.frame = frame;
	statusMarquee.alpha = 0.;
	
	statusText.text = @"";
	labelText.text = @"";
	
	progressView.alpha = .0;
	progressView2.alpha = .0;
	
	activityIndicator.alpha = .0;
	cancelButton.alpha = 1.;
	
	frame = cancelButton.frame;
	frame.origin = cancelButtonOrigin;
	cancelButton.frame = frame;
}

#pragma mark -

- (void)viewWillAppear:(BOOL)animated
{
	if (self.remove)
		[self setRemovePhase];
	else
		[self setInstallPhase];
		
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	[self advancePhase];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}

#pragma mark -

- (void)advancePhase
{
	static UIImageView* sPhases[2][5] = { nil };
	if (!sPhases[0][0])
	{
		sPhases[0][0] = statusPreparing;
		sPhases[0][1] = statusDownloading;
		sPhases[0][2] = statusInstalling;
		sPhases[0][3] = statusFinishing;

		sPhases[1][0] = statusPreparing;
		sPhases[1][1] = statusRemoving;
		sPhases[1][2] = statusFinishing;

	}
	
	if (!sPhases[remove][mCurrentPhase])
		mCurrentPhase = 0;
		
	if (!remove && mCurrentPhase == 2)
	{
		currentOperation = nil;
		[activityIndicator startAnimating];
	}
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.75];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	if (!mCurrentPhase)
		[UIView setAnimationDelay:1.];
	
	CGRect marqueeFrame = statusMarquee.frame;
	if (mCurrentPhase)
	{
		marqueeFrame.origin.x += (remove ? 102. : 68.);
	}
	else
	{
		marqueeFrame.origin = statusMarqueeOrigin;
	}
	statusMarquee.frame = marqueeFrame;
	statusMarquee.alpha = 1.;
	
	sPhases[remove][mCurrentPhase].alpha = 1.;
	statusText.alpha = .0;
	
	if (!remove && mCurrentPhase == 2)
	{
		CGRect fr = cancelButton.frame;
		fr.origin.y += 30.;
		cancelButton.frame = fr;
		cancelButton.alpha = .0;
		
		activityIndicator.alpha = 1.;
	}
	
	[UIView commitAnimations];

	mCurrentPhase++;
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	static NSString* sPhaseDescriptions[2][5] = { nil };
	
	if (!sPhaseDescriptions[0][0])
	{
		sPhaseDescriptions[0][0] = [NSLocalizedString(@"Preparing", @"") retain];
		sPhaseDescriptions[0][1] = [NSLocalizedString(@"Downloading", @"") retain];
		sPhaseDescriptions[0][2] = [NSLocalizedString(@"Installing", @"") retain];
		sPhaseDescriptions[0][3] = [NSLocalizedString(@"Finishing", @"") retain];

		sPhaseDescriptions[1][0] = [NSLocalizedString(@"Preparing", @"") retain];
		sPhaseDescriptions[1][1] = [NSLocalizedString(@"Removing", @"") retain];
		sPhaseDescriptions[1][2] = [NSLocalizedString(@"Finishing", @"") retain];
	}
	
	statusText.text = sPhaseDescriptions[remove][mCurrentPhase-1];

	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
		
	statusText.alpha = 1.;
	[UIView commitAnimations];

	if (mCurrentPhase == 1)			// preparing
	{
		if (self.remove)
		{
			DEBRemoveOperation* op = [[DEBRemoveOperation alloc] initWithPackageID:[identifiers objectAtIndex:0] installUninstallController:self];
			[[OperationQueue sharedQueue] addOperation:op];
			[op release];
		}
		else
		{
			DEBInstallOperation* op = [[DEBInstallOperation alloc] initWithPackageIDs:identifiers installUninstallController:self];
			[[OperationQueue sharedQueue] addOperation:op];
			currentOperation = op;
			[op release];
		}
	}
}

#pragma mark -

- (void)setRemovePhase
{
	statusDownloading.hidden = YES;
	statusInstalling.hidden = YES;
	statusRemoving.hidden = NO;

	cancelButton.alpha = .0;
	activityIndicator.alpha = 1.;
	[activityIndicator startAnimating];
}

- (void)setInstallPhase
{
	statusDownloading.hidden = NO;
	statusInstalling.hidden = NO;
	statusRemoving.hidden = YES;
}

#pragma mark -

- (void)setLabel:(NSString*)label
{
	labelText.text = label;
}

- (void)showProgressBar:(BOOL)show
{
	if (show && progressView.alpha > 0)
		return;
	else if (!show && progressView.alpha == .0)
		return;
		
	if (show)
		progressView.progress = .0;
		
	CGRect frame = progressView.frame;
	
	if (show)
	{
		frame.origin = progressViewOrigin;
		frame.origin.y += 20.;
		
		progressView.frame = frame;
	}
		
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.2];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	
	if (show)
	{
		frame.origin = progressViewOrigin;
		
		progressView.alpha = 1.;
	}
	else
	{
		frame.origin = progressViewOrigin;
		frame.origin.y += 20.;
		
		progressView.alpha = .0;
	}
	
	progressView.frame = frame;
	
	[UIView commitAnimations];
}

- (void)showProgressBar2:(BOOL)show
{
	if (show && progressView2.alpha > 0)
		return;
	else if (!show && progressView2.alpha == .0)
		return;
		
	if (show)
		progressView2.progress = .0;
		
	CGRect frame = progressView2.frame;
	
	if (show)
	{
		frame.origin = progressView2Origin;
		frame.origin.y += 20.;
		
		progressView2.frame = frame;
	}
		
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:.2];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	
	if (show)
	{
		frame.origin = progressView2Origin;
		
		progressView2.alpha = 1.;
	}
	else
	{
		frame.origin = progressView2Origin;
		frame.origin.y += 20.;
		
		progressView2.alpha = .0;
	}
	
	progressView2.frame = frame;
	
	[UIView commitAnimations];
}

- (void)setProgress:(float)progress
{
	progressView.progress = progress;
}

- (void)setProgress2:(float)progress
{
	progressView2.progress = progress;
}

- (void)failWithError:(NSError*)error
{
	currentOperation = nil;
	
	NSString* text = [error localizedDescription];
	
	NSString* otherButtonTitle = nil;
	
	if ([error localizedFailureReason])
	{
		otherButtonTitle = NSLocalizedString(@"View Console Log", @"");
		if (dpkgError)
			[dpkgError release];
		if (dpkgErrorPackageID)
			[dpkgErrorPackageID release];
			
		dpkgErrorPackageID = [[[error userInfo] objectForKey:@"packageID"] retain];
			
		dpkgError = [[error localizedFailureReason] retain];
	}
	
	UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle:text delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:otherButtonTitle, nil];
	[sheet setTag:otherButtonTitle?0:1];
	[sheet showInView:self.view];
	[sheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex  // after animation
{
	if (![actionSheet tag])
	{
		if (!buttonIndex)
		{
			// show the console log
			UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle:dpkgError delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:nil];
			[sheet setTag:1];
			
			// Add an "email" button
			
			if (dpkgErrorPackageID)
			{
				CGRect viewFrame = self.view.frame;
				
				UIButton* bbi = [UIButton buttonWithType:UIButtonTypeCustom];
				
				bbi.frame = CGRectMake(viewFrame.origin.x + viewFrame.size.width - 40, 10, 30, 30);
				[bbi addTarget:self action:@selector(doMailDPKGError:) forControlEvents:UIControlEventTouchUpInside];
				UIImage* buttonImage = nil;
				
				if (_UIImageWithName)
					buttonImage = _UIImageWithName(@"UIButtonBarCompose.png");
				
				if (!buttonImage)
					buttonImage = [UIImage imageNamed:@"About.png"];
					
				[bbi setImage:buttonImage forState:UIControlStateNormal];
				[sheet addSubview:bbi];
			}
			
			[sheet showInView:self.view];
			[sheet release];
		}
		else
			[self doReturn:nil];
	}
	else
	{
		[self doReturn:nil];
	}
}

- (NSDictionary*)_findPackage:(NSString*)packageID
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
	
	// Fetch the package URL
	rs = [db executeQuery:@"SELECT sources.url AS url FROM sources,packages WHERE sources.RowID = packages.source AND packages.identifier = ?", packageID];
	if (rs && [rs next])
	{
		NSURL* baseURL = nil;
		
		if ([rs stringForColumn:@"url"])
			baseURL = [NSURL URLWithString:[rs stringForColumn:@"url"]];
		
		NSURL* url = nil;
		
		if (baseURL && [result objectForKey:@"filename"])
		{
			// fix up url so it's relative to the repo
			NSString* filename = [result objectForKey:@"filename"];
			if ([filename hasPrefix:@"/"] && [filename length] > 1)
				filename = [filename substringFromIndex:1];
				
			url = [NSURL URLWithString:filename relativeToURL:baseURL];
		}
		
		if (url)
			[result setObject:url forKey:@"url"];
	}
	[rs close];
	
	return result;
}

- (void)doMailDPKGError:(id)sender
{
	if (!dpkgErrorPackageID)
		return;

	NSDictionary* package = [self _findPackage:dpkgErrorPackageID];
	if (!package)
		return;
		
	NSString* maintainer = [package objectForKey:@"maintainer"];
	if (!maintainer)
		maintainer = [package objectForKey:@"author"];
	
	if (!maintainer)
		return;
		
	NSRange openBrace = [maintainer rangeOfString:@" <"];
	if (openBrace.length)
	{
		NSString* email = nil;
		NSString* errorText = nil;
	
		email = [maintainer substringFromIndex:openBrace.location+openBrace.length];
		email = [email substringToIndex:[email length]-1];
		
		errorText= [NSString stringWithFormat:@"Device: %@\nFirmware: %@\n\n%@", [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion, dpkgError];

		NSString* body = [errorText stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		NSLog(@"body = %@", errorText);
		
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@&cc=support@ripdev.com&body=%@", email, [[NSString stringWithFormat:@"DPKG Error for package \"%@\"", dpkgErrorPackageID] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], body]];
		
		[[UIApplication sharedApplication] openURL:url];
	}
}

@end
