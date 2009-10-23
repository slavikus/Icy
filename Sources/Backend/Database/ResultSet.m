#import "ResultSet.h"

@interface ResultSet (Private)
- (NSMutableDictionary *)columnNameToIndexMap;
- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value;
@end

@implementation ResultSet

+ (id)resultSetWithStatement:(sqlite3_stmt *)stmt {
    
    ResultSet *rs = [[ResultSet alloc] init];
    
    [rs setPStmt:stmt];
    
    return [rs autorelease];
}

- (id)init {
    if(self = [super init]) {
        [self setColumnNameToIndexMap:[NSMutableDictionary dictionary]];
    }
	
	return self;
}


- (void)dealloc {
    [self close];
    
    [query autorelease];
    query = nil;
    
    [columnNameToIndexMap autorelease];
    columnNameToIndexMap = nil;
    
	[super dealloc];
}

- (void)close
{
    if (!pStmt) {
        return;
    }
    
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    int rc = sqlite3_finalize(pStmt);
    if (rc != SQLITE_OK) {
        NSLog(@"error finalizing for query: %@ (#%d)", [self query], rc);
    }
    
    pStmt = nil;
	
	//NSLog(@"0x%08X RS: CLOSE: %@", self, [self query]);
}

- (void)setupColumnNames {
    
    int columnCount = sqlite3_column_count(pStmt);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        [columnNameToIndexMap setObject:[NSNumber numberWithInt:columnIdx] forKey:[[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)] lowercaseString]];
    }
}

- (void)kvcMagic:(id)object {
    
    
    int columnCount = sqlite3_column_count(pStmt);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        
        
        const char *c = (const char *)sqlite3_column_text(pStmt, columnIdx);
        
        // check for a null row
        if (c) {
            NSString *s = [NSString stringWithUTF8String:c];
            
            [object setValue:s forKey:[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)]];
        }
    }
}

- (BOOL)next
{
    int rc = SQLITE_OK;
	
	BOOL debug_throttle = NO;
	do
	{
		rc = sqlite3_step(pStmt);
		
		if (SQLITE_BUSY == rc && !debug_throttle)
		{
			NSLog(@"Throttling on %@ (ATResultSet, SQLITE_BUSY)", query);
			debug_throttle = YES;
		}
		
		if (SQLITE_BUSY == rc)
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
			[pool release];
		}
	} while (rc == SQLITE_BUSY);
    
    if (!columnNamesSetup) {
        [self setupColumnNames];
    }
	
	if (rc != SQLITE_ROW && rc != SQLITE_DONE)
	{
		NSLog(@"Error in %@ = #%d", query, rc);
	}

	if (rc != SQLITE_ROW)			// close the query on last update
	{
		[self close];
	}
	
    return (rc == SQLITE_ROW);
}

- (int)columnIndexForName:(NSString*)columnName {
    
    NSNumber *n = [columnNameToIndexMap objectForKey:columnName];
    
    if (n) {
        return [n intValue];
    }
    
    NSLog(@"Warning: I could not find the column named '%@' (columns = %@). Make sure the column name is lowercase.", columnName, columnNameToIndexMap);
    
    return -1;
}



- (int)intForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return 0;
    }
    
    return sqlite3_column_int(pStmt, columnIdx);
}

- (BOOL)boolForColumn:(NSString*)columnName; {
    return ([self intForColumn:columnName] != 0);
}

- (double)doubleForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return 0;
    }
    
    return sqlite3_column_double(pStmt, columnIdx);
}

- (NSString*)stringForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    const char *c = (const char *)sqlite3_column_text(pStmt, columnIdx);
    
    if (!c) {
        // null row.
        return nil;
    }
    
    return [NSString stringWithUTF8String:c];
}


- (NSDate*)dateForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForColumn:columnName]];
}


- (NSData*)dataForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    int dataSize = sqlite3_column_bytes(pStmt, columnIdx);
    
    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
    
    memcpy([data mutableBytes], sqlite3_column_blob(pStmt, columnIdx), dataSize);
    
    return data;
}

- (sqlite3_stmt *)pStmt {
    return pStmt;
}

- (void)setPStmt:(sqlite3_stmt *)value {
    pStmt = value;
	//NSLog(@"0x%08X RS:  OPEN: %@", self, [self query]);
}

- (NSString *)query {
    return query;
}

- (void)setQuery:(NSString *)value {
    [value retain];
    [query release];
    query = value;
}

- (NSMutableDictionary *)columnNameToIndexMap {
    return columnNameToIndexMap;
}

- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value {
    [value retain];
    [columnNameToIndexMap release];
    columnNameToIndexMap = value;
}

@end
