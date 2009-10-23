//
//  AboutController.h
//  Icy
//
//  Created by Slava Karpenko on 3/26/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface AboutController : UITableViewController {
	IBOutlet UITableViewCell*		ripdevCell;
	IBOutlet UITableViewCell*		creditsCell;
}

- (IBAction)doSendFeedback:(id)sender;
- (IBAction)doOpenWWW:(id)sender;

@end
