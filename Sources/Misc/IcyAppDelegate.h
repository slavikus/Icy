//
//  IcyAppDelegate.h
//  Icy
//
//  Created by Slava Karpenko on 3/14/09.
//  Copyright Ripdev 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSString+RipdevExtensions.h"

#define ICY_APP ((IcyAppDelegate*)[UIApplication sharedApplication].delegate)

@class SourcesController;
@class InstalledController;

@interface IcyAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate> {
    UIWindow *window;
    UITabBarController *tabBarController;
	
	NSDictionary* themeDefinition;
	
	IBOutlet UITabBarItem* updatedTabBarItem;
	IBOutlet SourcesController* sourcesController;
	IBOutlet InstalledController* installedController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (retain) NSDictionary* themeDefinition;
@end
