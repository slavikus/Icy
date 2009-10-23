//
//  SchemaBuilder.m
//  Installer
//
//  Created by Slava Karpenko on 3/12/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <sqlite3.h>
#import "SchemaBuilder.h"
#import "Database.h"

@interface SchemaBuilder (SchemaBuilderPrivate)
- (void)_checkSchema;
@end


@implementation SchemaBuilder

- (id)init
{
	if (self = [super init])
	{
		[self _checkSchema];
	}
	
	return self;
}

- (void)_checkSchema
{
	NSString* schemaPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DatabaseSchema" ofType:@"plist"];
	
	if (!schemaPath)
		return;
		
	NSArray* schema = [NSArray arrayWithContentsOfFile:schemaPath];

	int schemaVersion = 0;
	Database* db = [Database sharedDatabase];
	
	ResultSet* res = [db executeQuery:@"PRAGMA user_version"];
	if (res && [res next])
	{
		schemaVersion = [res intForColumn:@"user_version"];
	
		[res close];
	}
	
	if (schemaVersion < [schema count])
	{
		int start = schemaVersion;
		
		for (int i=start; i < [schema count]; i++)
		{
			NSString* query = [schema objectAtIndex:i];
			
			int rc = [db executeUpdate:query];
			if (rc != SQLITE_OK)
				NSLog(@"Schema bump to #%d (%@) failed: %d", i, query, rc);
		}
		
		// Store the new schema version
		[db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %d", [schema count]]];
	}
}

@end
