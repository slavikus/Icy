//
//  DPKGParser.m
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "DPKGParser.h"


@implementation DPKGParser

- (NSArray*)parseDatabaseAtPath:(NSString*)path
{
	return [self parseDatabaseAtPath:path ignoreStatus:NO];
}

- (NSArray*)parseDatabaseAtPath:(NSString*)path ignoreStatus:(BOOL)ignoreStatus
{
	NSMutableArray* packages = [NSMutableArray arrayWithCapacity:0];
	NSError* err = nil;
	BOOL lossyConversion = NO;
	
	NSString* databaseData = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
	
	if (err)		// fallback to ASCII if there's something wrong with the file
	{
		databaseData = [[NSString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&err];
		lossyConversion = YES;
	}
	
	if (!databaseData)
		return packages;
		
	NSArray* packs = [databaseData componentsSeparatedByString:@"\n\n"];
	[databaseData release];
	
	for (NSString* package in packs)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSArray* lines = [package componentsSeparatedByString:@"\n"];
		NSMutableDictionary* newEntry = [NSMutableDictionary dictionaryWithCapacity:0];
		NSString* lastKey = nil;
		
		for (NSString* line in lines)
		{
			if ([line hasPrefix:@" "])
			{
				// continue of multi-line object
				if (lastKey)
				{
					NSString* lastValue = [newEntry objectForKey:lastKey];
					
					if ([lastValue isKindOfClass:[NSString class]])
						[newEntry setObject:[lastValue stringByAppendingString:line] forKey:lastKey];
				}
				
				continue;
			}
			
			NSRange separator = [line rangeOfString:@": "];
			if (separator.length)
			{
				NSString* key = [[line substringToIndex:separator.location] lowercaseString];
				NSString* value = [line substringFromIndex:separator.location + separator.length];
				
				lastKey = key;
								
				if (value && key)
				{
					if (lossyConversion)
					{
						NSString* newVal = nil;
						
						NS_DURING
						newVal = [[[NSString alloc] initWithData:[value dataUsingEncoding:NSISOLatin1StringEncoding] encoding:NSUTF8StringEncoding] autorelease];
						if (newVal)
							value = newVal;
						
						NS_HANDLER
						NS_ENDHANDLER
					}
					
					[newEntry setObject:value forKey:key];
				}
			}
		}
		
		if ([newEntry count])
		{
			NSString* status = [newEntry objectForKey:@"status"];
			NSArray* comps = [status componentsSeparatedByString:@" "];
			
			if (ignoreStatus || (comps && [comps containsObject:@"install"] && [comps containsObject:@"ok"] && [comps containsObject:@"installed"]))
			{
				[packages addObject:newEntry];
			}
		}
		
		[pool release];
	}
	
	return packages;
}

- (NSMutableArray*)dependencyFromString:(NSString*)string
{
    return [self dependencyFromString:string full:NO];
}

- (NSMutableArray*)dependencyFromString:(NSString*)string full:(BOOL)full
{
    NSMutableArray* result = nil;
    
    if(string != nil)
    {
        NSArray* components = [string componentsSeparatedByString:@","];
        if([components count] > 0)
        {
            NSString* dependString = nil;
            
            for (dependString in components)
            {
                NSString* correctDependString = dependString;
                
                NSRange findedRange = [correctDependString rangeOfString:@"("];
                if(findedRange.location < [correctDependString length])
				{
					if ([[correctDependString substringFromIndex:(findedRange.location - 1)] hasPrefix:@" "])
						correctDependString = [correctDependString substringToIndex:(findedRange.location - 1)];
					else
						correctDependString = [correctDependString substringToIndex:findedRange.location];
				}
				
                correctDependString = [correctDependString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
                
                if ([correctDependString length] > 0)
                {
                    if(result == nil)
                        result = [NSMutableArray arrayWithCapacity:0];
						
					if (full)
					{
						NSString* vers = nil;
						
						if (findedRange.length)
						{
							vers = [dependString substringFromIndex:findedRange.location];
							vers = [vers stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t()"]];
						}
						
						[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:	correctDependString, @"package",
																						vers, @"version",
																						nil]];
					}
                    else
						[result addObject:correctDependString];
                }
            }
        }
    }
    
    return result;
}

@end
