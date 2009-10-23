//
//  StashController.m
//  Icy
//
//  Created by Slava Karpenko on 5/30/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <sys/stat.h>
#import "StashController.h"
#import "IcyAppDelegate.h"

static void cmd_system_chroot(const char* newRoot, char * argv[]);
static void sig_chld_ignore(int signal);
static void sig_chld_waitpid(int signal);

#if defined(__i386__)
	#define STASH_DIR "/tmp/stash/"
#else
	#define STASH_DIR "/var/stash/"
#endif

@implementation StashController

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	// Theme support
	NSString* tintColor = [ICY_APP.themeDefinition objectForKey:@"InstallBackgroundColor"];
	if (tintColor)
	{
		self.view.backgroundColor = [tintColor colorRepresentation];
	}
	else
		self.view.backgroundColor = [UIColor viewFlipsideBackgroundColor];
	// ~Theme support
	
	[ICY_APP.window addSubview:self.view];
	CGRect fr = self.view.frame;
	fr.origin.y += 10.;
	self.view.frame = fr;
	
	[spinner startAnimating];
	
	progress.progress = .0;
	status.text = NSLocalizedString(@"Preparing", @"");
	caption.text = NSLocalizedString(@"Moving Directories", @"");

    [super viewDidLoad];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

#pragma mark -

- (void)stashDirectories:(NSArray*)dirs
{
	int i = 0;
	
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	for (NSString* dir in dirs)
	{
		NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
		i++;
		status.text = dir;
		progress.progress = ((float)i / (float)[dirs count]);
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
		[self _stash:dir];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
		[innerPool release];
	}
	
	progress.progress = 1.;
	status.text = @"";
	
	UIActionSheet* as = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"The directories were successfully moved to a bigger user partition, so you can safely install some of the larger third-party packages. Icy will quit now. To browse and install packages, please launch it again.", @"")
												delegate:self cancelButtonTitle:nil destructiveButtonTitle:NSLocalizedString(@"Quit", @"") otherButtonTitles:nil];
	
	[as showInView:self.view];
	[as release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	exit(0);
}

- (void)_stash:(NSString*)dir
{
	struct stat st;
	
	if (stat(STASH_DIR, &st))
		mkdir(STASH_DIR, 0755);
	
	char stashDir[1024];
	
	strcpy(stashDir, STASH_DIR);
	strcat(stashDir, [[dir lastPathComponent] UTF8String]);
	
	// make random ending for the stash dir
	strcat(stashDir, [[NSString stringWithFormat:@"-%@", [[[[NSDate date] description] MD5Hash] substringToIndex:5]] UTF8String]);
	
	printf("Stashing %s -> %s\n", [dir fileSystemRepresentation], stashDir); fflush(stdout);
		
	// it's time to mooove
	cmd_system_chroot((const char*)NULL, (char*[]){"/bin/mv", (char*)[dir fileSystemRepresentation], stashDir, (char*) 0});
	
	symlink(stashDir, [dir fileSystemRepresentation]);
}

@end

void cmd_system_chroot(const char* newRoot, char * argv[])
{
	pid_t fork_pid;
	signal(SIGCHLD, &sig_chld_ignore);
	if((fork_pid = fork()) != 0)
	{
		while(waitpid(fork_pid, NULL, WNOHANG) <= 0)
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
			
			[pool release];
		}
	}
	else
	{
		if(newRoot)
		{
			if(chroot(newRoot) != 0)
			{
				fprintf(stderr, "execute command: chroot failed\n");
				exit(0);
			}
			if(chdir("/") != 0)
			{
				fprintf(stderr, "execute command: chdir failed\n");
				exit(0);
			}
			fflush(stderr);
		}
		
		setenv("PATH", "/bin", 1);
		
		if(execve(argv[0], argv, NULL) != 0)
		{
			perror("execv");
			fflush(stderr);
			fflush(stdout);
		}
		
		exit(0);
	}

	signal(SIGCHLD, &sig_chld_waitpid);
}

static void sig_chld_ignore(int signal)
{
	return;
}

static void sig_chld_waitpid(int signal)
{
	while(waitpid(-1, 0, WNOHANG) > 0);
}

