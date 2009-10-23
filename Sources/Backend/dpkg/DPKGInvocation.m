//
//  DPKGInvocation.m
//  Icy
//
//  Created by Slava Karpenko on 3/21/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import "DPKGInvocation.h"


@implementation DPKGInvocation

-(int) invoke:(NSArray*) arguments
{
    int fn = fileno(stderr);
    
    return [self invoke:arguments fn:fn];
}

-(int) invoke:(NSArray*) arguments fn:(int) fn
{
	pid_t fork_pid;

	if((fork_pid = fork()) != 0)
	{
		int st = 0;
		pid_t p = 0;
		
		do
		{
			p = waitpid(fork_pid, &st, WNOHANG);
			if (p <= 0)
				usleep(300);
		} while (p <= 0);
		
		return WEXITSTATUS(st);
	}
	else
	{
#ifdef __i386__
		setenv("PATH", "/bin:/sbin:/usr/bin:/usr/sbin:/opt/local/bin", 1);
#else
		setenv("PATH", "/bin:/sbin:/usr/bin:/usr/sbin", 1);
#endif
		char cydiaFake[32];
		sprintf(cydiaFake, "%d 1", fileno(stdout));
		setenv("CYDIA", cydiaFake, 1);
	//setenv("CYDIA", [[[[NSNumber numberWithInt:cydiafd_] stringValue] stringByAppendingString:@" 1"] UTF8String], 1);

		char fd[10];
		
		sprintf(fd, "%d", fn);
		
		// build the args list
		char** args = malloc(sizeof(char*) * ([arguments count]+4));
		int i;
		bzero(args, sizeof(char*) * ([arguments count]+4));
		
		args[0] = "dpkg";
		args[1] = "--status-fd";
		args[2] = fd;
		for (i=0; i < [arguments count]; i++)
		{
			args[i+3] = (char*)[[arguments objectAtIndex:i] UTF8String];
		}
		
/*		for (i=0; args[i]; i++)
		{
			NSLog(@"#%d: '%s'", i, args[i]);
		} */
		
		if (fn != fileno(stderr))
			dup2(fn, fileno(stderr));
		
		int rc = setuid(0);
		if (rc) perror("setuid");
		rc = setgid(0);
		if (rc) perror("setgid");
		
		if(execvp(args[0], args) != 0)
		{
			perror("execvp");
		}
		
		exit(0);
	}
}

-(int) invoke:(NSArray*) arguments errorInfo:(NSString**) errorInfo
{
    int fn = fileno(stderr);
    
    FILE* f = fopen("/tmp/dpkg.out", "a");
    if(f)
        fn = fileno(f);

    int res = [self invoke:arguments fn:fn];
    
    if(f)
        fclose(f);
    
    if(res)
    {
        *errorInfo = @"Unknown error";

        NSString* string = [NSString stringWithContentsOfFile:@"/tmp/dpkg.out"];
        if(string)
            *errorInfo = string;
    }
	
    
    unlink("/tmp/dpkg.out");
    
    return res;
}

@end
