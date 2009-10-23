//
//  SourcesTabBarItem.h
//  Icy
//
//  Created by Slava Karpenko on 4/19/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SourcesTabBarItem : UITabBarItem {
	UIActivityIndicatorView* progress;
}

@property (nonatomic, assign) BOOL progressEnabled;
@end
