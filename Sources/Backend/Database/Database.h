#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "ResultSet.h"

#define BUSY_MAX_WAIT_ITERATIONS 1000

@interface Database : NSObject 
{
	sqlite3*	db;
	NSString*	databasePath;
    BOOL        logsErrors;
}

@property (assign) sqlite3* db;

+ (Database*)sharedDatabase;
+ (Database*)database;

- (id)initWithPath:(NSString*)inPath;

- (sqlite3*)db;

- (BOOL)open;
- (void)close;

- (NSString*)lastErrorMessage;
- (int)lastErrorCode;
- (sqlite_int64)lastInsertRowId;
- (sqlite_int64)affectedRows;

- (int)executeUpdate:(NSString*)objs, ...;
- (id)executeQuery:(NSString*)obj, ...;
- (int)executeUpdate:(NSString*)query withArray:(NSArray*)objs;

- (BOOL)rollback;
- (BOOL)commit;
- (BOOL)beginTransaction;

- (BOOL)logsErrors;
- (void)setLogsErrors:(BOOL)flag;

+ (NSString*) sqliteLibVersion;

@end
