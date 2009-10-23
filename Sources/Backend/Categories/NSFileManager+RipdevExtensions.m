//
//  NSFileManager+RipdevExtensions.m
//  Installer
//
//  Created by Slava Karpenko on 3/10/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "NSFileManager+RipdevExtensions.h"

@implementation NSFileManager (RipdevExtensions)

- (BOOL)copyPath:(NSString *)source toPath:(NSString *)destination handler:(id)handler
{
	BOOL result = YES;
	BOOL isDirectory = NO;

	// this is new, hope its not buggy? TESTME
	NSString * destinationPath = [destination stringByDeletingLastPathComponent];
	if(![self fileExistsAtPath:destination]) { // Create the folder?
			NSNumber* posixPerms = [NSNumber numberWithLong:(0000755)];

			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
							posixPerms,	NSFilePosixPermissions,
							@"root", NSFileOwnerAccountName,
							@"wheel", NSFileGroupOwnerAccountName,
							nil];

		if(![self createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:attributes error:nil]) return NO;
	}

	if([self fileExistsAtPath:source isDirectory:&isDirectory]) {
		NSDictionary * attributes = [self fileAttributesAtPath:source traverseLink:NO];

		if(isDirectory) {
			[self createDirectoryAtPath:destination attributes:attributes];

			NSEnumerator * subpaths = [[self subpathsAtPath:source] objectEnumerator];
			NSString * subpath;

			while((subpath = [subpaths nextObject])) {
				NSString * sourcePath = [source stringByAppendingPathComponent:subpath];
				NSString * destinationPath = [destination stringByAppendingPathComponent:subpath];

				if([self fileExistsAtPath:sourcePath isDirectory:&isDirectory]) {
					attributes = [self fileAttributesAtPath:sourcePath traverseLink:NO];
					if(isDirectory) { // Directory
						result = [self createDirectoryAtPath:destinationPath attributes:attributes];
					} else { // File
						NSData * contents = [NSData dataWithContentsOfMappedFile:sourcePath];
						result = [self createFileAtPath:destinationPath contents:contents attributes:attributes];
					}
				}

				if(!result) {
					NSLog(@"Error copying path: %@ to path: %@", sourcePath, destinationPath);
					break;
				}
			}
		} else {
			NSData * contents = [NSData dataWithContentsOfMappedFile:source];
			result = [self createFileAtPath:destination contents:contents attributes:attributes];
		}
	}

	return result;
}

- (NSString*)tempFilePath
{
	char* filename = tempnam([self fileSystemRepresentationWithPath:NSTemporaryDirectory()], "Icy-");
	
	if (filename)
	{
		NSString* filePath = [self stringWithFileSystemRepresentation:filename length:strlen(filename)];
		
		free(filename);
		
		return filePath;
	}
	
	return nil;
}

@end
