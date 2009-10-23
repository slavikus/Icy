//
//  NSString+RipdevVersionCompare.m
//  Icy
//
//  Created by Slava Karpenko on 3/19/09.
//  Copyright 2009 Ripdev. All rights reserved.
//

#import <ctype.h>
#import "NSString+RipdevVersionCompare.h"

/*
	This is a shameless rip from DPKG, which is GPL'ed, so probably I should burn in hell
	for re-using GPLed source and not releasing the whole app in source form...
	
	Forgive me father, for I have sinned.
*/

struct versionrevision {
  unsigned long epoch;
  const char *version;
  const char *revision;
};  

static void blankversion(struct versionrevision *version);
static const char *parseversion(struct versionrevision *rversion, const char *string);
static int informativeversion(const struct versionrevision *version);
static int versioncompare(const struct versionrevision *version, const struct versionrevision *refversion);
static int verrevcmp(const char *val, const char *ref);
				   
@implementation NSString (RipdevVersionCompare)

- (BOOL)compareWithVersion:(NSString*)version operation:(NSString*)operation
{
  struct relationinfo {
    const char *string;
    /* These values are exit status codes, so 0=true, 1=false */
    int if_lesser, if_equal, if_greater;
    int if_none_a, if_none_both, if_none_b;
  };

  static const struct relationinfo relationinfos[]= {
   /*              < = > !a!2!b  */
    { "le",        0,0,1, 0,0,1  },
    { "lt",        0,1,1, 0,1,1  },
    { "eq",        1,0,1, 1,0,1  },
    { "ne",        0,1,0, 0,1,0  },
    { "ge",        1,0,0, 1,0,0  },
    { "gt",        1,1,0, 1,1,0  },
    { "le-nl",     0,0,1, 1,0,0  }, /* Here none        */
    { "lt-nl",     0,1,1, 1,1,0  }, /* is counted       */
    { "ge-nl",     1,0,0, 0,0,1  }, /* than any version.*/
    { "gt-nl",     1,1,0, 0,1,1  }, /*                  */
    { "<",         0,1,1, 0,1,1  }, /* For compatibility*/
    { "<=",        0,0,1, 0,0,1  }, /* with dpkg        */
    { "<<",        0,1,1, 0,1,1  }, /* control file     */
    { "=",         1,0,1, 1,0,1  }, /* syntax           */
    { ">",         1,1,0, 1,1,0  }, /*                  */
    { ">=",        1,0,0, 1,0,0  },
    { ">>",        1,1,0, 1,1,0  },
    { NULL                       }
  };

  const struct relationinfo *rip;
  const char *emsg;
  struct versionrevision a, b;
  int r;
  
  if (!operation)
	operation = @"lt";
	
  const char* argv[] = {
	[self UTF8String],
	[operation UTF8String],
	[version UTF8String],
	NULL
  };
  
  for (rip=relationinfos; rip->string && strcmp(rip->string,argv[1]); rip++);

  if (!rip->string)
  {
	NSLog(@"Unknown relation: %@", operation);
	return NO;
  }

  if (*argv[0] && strcmp(argv[0],"<unknown>")) {
    emsg= parseversion(&a,argv[0]);
    if (emsg) {
      NSLog(@"dpkg: version '%s' has bad syntax: %s\n", argv[0], emsg);
	  return NO;
	}
  } else {
    blankversion(&a);
  }
  
  if (*argv[2] && strcmp(argv[2],"<unknown>")) {
    emsg= parseversion(&b,argv[2]);
    if (emsg) {
      NSLog(@"dpkg: version '%s' has bad syntax: %s\n", argv[2], emsg);
	  return NO;
    }
  } else {
    blankversion(&b);
  }
  
  if (!informativeversion(&a)) {
    return !(informativeversion(&b) ? rip->if_none_a : rip->if_none_both);
	
  } else if (!informativeversion(&b)) {
    return !(rip->if_none_b);
  }
  
  r= versioncompare(&a,&b);

  if (r>0) return !(rip->if_greater);
  else if (r<0) return !(rip->if_lesser);
  else return !(rip->if_equal);

}

@end


#pragma mark -

void blankversion(struct versionrevision *version)
{
  version->epoch= 0;
  version->version= version->revision= NULL;
}

const char *parseversion(struct versionrevision *rversion, const char *string)
{
  char *hyphen, *colon, *eepochcolon;
  const char *end, *ptr;
  unsigned long epoch;

  if (!*string) return "version string is empty";

  /* trim leading and trailing space */
  while (*string && (*string == ' ' || *string == '\t') ) string++;
  /* string now points to the first non-whitespace char */
  end = string;
  /* find either the end of the string, or a whitespace char */
  while (*end && *end != ' ' && *end != '\t' ) end++;
  /* check for extra chars after trailing space */
  ptr = end;
  while (*ptr && ( *ptr == ' ' || *ptr == '\t' ) ) ptr++;
  if (*ptr) return "version string has embedded spaces";

  colon= strchr(string,':');
  if (colon) {
    epoch= strtoul(string,&eepochcolon,10);
    if (colon != eepochcolon) return "epoch in version is not number";
    if (!*++colon) return "nothing after colon in version number";
    string= colon;
    rversion->epoch= epoch;
  } else {
    rversion->epoch= 0;
  }
  
  rversion->version= malloc(end-string+1);
  bzero((void*)rversion->version, (end-string+1));
  memcpy((void*)rversion->version, string, (end-string));

  hyphen= strrchr(rversion->version,'-');
  if (hyphen) *hyphen++= 0;
  rversion->revision= hyphen ? hyphen : "";
  
  return NULL;
}

int informativeversion(const struct versionrevision *version)
{
  return (version->epoch ||
          (version->version && *version->version) ||
          (version->revision && *version->revision));
}

/* assume ascii; warning: evaluates x multiple times! */
#define order(x) ((x) == '~' ? -1 \
		: isdigit((x)) ? 0 \
		: !(x) ? 0 \
		: isalpha((x)) ? (x) \
		: (x) + 256)

static int verrevcmp(const char *val, const char *ref)
{
  if (!val) val= "";
  if (!ref) ref= "";

  while (*val || *ref) {
    int first_diff= 0;

    while ( (*val && !isdigit(*val)) || (*ref && !isdigit(*ref)) ) {
      int vc= order(*val), rc= order(*ref);
      if (vc != rc) return vc - rc;
      val++; ref++;
    }

    while ( *val == '0' ) val++;
    while ( *ref == '0' ) ref++;
    while (isdigit(*val) && isdigit(*ref)) {
      if (!first_diff) first_diff= *val - *ref;
      val++; ref++;
    }
    if (isdigit(*val)) return 1;
    if (isdigit(*ref)) return -1;
    if (first_diff) return first_diff;
  }
  return 0;
}

int versioncompare(const struct versionrevision *version,
                   const struct versionrevision *refversion)
{
  int r;

  if (version->epoch > refversion->epoch) return 1;
  if (version->epoch < refversion->epoch) return -1;
  r= verrevcmp(version->version,refversion->version);  if (r) return r;
  return verrevcmp(version->revision,refversion->revision);
}

