//
//  DPKGParser.h
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DPKGParser : NSObject {
}

- (NSArray*)parseDatabaseAtPath:(NSString*)path;
- (NSArray*)parseDatabaseAtPath:(NSString*)path ignoreStatus:(BOOL)ignoreStatus;
- (NSMutableArray*)dependencyFromString:(NSString*)string;							// NSArray* of NSStrings (package)
- (NSMutableArray*)dependencyFromString:(NSString*)string full:(BOOL)full;			// NSArray* of NSDictionaries [ "package", "version" ]
@end
