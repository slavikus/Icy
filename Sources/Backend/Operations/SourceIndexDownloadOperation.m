//
//  SourceIndexDownloadOperation.m
//  Icy
//
//  Created by Slava Karpenko on 3/16/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "NSFileManager+RipdevExtensions.h"
#import "SourceIndexDownloadOperation.h"
#import "URLDownload.h"
#import "SourceRefreshOperation.h"

static NSData* sBZIP2MagicNumber = nil;
static NSData* sGZIPMagicNumber = nil;

@implementation SourceIndexDownloadOperation

- initWithSourceID:(sqlite_int64)sid url:(NSURL*)_url delegate:(id)_del;
{
	if (self = [super init])
	{
		sourceID = sid;
		url = [_url retain];
		delegate = _del;
	}
	
	return self;
}

- (void)dealloc
{
	[url release];
	
	[super dealloc];
}

- (void)main
{
	if (delegate && [delegate respondsToSelector:@selector(sourceRefreshStarted:)])
		[delegate performSelectorOnMainThread:@selector(sourceRefreshStarted:) withObject:[NSNumber numberWithLongLong:sourceID] waitUntilDone:NO];

	URLDownload* dl = [[URLDownload alloc] initWithURL:url delegate:self];
	dl.actAsInsect = YES;
	[dl start];
	[dl release];
}

- (void)urlDownloadDidFinish:(URLDownload *)download
{
	if (!sBZIP2MagicNumber)
	{
		const char magicBytes[] = { 0x42, 0x5a };
		sBZIP2MagicNumber = [[NSData alloc] initWithBytes:magicBytes length:sizeof(magicBytes)];
	}

	if (!sGZIPMagicNumber)
	{
		const char magicBytes[] = { 0x1f, 0x8b };
		sGZIPMagicNumber = [[NSData alloc] initWithBytes:magicBytes length:sizeof(magicBytes)];
	}
	
	NSString* destPath = [kIcyIndexesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.idx", (int)sourceID]];
	
	// check for magic values and expand if necessary
	NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath:download.downloadFilePath];
	NSData* magic = [fh readDataOfLength:2];
	[fh closeFile];

	[[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];

	if ([magic isEqualToData:sBZIP2MagicNumber])
	{
		NSString* newPath = [self unBzip2:download.downloadFilePath];
		if (!newPath)
		{
			[self performSelectorOnMainThread:@selector(notifyDelegateWithError:) withObject:nil waitUntilDone:YES];
			return;
		}
		
		NSError* err = nil;
		if (![[NSFileManager defaultManager] copyItemAtPath:newPath toPath:destPath error:&err])
			CFShow(err);

	}
	else if ([magic isEqualToData:sGZIPMagicNumber])
	{
		NSString* newPath = [self unGzip:download.downloadFilePath];
		if (!newPath)
		{
			[self performSelectorOnMainThread:@selector(notifyDelegateWithError:) withObject:nil waitUntilDone:YES];
			return;
		}
		
		[[NSFileManager defaultManager] copyItemAtPath:newPath toPath:destPath error:nil];		
	}
	else
	{
		// just copy the file
		[[NSFileManager defaultManager] copyItemAtPath:download.downloadFilePath toPath:destPath error:nil];
	}
	
	NSDictionary* oldAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:download.downloadFilePath error:nil];
	NSDictionary* newAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[oldAttrs fileModificationDate], NSFileModificationDate, nil];
	
	[[NSFileManager defaultManager] setAttributes:newAttrs ofItemAtPath:destPath error:nil];
	
	// Notify source refresh op that we're done
	CFMessagePortRef srPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kSourceRefreshOperationPortName);
	if (srPort)
	{
		CFMessagePortSendRequest(srPort, (SInt32)sourceID, NULL, 600., 0, NULL, NULL);
		
		CFRelease(srPort);
	}
	else
		[self performSelectorOnMainThread:@selector(notifyDelegateWithError:) withObject:nil waitUntilDone:YES];
}

- (void)urlDownload:(URLDownload *)download didFailWithError:(NSError *)error
{
	NSString* destPath = [kIcyIndexesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.idx", (int)sourceID]];
	
	[[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
	
	[self performSelectorOnMainThread:@selector(notifyDelegateWithError:) withObject:error waitUntilDone:YES];
}

- (void)notifyDelegateWithError:(NSError*)error
{
	if (delegate && [delegate respondsToSelector:@selector(sourceRefreshDone:withError:)])
		[delegate sourceRefreshDone:[NSNumber numberWithLongLong:sourceID] withError:error];
}

#pragma mark -

- (NSString*)unBzip2:(NSString*)path
{
	NSString* tempPath = [[[NSFileManager defaultManager] tempFilePath] retain];
	
	char* argv[] = {
#if defined(__i386__)
		"/usr/bin/bzip2",
#else
		"/bin/bzip2",
#endif
		"-dc",
		(char*)[path fileSystemRepresentation],
		NULL
	};
	
	int res = [self exec:argv redirectTo:tempPath];

	if (res == 0)
		return [tempPath autorelease];
	
	[[NSFileManager defaultManager] removeItemAtPath:[tempPath autorelease] error:nil];
	
	return nil;
}

- (NSString*)unGzip:(NSString*)path
{
	NSString* tempPath = [[[NSFileManager defaultManager] tempFilePath] retain];
	
	char* argv[] = {
#if defined(__i386__)
		"/usr/bin/gzip",
#else
		"/bin/gzip",
#endif
		"-dc",
		(char*)[path fileSystemRepresentation],
		NULL
	};
	
	int res = [self exec:argv redirectTo:tempPath];

	if (res == 0)
		return [tempPath autorelease];
	
	[[NSFileManager defaultManager] removeItemAtPath:[tempPath autorelease] error:nil];
	
	return nil;
}

- (int)exec:(char**)argv redirectTo:(NSString*)redirectPath
{
	pid_t pid;
	pid_t result;
	int status;
	const char* repath = [redirectPath fileSystemRepresentation];

	pid = fork();

	if(pid == 0)
	{
		FILE* stream = NULL;
		
		if (redirectPath)
		{
			unlink(repath);
			stream = fopen(repath, "w+");
	
			dup2(fileno(stream), STDOUT_FILENO);
		}
		
		char* envir[] = {
			"PATH=/bin:/usr/bin:/usr/local/bin",
			NULL
		};
				
		execve(argv[0], argv, envir);
		
		if (stream)
			close(fileno(stream));
		exit(0);
		return 0;
	}
	else if (pid < 0)
	{
		NSLog(@"Error forking child process!");
	}
	else
	{
		while (1)
		{
			result = waitpid(pid, &status, WNOHANG);
			if (result == pid || result == -1) break;
			usleep(100);
		};
		
		return WEXITSTATUS(status);
	}
	
	return -1;
}

@end
