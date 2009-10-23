//
//  NSFileManager+RipdevExtensions.h
//  Installer
//
//  Created by Slava Karpenko on 3/10/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

@interface NSFileManager (RipdevExtensions)
- (NSString*)tempFilePath;
- (BOOL)copyPath:(NSString *)source toPath:(NSString *)destination handler:(id)handler;
@end
