//
//  URLDownload.m
//  Installer
//
//  Created by Slava Karpenko on 3/10/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#include <sys/sysctl.h>
#import "NSFileManager+RipdevExtensions.h"
#import "NSString+RipdevExtensions.h"
#import "URLDownload.h"
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#ifndef INSTALLER_APP
    #import <CFNetwork/CFProxySupport.h>
#endif // INSTALLER_APP

#define kURLDownloadTimeout		600			// 10 minutes oughtta be enough for everybody...™

#define CURLErrorDomain @"se.haxx.curl"

static size_t _curl_write(void *buffer, size_t size, size_t nmemb, void *userp);
static size_t _curl_header(void *buffer, size_t size, size_t nmemb, void *userp);

static char			gMachineName[128] = { 0 };

@implementation URLDownload

@synthesize downloadFile;
@synthesize downloadFilePath;
@synthesize delegate;
@synthesize url;
@synthesize cancel;
@synthesize lastModified;
@synthesize actAsInsect;

- (id)initWithURL:(NSURL *)_url delegate:(id)del
{
	return [self initWithURL:_url delegate:del resumeable:NO];
}

- (id)initWithURL:(NSURL *)_url delegate:(id)del resumeable:(BOOL)resumeable
{
	if (self = [super init])
	{
		cancel = NO;
		self.delegate = del;
		
		self.url = _url;
		
		if ([self.url isFileURL])
		{
			self.downloadFilePath = [[NSFileManager defaultManager] tempFilePath];
			
			if ([delegate respondsToSelector:@selector(urlDownloadDidBegin:)])
				[delegate urlDownloadDidBegin:self];
				
			if ([delegate respondsToSelector:@selector(urlDownload:didCreateDestination:)])
				[delegate urlDownload:self didCreateDestination:self.downloadFilePath];
			
			if ([[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:self.downloadFilePath error:nil])
			{
				[self connectionDidFinishLoading:nil];
			}
			else
			{
				[self connection:nil didFailWithError:[NSError errorWithDomain:CURLErrorDomain code:CURLE_FILE_COULDNT_READ_FILE userInfo:nil]];
			}
			
			return self;
		}
		
		curl = curl_easy_init();
		
		/*
		if (resumeable)
		{
			// find whether this file was attempted download before
			ATIncompleteDownload* dl = [[ATPackageManager sharedPackageManager].incompleteDownloads downloadWithLocation:[request URL]];
			if (dl)
			{
				self.downloadFilePath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:dl.path];
			}
			else
			{
				NSString* tempFileName = [[request URL] tempDownloadFileName];
				
				self.downloadFilePath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:tempFileName];
				
				dl = [[ATIncompleteDownload alloc] init];
				
				dl.url = [request URL];
				dl.path = tempFileName;
				dl.date = [NSDate date];
				
				[dl commit];

				[dl release];
			}
		}
		else */
			self.downloadFilePath = [kIcyCachePath stringByAppendingPathComponent:[[self.url absoluteString] MD5Hash]];
		
		if ([delegate respondsToSelector:@selector(downloadDidBegin:)])
			[delegate urlDownloadDidBegin:self];

		if([[NSFileManager defaultManager] fileExistsAtPath:self.downloadFilePath] || [[NSFileManager defaultManager] createFileAtPath:self.downloadFilePath contents:nil attributes:nil])
		{
			self.downloadFile = [NSFileHandle fileHandleForWritingAtPath:self.downloadFilePath];
			
			//[self.downloadFile seekToEndOfFile];			// XXX uncomment me if we plan transfer resumes
			
			if ([delegate respondsToSelector:@selector(download:didCreateDestination:)])
				[delegate urlDownload:self didCreateDestination:self.downloadFilePath];
		}

		if (curl)
		{
			curl_easy_setopt(curl, CURLOPT_URL, [[self.url absoluteString] UTF8String]);
			curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, &_curl_write);
			curl_easy_setopt(curl, CURLOPT_HEADERDATA, self);
			curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, &_curl_header);
			curl_easy_setopt(curl, CURLOPT_WRITEDATA, self);
			curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
			curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
			curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 15);		// 15 seconds connect timeout
			//curl_easy_setopt(curl, CURLOPT_TIMEOUT, kURLDownloadTimeout);			// 30 seconds overall timeout
			
#if !defined(__i386__)
			CFDictionaryRef	proxySettings = CFNetworkCopySystemProxySettings();
			
			if (proxySettings)
			{
				CFNumberRef isProxyEnabled = (CFNumberRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPEnable);
				CFStringRef proxyName = (CFStringRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPProxy);
				CFNumberRef proxyPort = (CFNumberRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPPort);
				
				if (isProxyEnabled && [(NSNumber*)isProxyEnabled intValue] && proxyPort && proxyName)
				{
					curl_easy_setopt(curl, CURLOPT_PROXY, [(NSString*)proxyName UTF8String]);
					curl_easy_setopt(curl, CURLOPT_PROXYPORT, [(NSNumber*)proxyPort unsignedIntValue]);
				}
				
				CFRelease(proxySettings);
			}
#endif

			/*if ([[NSFileManager defaultManager] fileExistsAtPath:self.downloadFilePath])
			{
				unsigned long long fs = [[[NSFileManager defaultManager] fileAttributesAtPath:self.downloadFilePath traverseLink:NO] fileSize];
				if (fs > 0)
				{
					curl_off_t offset = fs;
					
					curl_easy_setopt(curl, CURLOPT_RESUME_FROM_LARGE, offset);
				}
			}*/
			//[self performSelector:@selector(start) withObject:nil afterDelay:0.];
		}
		
	}
	
	return self;
}

- (void)start
{
	[self retain];			// in case someone releases us in response to an error
	CURLcode res = CURLE_FAILED_INIT;
	
	if (curl)
    {
		// Add saurik's extended http fields
		struct curl_slist *headers = NULL;
		
		headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Unique-ID: %@", [UIDevice currentDevice].uniqueIdentifier] UTF8String]);
		headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Firmware: %@", [UIDevice currentDevice].systemVersion] UTF8String]);
		
		// machine name
		if (!gMachineName[0])
		{
			size_t size = sizeof(gMachineName);
			sysctlbyname("hw.machine", gMachineName, &size, NULL, 0);
		}
		
		if (gMachineName[0])
			headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Machine: %s", gMachineName] UTF8String]);
		
		curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

		if (self.actAsInsect)
			curl_easy_setopt(curl, CURLOPT_USERAGENT, [@"Cydia/0.9 CFNetwork/342.1 Darwin/9.4.1" UTF8String]);
		else
			curl_easy_setopt(curl, CURLOPT_USERAGENT, [@"Telesphoreo APT-HTTP/1.0.534" UTF8String]);

		res = curl_easy_perform(curl);
		curl_slist_free_all(headers);
   }

	if (res != CURLE_OK && res != CURLE_WRITE_ERROR)
	{
		NSError* err = nil;
		NSDictionary* userInfo = nil;
		
		const char* errStr = curl_easy_strerror(res);
		
		if (errStr)
		{
			NSString* fullError = [NSString stringWithFormat:@"%@ (%@)", [NSString stringWithUTF8String:errStr], [self.url host]];
		
			userInfo = [NSDictionary dictionaryWithObjectsAndKeys:fullError, NSLocalizedDescriptionKey, nil];
		}
		
		err = [NSError errorWithDomain:CURLErrorDomain code:res userInfo:userInfo];
		
		[self connection:nil didFailWithError:err];
	}
	
	if (res == CURLE_OK ||
		res == CURLE_WRITE_ERROR)		// write error = manual abort, no need to keep the file around
	{
		// remove incomplete download (as it's now complete)
/*		ATIncompleteDownload* dl = [[ATPackageManager sharedPackageManager].incompleteDownloads downloadWithLocation:self.url];
		if (dl)
		{
			[dl remove];
		} */
		
		[self connectionDidFinishLoading:nil];
	}
	
	if (self.cancel)
		[[NSFileManager defaultManager] removeItemAtPath:self.downloadFilePath error:nil];
	
	[self release];
}

- (void)dealloc
{
	if (curl)
		curl_easy_cleanup(curl);
	
	[self.downloadFile closeFile];
	self.downloadFile = nil;
	self.downloadFilePath = nil;
	
	self.url = nil;
	
	[super dealloc];
}

- (void)cancelDownload
{
	cancel = YES;
}

#pragma mark -
#pragma mark NSURL Download Delegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newBytes {
	[self.downloadFile writeData:newBytes];

	if ([self.delegate respondsToSelector:@selector(urlDownload:didReceiveDataOfLength:)])
		[self.delegate urlDownload:self didReceiveDataOfLength:[newBytes length]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self.downloadFile closeFile];
	self.downloadFile = nil;
	
	//NSLog(@"[URLd] Done: %@", self.url);
	
	if (self.lastModified)
	{
		NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:self.lastModified, NSFileModificationDate, nil];
		
		[[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:self.downloadFilePath error:nil];
	}
	
	if ([self.delegate respondsToSelector:@selector(urlDownloadDidFinish:)])
		[self.delegate urlDownloadDidFinish:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)failReason
{
	[self.downloadFile closeFile];
	self.downloadFile = nil;
	
	//NSLog(@"[URLd] Error: %@ -> %@", self.url, failReason);
	
	if ([self.delegate respondsToSelector:@selector(urlDownload:didFailWithError:)])
		[self.delegate urlDownload:self didFailWithError:failReason];

	if (self.downloadFilePath)
		[[NSFileManager defaultManager] removeItemAtPath:self.downloadFilePath error:nil];
	
	self.delegate = nil;
}

- (BOOL)setLastModifiedDate:(NSString*)lastModifiedString
{
	NSDate* date = [NSDate dateWithNaturalLanguageString:lastModifiedString];
	
	if (date)
	{
		NSDate* cachedFileDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.downloadFilePath error:nil] fileModificationDate];
				
		if (cachedFileDate)
		{
			if ([date isEqualToDate:cachedFileDate])
			{
				//fprintf(stderr, "Aborting download (%s) as the cached copy is the same.\n", [[self.url absoluteString] UTF8String]);
				return NO;
			}
			
			//fprintf(stderr, "Continuing download (%s) as the cached copy is not the same.\n", [[self.url absoluteString] UTF8String]);
			
			[self.downloadFile truncateFileAtOffset:0];
			[self.downloadFile seekToFileOffset:0];
		}
		
		self.lastModified = date;
	}
	//else
	//	fprintf(stderr, "Cannot convert date from natural language string (%s)\n", [lastModifiedString UTF8String]);
	
	return YES;		// continue loading
}

@end

static size_t _curl_write(void *buffer, size_t size, size_t nmemb, void *userp)
{
	URLDownload* dl = (URLDownload*)userp;

	if (dl.cancel)
		return -1;

	NSData* newData = [[NSData alloc] initWithBytesNoCopy:buffer length:(size*nmemb) freeWhenDone:NO];
	[dl connection:nil didReceiveData:newData];
	[newData release];
	
	if (dl.cancel)		// we check again because our handler may have set cancel in the callback
		return -1;

	return size*nmemb;
}

static size_t _curl_header(void *buffer, size_t size, size_t nmemb, void *userp)
{
	URLDownload* dl = (URLDownload*)userp;
	NSString* header = [NSString stringWithCString:buffer length:size*nmemb];
	
	if ([header hasPrefix:@"HTTP/"])
	{
		// check response code
		NSArray* components = [header componentsSeparatedByString:@" "];
		
		// get the response code:
		if ([components count] > 1)
		{
			int respCode = [[components objectAtIndex:1] intValue];
			
			if (respCode >= 400 && respCode <= 599)
			{
				// emit error
				NSString* errorStr = nil;
				NSDictionary* userInfo = nil;
				
				if ([components count] > 2)
					errorStr = [[components subarrayWithRange:NSMakeRange(2, [components count]-2)] componentsJoinedByString:@" "];
				
				if (errorStr)
					userInfo = [NSDictionary dictionaryWithObject:errorStr forKey:NSLocalizedDescriptionKey];
				
				NSError* err = [NSError errorWithDomain:CURLErrorDomain code:respCode userInfo:userInfo];
				[dl connection:nil didFailWithError:err];
				
				return -1;
			}
		}
	}
	else if ([header hasPrefix:@"Last-Modified: "])
	{
		if (![dl setLastModifiedDate:[header substringFromIndex:[@"Last-Modified: " length]]])
			return -1;
	}
	
	return size*nmemb;
}

