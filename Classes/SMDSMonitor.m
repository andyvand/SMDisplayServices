//
//  SMDSMonitor.m
//  SMDisplayServices
//
//  Created by Sam Marshall on 3/31/12.
//  Copyright 2012 Sam Marshall. All rights reserved.
//

/*
Copyright (c) 2010-2012, Sam Marshall
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. All advertising materials mentioning features or use of this software must display the following acknowledgement:
This product includes software developed by the Sam Marshall.
4. Neither the name of the Sam Marshall nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY Sam Marshall ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Sam Marshall BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "SMDSMonitor.h"
#import "NSScreen+Additions.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation SMDSMonitor

@synthesize displayid;
@synthesize name;
@synthesize frame;
@synthesize bounds;
@synthesize isMain;
@synthesize gamma;

- (id)initWithScreen:(NSScreen *)screen {
	self = [super init];
	if (self) {
		displayid = screen.CGDirectDisplayID;
		[self refresh];
	}
	return self;
}

- (void)refresh {
	frame = CGRectMake(0, 0, CGDisplayPixelsWide(displayid), CGDisplayPixelsHigh(displayid));
	bounds = CGDisplayBounds(displayid);
	isMain = (displayid == CGMainDisplayID());
	[self detectName];
	self.gamma = [[[SMDSGamma alloc] initWithDisplayID:displayid] autorelease];
}

- (void)detectName {
	io_connect_t display_port = CGDisplayIOServicePort(displayid);
	NSDictionary *data = [(NSDictionary *)IODisplayCreateInfoDictionary(display_port, kIODisplayOnlyPreferredName) autorelease];
	NSDictionary *names = [data objectForKey:@"DisplayProductName"];
	NSSet *name_locals = [NSSet setWithArray:[names allKeys]];
	if ([name_locals containsObject:[[NSLocale currentLocale] localeIdentifier]]) {
		self.name = [names objectForKey:[[NSLocale currentLocale] localeIdentifier]];
	} else if ([name_locals containsObject:@"en_US"]) {
		self.name = [names objectForKey:@"en_US"];
	} else {
		self.name = [names objectForKey:[[names allKeys] objectAtIndex:0]];
	}
}

- (NSArray *)windows {
	
}

- (void)dealloc {
	[super dealloc];
}

@end