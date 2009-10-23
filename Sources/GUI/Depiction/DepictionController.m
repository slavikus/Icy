//
//  DepictionController.m
//  Icy
//
//  Created by Slava Karpenko on 3/30/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

//#import <objc/objc-runtime.h>
#import "DepictionController.h"
#import "NSURLRequest+RipdevExtensions.h"
#import "NSString+RipdevExtensions.h"
#import "PackageInfoController.h"
#import "Database.h"

@implementation DepictionController
@synthesize url;

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
	
	NSObject *dView; // webDocumentView
	NSObject *wView;
	dView = objc_msgSend(self.view, @selector(_documentView));
	object_getInstanceVariable(dView, "_webView",(void**)&wView);
	objc_msgSend(wView, @selector(setPolicyDelegate:),self);
}

- (void)viewWillAppear:(BOOL)animated
{
	((UIWebView*)self.view).delegate = self;
	if (self.url)
	{
		UIWebView* wv = (UIWebView*)self.view;
		NSURLRequest* req = [NSURLRequest requestWithCydiaURL:self.url];
		[wv loadRequest:req];
	}
	
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	((UIWebView*)self.view).delegate = nil;
	[(UIWebView*)self.view stopLoading];
	[(UIWebView*)self.view loadHTMLString:@"<html/>" baseURL:nil];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	
	[(UIWebView*)self.view stopLoading];
	[(UIWebView*)self.view loadHTMLString:@"<html/>" baseURL:nil];
}


- (void)dealloc {
	self.url = nil;
    [super dealloc];
}

#pragma mark -

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

- (void)webView:(NSObject*)sender decidePolicyForNewWindowAction:(NSDictionary*)info request:(NSURLRequest*)request newFrameName:(id) frame decisionListener:(id)listener
{
	NSURL* _url = [request URL];

	objc_msgSend(listener, @selector(ignore));
	
	if ([[_url scheme] isEqualToString:@"cydia"] ||
		[[_url scheme] isEqualToString:@"apptapp"])
	{
		if ([[_url host] isEqualToString:@"package"])
		{
			NSString* packageID = [_url path];
			if ([packageID hasPrefix:@"/"])
				packageID = [packageID substringFromIndex:1];
				
			BOOL found = NO;
			
			ResultSet* rs = [[Database database] executeQuery:@"SELECT RowID, name, version, identifier FROM packages WHERE identifier = ?", packageID];
			if (rs && [rs next])
			{
				found = YES;
				
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
				
				packageInfoController.package = dict;
				[dict release];
			}
			
			[rs close];
			
			if (found)
			{
				[self.navigationController popViewControllerAnimated:YES];
			}
			else
			{
				NSString* text = [NSString stringWithFormat:NSLocalizedString(@"Package \"%@\" was not found.", @""), packageID];
				UIActionSheet* sheet = [[UIActionSheet alloc] initWithTitle:text delegate:nil cancelButtonTitle:nil destructiveButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
				[sheet showInView:self.view];
				[sheet release];
			}
		}
		
		return;
	}
	
	if ([[_url host] isEqualToString:@"phobos.apple.com"])
	{
		[[UIApplication sharedApplication] openURL:_url];
		return;
	}
	
	[(UIWebView*)self.view loadRequest:[NSURLRequest requestWithCydiaURL:_url]];
}

- (void) webView:(id)sender decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(id)frame decisionListener:(id)listener
{
	if (CFPreferencesGetAppBooleanValue(CFSTR("FilterAds"), CFSTR("com.ripdev.icy"), NULL) && 
		[[[request URL] scheme] hasPrefix:@"http"])
	{
		NSString* myHost = [[self.url host] hostName];
		NSString* theirHost = [[[request URL] host] hostName];
		
		// determine hostname
		if ([myHost compare:theirHost options:NSCaseInsensitiveSearch] != NSOrderedSame)
		{
			objc_msgSend(listener, @selector(ignore));
		}
	}
	
	objc_msgSend(listener, @selector(use));
}

@end
