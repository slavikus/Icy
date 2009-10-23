#import "Database.h"

static Database* gSharedDatabase = nil;

@implementation Database

@synthesize db;

+ (Database*)sharedDatabase
{
	if (!gSharedDatabase)
		gSharedDatabase = [[Database alloc] initWithPath:kIcyDatabasePath];
		
	return gSharedDatabase;
}

+ (Database*)database
{
	return [[[Database alloc] initWithPath:kIcyDatabasePath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
    self = [super init];
	
    if (self) {
        databasePath = [aPath copy];
        db           = nil;
        logsErrors   = YES;
		
		if (![self open])
			NSLog(@"Database: cannot open the database!");

#if !defined(INSTALLER_APP) && !defined(__i386__)
		if (![[[[NSFileManager defaultManager] fileAttributesAtPath:aPath traverseLink:YES] fileOwnerAccountName] isEqualToString:@"mobile"])
			[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:@"mobile", NSFileOwnerAccountName, @"mobile", NSFileGroupOwnerAccountName, nil]
											ofItemAtPath:aPath error:nil];
#endif
    }
	
	return self;
}

- (sqlite3*)db
{
	return db;
}

- (void)dealloc {
	[self close];
	[databasePath release];
	[super dealloc];
}

+ (NSString*)sqliteLibVersion; {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

- (BOOL)open {
	int err = sqlite3_open( [databasePath fileSystemRepresentation], &db );
	if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
		return NO;
	}
	
	//[self executeUpdate:@"PRAGMA synchronous = NORMAL;"];
	//[self executeUpdate:@"PRAGMA read_uncommitted = 1;"];
	
	return YES;
}

- (void)close {
	if (!db) {
        return;
    }
    
	//[self executeUpdate:@"ROLLBACK TRANSACTION;"];
	
	int err = sqlite3_close(db);
		
	if(err != SQLITE_OK)
	{
        NSLog(@"error closing!: %d", err);
	}
    
	db = nil;
}

- (NSString*)lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(db)];
}

- (int)lastErrorCode {
    return sqlite3_errcode(db);
}

- (sqlite_int64)lastInsertRowId {
    return sqlite3_last_insert_rowid(db);
}

- (sqlite_int64)affectedRows
{
	return sqlite3_changes(db);
}

- (id)executeQuery:(NSString*)objs, ...; {
    
    ResultSet *rs = nil;
    
    NSString *sql = objs;
    int rc;
    sqlite3_stmt *pStmt;
    
    // use sqlite3_bind_parameter_count , thanks to it being pointed out by Dominic Yu
    
	//NSLog(@"Q: %@", sql);
    rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
    if (rc != SQLITE_OK && rc != SQLITE_BUSY)
	{
        rc = sqlite3_finalize(pStmt);
        
        if (logsErrors) {
            NSLog(@"DB Error: %d \"%@\" (%@)", [self lastErrorCode], [self lastErrorMessage], sql);
        }
        
        return nil;
    }
	
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    va_list argList;
    va_start(argList, objs);
    
    while (idx < queryCount) {
        
        obj = va_arg(argList, id);
        idx++;
        
        // FIXME - someday check the return codes on these binds.
        
        if ([obj isKindOfClass:[NSData class]]) {
            rc = sqlite3_bind_blob(pStmt, idx, [obj bytes], [(NSData*)obj length], SQLITE_TRANSIENT);
        }
		else if (!obj || [obj isKindOfClass:[NSNull class]])		// Allow NULL values to be inserted in form of nil or [NSNull null]
		{
			rc = sqlite3_bind_null(pStmt, idx);
		}
		else if ([obj isKindOfClass:[NSNumber class]])
		{
			rc = sqlite3_bind_int(pStmt, idx, [obj intValue]);
		}
        else if ([obj isKindOfClass:[NSDate class]]) {
            rc = sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
        }
		else if ([obj isKindOfClass:[NSURL class]]) {
            rc = sqlite3_bind_text(pStmt, idx, [[obj absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
        }		
        else {
            rc = sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_TRANSIENT);
        }
		
		if (rc != SQLITE_OK)
		{
			NSLog(@"DB bind error for %@ (%@) = #%d", sql, obj, rc);
		}
    }
    
    va_end(argList);
    
    // the statement gets close in rs's dealloc or [rs close];
    rs = [ResultSet resultSetWithStatement:pStmt];
	
	[rs setQuery:sql];		// mostly for debug purposes
    
    return rs;
}


- (int)executeUpdate:(NSString*)objs, ...;{
    
    NSString *sql = objs;
    int rc;
    sqlite3_stmt *pStmt;
	
	//NSLog(@"U: %@", sql);
    
	rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
	
	if( rc != SQLITE_OK && rc != SQLITE_BUSY )
	{
        int ret = rc;
        rc = sqlite3_finalize(pStmt);
         if (logsErrors) {
            NSLog(@"DB Error: %d \"%@\" (%@)", [self lastErrorCode], [self lastErrorMessage], sql);
        }
        
        return ret;
    }

	id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    va_list argList;
    va_start(argList, objs);
    
    while (idx < queryCount) {
        
        obj = va_arg(argList, id);
        idx++;
        
		if ([obj isKindOfClass:[NSArray class]])
		{
			NSData* serialized = [NSPropertyListSerialization dataFromPropertyList:obj format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
			
			if (serialized)
				rc = sqlite3_bind_blob(pStmt, idx, [serialized bytes], [(NSData*)serialized length], SQLITE_TRANSIENT);
			else
				rc = sqlite3_bind_null(pStmt, idx);
		}
		else if ([obj isKindOfClass:[NSData class]]) {
            rc = sqlite3_bind_blob(pStmt, idx, [obj bytes], [(NSData*)obj length], SQLITE_TRANSIENT);
        }
		else if (!obj || [obj isKindOfClass:[NSNull class]])		// Allow NULL values to be inserted in form of nil or [NSNull null]
		{
			rc = sqlite3_bind_null(pStmt, idx);
		}
		else if ([obj isKindOfClass:[NSNumber class]])
		{
			rc = sqlite3_bind_int(pStmt, idx, [obj intValue]);
		}
        else if ([obj isKindOfClass:[NSDate class]]) {
            rc = sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
        }
		else if ([obj isKindOfClass:[NSURL class]]) {
            rc = sqlite3_bind_text(pStmt, idx, [[obj absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
        }		
        else {
            rc = sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_TRANSIENT);
        }

		if (rc != SQLITE_OK)
		{
			NSLog(@"DB bind error for %@ (%@) = #%d", sql, obj, rc);
		}

    }
    
    va_end(argList);
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
    ** executed is not a SELECT statement, we assume no data will be returned.
    */
	do
	{
		rc = sqlite3_step(pStmt);
			
		if (SQLITE_BUSY == rc)
		{
			usleep(20);
		}
	} while (SQLITE_BUSY == rc);

    if (rc == SQLITE_BUSY)
		return rc;
		
	if (rc != SQLITE_OK && rc != SQLITE_DONE)
	{
		NSLog(@"db error: %@ = #%d", sql, rc);
	}
	
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    rc = sqlite3_finalize(pStmt);
    return rc;
}

- (int)executeUpdate:(NSString*)query withArray:(NSArray*)objs
{
    
    NSString *sql = query;
    int rc;
    sqlite3_stmt *pStmt;
    
	//NSLog(@"U: %@", sql);
	
	rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
	
	if( rc != SQLITE_OK && rc != SQLITE_BUSY )
	{
        int ret = rc;
        rc = sqlite3_finalize(pStmt);
         if (logsErrors) {
            NSLog(@"DB Error: %d \"%@\" (%@)", [self lastErrorCode], [self lastErrorMessage], sql);
        }
        
        return ret;
    }

    int idx = 0;

    
    for (id obj in objs) {
        
        idx++;
        
		if ([obj isKindOfClass:[NSArray class]])
		{
			NSData* serialized = [NSPropertyListSerialization dataFromPropertyList:obj format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
			
			if (serialized)
				sqlite3_bind_blob(pStmt, idx, [serialized bytes], [(NSData*)serialized length], SQLITE_TRANSIENT);
			else
				sqlite3_bind_null(pStmt, idx);
		}
		else if ([obj isKindOfClass:[NSData class]]) {
            sqlite3_bind_blob(pStmt, idx, [obj bytes], [(NSData*)obj length], SQLITE_TRANSIENT);
        }
		else if (!obj || [obj isKindOfClass:[NSNull class]])		// Allow NULL values to be inserted in form of nil or [NSNull null]
		{
			sqlite3_bind_null(pStmt, idx);
		}
        else if ([obj isKindOfClass:[NSDate class]]) {
            sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
        }
		else if ([obj isKindOfClass:[NSNumber class]])
		{
			sqlite3_bind_int(pStmt, idx, [obj intValue]);
		}
		else if ([obj isKindOfClass:[NSURL class]]) {
            sqlite3_bind_text(pStmt, idx, [[obj absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
        }		
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_TRANSIENT);
        }
    }
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
    ** executed is not a SELECT statement, we assume no data will be returned.
    */
	do
	{
		rc = sqlite3_step(pStmt);

		if (SQLITE_BUSY == rc)
		{
			usleep(20);
		}
	} while (SQLITE_BUSY == rc);
	
    if (rc == SQLITE_BUSY)
		return rc;

	assert( rc!=SQLITE_ROW );
    
		
	if (rc != SQLITE_OK && rc != SQLITE_DONE)
	{
		NSLog(@"db error: %@ = #%d", sql, rc);
	}
    
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    rc = sqlite3_finalize(pStmt);
    return rc;
}

- (BOOL)rollback; {
    return ([self executeUpdate:@"ROLLBACK TRANSACTION;", nil] == SQLITE_OK);
}

- (BOOL)commit; {
	//if (logsErrors)
	//	NSLog(@"[commit transaction (%@)]", [databasePath lastPathComponent]);
	int rc = [self executeUpdate:@"COMMIT TRANSACTION;"];
	
	if (rc != SQLITE_OK)
		NSLog(@"Commit error: %d (%@)", rc, [self lastErrorMessage]);
		
    return (rc == SQLITE_OK);
}

- (BOOL)beginTransaction; {	
	//if (logsErrors)
	//	NSLog(@"[begin transaction (%@)]", [databasePath lastPathComponent]);
		
	int rc = [self executeUpdate:@"BEGIN DEFERRED TRANSACTION;"];
	
	if (rc != SQLITE_OK)
		NSLog(@"Begin transaction error: %d (%@)", rc, [self lastErrorMessage]);

    return (rc == SQLITE_OK);
}

- (BOOL)logsErrors {
    return logsErrors;
}

- (void)setLogsErrors:(BOOL)flag {
    logsErrors = flag;
}

@end
