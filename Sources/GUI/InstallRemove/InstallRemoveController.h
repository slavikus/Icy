//
//  InstallRemoveController.h
//  Icy
//
//  Created by Slava Karpenko on 3/15/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface InstallRemoveController : UIViewController <UIActionSheetDelegate> {
	IBOutlet UIWindow* rootWindow;
	IBOutlet UITabBarController* rootTabBarController;
	
	IBOutlet UIImageView* statusPreparing;
	IBOutlet UIImageView* statusDownloading;
	IBOutlet UIImageView* statusInstalling;
	IBOutlet UIImageView* statusFinishing;
	IBOutlet UIImageView* statusRemoving;
	IBOutlet UIImageView* statusMarquee;
	
	IBOutlet UILabel* statusText;
	IBOutlet UILabel* labelText;
	IBOutlet UIProgressView* progressView;
	IBOutlet UIProgressView* progressView2;
	
	IBOutlet UIButton* cancelButton;
	IBOutlet UIActivityIndicatorView* activityIndicator;
	
	int			mCurrentPhase;
	
	NSArray*	identifiers;
	BOOL		remove;
	
	id			delegate;
	
	@private
		NSMutableArray* list;
		CGPoint			statusMarqueeOrigin;
		CGPoint			progressViewOrigin;
		CGPoint			progressView2Origin;
		CGPoint			cancelButtonOrigin;
		
		NSOperation*	currentOperation;
		
		NSString*		dpkgError;
		NSString*		dpkgErrorPackageID;
}

@property (retain, nonatomic) NSArray* identifiers;
@property (assign, nonatomic) BOOL remove;
@property (assign, nonatomic) id delegate;

- (IBAction)doReturn:(id)sender;
- (IBAction)doFlip:(id)sender;
- (IBAction)doCancel:(id)sender;

- (void)advancePhase;

- (void)setLabel:(NSString*)label;
- (void)showProgressBar:(BOOL)show;
- (void)showProgressBar2:(BOOL)show;

- (void)setProgress:(float)progress;
- (void)setProgress2:(float)progress;

- (void)failWithError:(NSError*)error;

- (void)setRemovePhase;
- (void)setInstallPhase;

- (NSDictionary*)_findPackage:(NSString*)packageID;
@end
