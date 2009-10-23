#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface ResultSet : NSObject
{
    sqlite3_stmt *pStmt;
    NSString *query;
    NSMutableDictionary *columnNameToIndexMap;
    BOOL columnNamesSetup;
}

+ (id)resultSetWithStatement:(sqlite3_stmt *)stmt;

- (void) close;

- (NSString *)query;
- (void)setQuery:(NSString *)value;

- (sqlite3_stmt *)pStmt;
- (void)setPStmt:(sqlite3_stmt *)value;

- (BOOL)next;

- (int)intForColumn:(NSString*)columnName;
- (BOOL)boolForColumn:(NSString*)columnName;
- (double)doubleForColumn:(NSString*)columnName;
- (NSString*)stringForColumn:(NSString*)columnName;
- (NSDate*)dateForColumn:(NSString*)columnName;
- (NSData*)dataForColumn:(NSString*)columnName;

- (void)kvcMagic:(id)object;

@end
