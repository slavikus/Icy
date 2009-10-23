/*
 *  Trichlorotrifluoroethane.c
 *  Icy
 *
 *  Created by Slava Karpenko on 3/21/09.
 *  Copyright 2009 Ripdev. All rights reserved.
 *
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char * argv[])
{
	char fullpath[1024];
	
	strncpy(fullpath, argv[0], strlen(argv[0]) - strlen("Trichlorotrifluoroethane"));
	strcat(fullpath, "Icy");
	
	char* newArgv[] = { fullpath, NULL };
	
	return execve(fullpath, newArgv, NULL);
}
