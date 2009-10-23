//
//  DPKGInvocation.h
//  Icy
//
//  Created by Slava Karpenko on 3/21/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DPKGInvocation : NSObject {

}

-(int) invoke:(NSArray*) arguments;
-(int) invoke:(NSArray*) arguments fn:(int) fn;
-(int) invoke:(NSArray*) arguments errorInfo:(NSString**) errorInfo;

@end
