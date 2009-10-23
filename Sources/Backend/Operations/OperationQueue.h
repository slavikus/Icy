//
//  OperationQueue.h
//  Installer
//
//  Created by Slava Karpenko on 3/13/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface OperationQueue : NSOperationQueue {

}

+ (OperationQueue*)sharedQueue;

@end
