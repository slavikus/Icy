//
//  StashController.h
//  Icy
//
//  Created by Slava Karpenko on 5/30/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface StashController : UIViewController <UIActionSheetDelegate> {
	IBOutlet UIProgressView*			progress;
	IBOutlet UIActivityIndicatorView*	spinner;
	IBOutlet UILabel*					status;
	IBOutlet UILabel*					caption;
}

- (void)stashDirectories:(NSArray*)dirs;
- (void)_stash:(NSString*)dir;

@end
