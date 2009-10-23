#import "NSString+RipdevExtensions.h"
#import "md5.h"

@implementation NSString (AppTappExtensions)

- (NSString *)MD5Hash
{
	if ([self length])
	{
		MD5_CTX ctx;
		unsigned char digest[16];
		
		MD5Init(&ctx);
		
		MD5Update(&ctx, [self UTF8String], [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
		
		MD5Final(digest, &ctx);
		
		char hexdigest[33];
		int a;
		
		for (a = 0; a < 16; a++) sprintf(hexdigest + 2*a, "%02x", digest[a]);
		
		return [NSString stringWithCString:hexdigest];
	}
	else
		return nil;
}

- (NSString*)hostName
{
	NSArray* comps = [self componentsSeparatedByString:@"."];
	if ([comps count] > 1)
	{
		// walk array until we see a hostname. We're dumb and assume whatever component is longer than 3 symbols it is a host name
		CFIndex i;
		
		for (i=[comps count]-2;i>=0;i--)
		{
			if ([[comps objectAtIndex:i] length] > 3)
				break;
		}
		
		comps = [comps subarrayWithRange:NSMakeRange(i, [comps count]-i)];

		return [comps componentsJoinedByString:@"."];
	}
	
	return self;
}

- (UIColor*)colorRepresentation
{
	if (![self length])
		return [UIColor clearColor];
		
	NSArray* comps = [self componentsSeparatedByString:@","];
	if (comps && [comps count] >= 3)
	{
		float r = [[comps objectAtIndex:0] floatValue];
		float g = [[comps objectAtIndex:1] floatValue];
		float b = [[comps objectAtIndex:2] floatValue];
		float a = 1.;
		
		if ([comps count] > 3)
			a = [[comps objectAtIndex:3] floatValue];
			
		return [UIColor colorWithRed:r green:g blue:b alpha:a];
	}
	else if ([[self pathExtension] length])
	{
		NSString* path = [[NSBundle mainBundle] pathForResource:[self stringByDeletingPathExtension] ofType:[self pathExtension]];
		if (path)
		{
			UIImage* img = [[UIImage alloc] initWithContentsOfFile:path];
			
			if (img)
			{
				UIColor* color = [UIColor colorWithPatternImage:img];
				[img release];
				return color;
			}
		}
	}
	
	return nil;
}

@end
