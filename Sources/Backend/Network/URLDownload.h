//
//  URLDownload.h
//  Installer
//
//  Created by Slava Karpenko on 3/10/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <curl/curl.h>

@interface URLDownload : NSObject {
	CURL*				curl;
	NSFileHandle*		downloadFile;
	NSString*			downloadFilePath;
	id					delegate;
	NSURL*				url;
	BOOL				cancel;
	NSDate*				lastModified;
	
	BOOL				actAsInsect;
}

@property (retain) NSFileHandle* downloadFile;
@property (retain) NSString* downloadFilePath;
@property (nonatomic, assign) id delegate;
@property (retain) NSURL* url;
@property (assign) BOOL cancel;
@property (retain) NSDate* lastModified;
@property (assign) BOOL actAsInsect;

- (id)initWithURL:(NSURL *)request delegate:(id)delegate;
- (id)initWithURL:(NSURL *)request delegate:(id)del resumeable:(BOOL)resumeable;

- (void)start;

- (void)cancelDownload;			// you will be called a download:didFailWithError: when the actual abort is done.

@end

@interface NSObject (URLDownloadDelegate)

- (void)urlDownloadDidBegin:(URLDownload *)download;
- (void)urlDownload:(URLDownload *)download didReceiveDataOfLength:(NSUInteger)length;
- (void)urlDownload:(URLDownload *)download didCreateDestination:(NSString *)path;
- (void)urlDownloadDidFinish:(URLDownload *)download;
- (void)urlDownload:(URLDownload *)download didFailWithError:(NSError *)error;

@end
