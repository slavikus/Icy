//
//  DepictionController.h
//  Icy
//
//  Created by Slava Karpenko on 3/30/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PackageInfoController;

@interface DepictionController : UIViewController<UIWebViewDelegate> {
	NSURL* url;
	
	IBOutlet PackageInfoController* packageInfoController;
}

@property (nonatomic, retain) NSURL* url;

@end
