//
//  SMDSScreenControl.m
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

#import "SMDSScreenControl.h"
#import "SMDSMonitor.h"
#import "SMDSScreenView.h"
#import "SMDSMaths.h"

@implementation SMDSScreenControl

@synthesize displayHighlight;
@synthesize delta;
@synthesize global;
@synthesize canConfigure;
@synthesize canZeroSelect;
@synthesize shouldNotRetainSelect;

- (id)initWithFrame:(NSRect)rect {
	self = [super initWithFrame:rect];
	if (self) {
		displayHighlight = [[SMDSDisplaySelect alloc] initWithContentRect:CGRectMake(0,0,0,0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreRetained defer:NO];
		[displayHighlight setLevel:NSTornOffMenuWindowLevel];
		canConfigure = YES;
		canZeroSelect = YES;
		shouldNotRetainSelect = YES;
	}
	return self;
}

- (BOOL)canZeroSelect {
	if (shouldNotRetainSelect)
		return YES;
	else
		return canZeroSelect;
}

- (BOOL)isFlipped {
	return YES;
}

- (void)setDisplayViews:(NSArray *)displays {
	[[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	delta = GetDelta(displays);
	global = GetGlobalDisplaySpace(displays);
	for (SMDSMonitor *screen in displays) {
		SMDSScreenView *a_screen = [[[SMDSScreenView alloc] initWithFrame:ReduceFrameWithDelta(screen.bounds, delta) withID:screen.displayid] autorelease];
		[self addSubview:a_screen];
	}
	[self setNeedsDisplay:YES];
}

- (void)setHightlight:(BOOL)toggle onDisplay:(NSUInteger)displayid {
	if (toggle) {
		CGRect bounds = GetDisplayRectForDisplayInSpace(displayid,global);	
		[displayHighlight setFrame:bounds display:YES];
		[displayHighlight orderFrontRegardless];
	} else {
		[displayHighlight orderOut:self];
		[displayHighlight setFrame:CGRectMake(0,0,0,0) display:YES];
	}
}

- (void)mouseDown:(NSEvent *)theEvent {
	NSArray *display_subviews = [self subviews];
	NSWindow *window = [self window];
	NSPoint vloc;
	if (window) {
		vloc = [self convertPoint:[theEvent locationInWindow] fromView:[window contentView]];
		NSUInteger current_selected = [display_subviews indexOfObjectPassingTest:^(SMDSScreenView *view, NSUInteger index, BOOL *stop) {
				return view.isSelected;
		}];
		
		NSUInteger clicked_view = [display_subviews indexOfObjectPassingTest:^(SMDSScreenView *view, NSUInteger index, BOOL *stop) {
			return [view mouse:vloc inRect:view.frame];
		}];
		
		if (canZeroSelect) {
			if (current_selected != NSNotFound) {
				SMDSScreenView *old_view = [display_subviews objectAtIndex:current_selected];
				old_view.isSelected = NO;
			}
			if (clicked_view != NSNotFound) {
				SMDSScreenView *view = [display_subviews objectAtIndex:clicked_view];
				view.isSelected = YES;
				[self setHightlight:YES onDisplay:[view displayid]];
			}
		} else {
			if (clicked_view != NSNotFound) {
				if (current_selected != NSNotFound) {
					SMDSScreenView *old_view = [display_subviews objectAtIndex:current_selected];
					old_view.isSelected = NO;
				}
				SMDSScreenView *view = [display_subviews objectAtIndex:clicked_view];
				view.isSelected = YES;
				[self setHightlight:YES onDisplay:[view displayid]];
			}
		}
		[self setNeedsDisplay:YES];
	}
}

- (void)mouseUp:(NSEvent *)theEvent {
	[self setHightlight:NO onDisplay:0];
}

- (BOOL)willDisplay:(SMDSScreenView *)dragged_display collide:(CGRect)display_rect {
	BOOL status = NO;
	NSPredicate *pred = [NSPredicate predicateWithFormat:@"displayid != %llu",dragged_display.displayid];
	NSArray *results = [[self subviews] filteredArrayUsingPredicate:pred];
	
	for (SMDSScreenView *view in results) {
		status = CGRectIntersectsRect(view.frame, display_rect);
		if (status) break;
	}
	return status;
}

- (NSArray *)viewSnap:(SMDSScreenView *)colliding_view {
	NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
	NSPredicate *pred = [NSPredicate predicateWithFormat:@"displayid != %llu",colliding_view.displayid];
	NSArray *results = [[self subviews] filteredArrayUsingPredicate:pred];	
	for (SMDSScreenView *view in results) {
		CGRect draggable = CGRectMake(view.frame.origin.x-colliding_view.frame.size.width, view.frame.origin.y-colliding_view.frame.size.height, (2.0*colliding_view.frame.size.width)+view.frame.size.width+0.5, (2.0*colliding_view.frame.size.height)+view.frame.size.height+0.5);		
		[array addObject:[NSValue valueWithRect:draggable]];
	}
	return array;
}

- (BOOL)snap:(CGRect)view toBounds:(NSArray *)array {
	BOOL status = YES;
	for (NSValue *val in array) {		
		status = CGRectContainsRect([val rectValue], view);
		if (!status) break;
	}
	return status;
}

- (CGPoint)getDeltaFromMain:(SMDSScreenView *)view {
	CGFloat x = 0.f, y = 0.f;
	//CGSize test = GetDelta([self subviews]);
	//NSLog(@"%f %f", test.width, test.height);
	NSPredicate *pred_main = [NSPredicate predicateWithFormat:@"displayid == %llu",CGMainDisplayID()];
	NSArray *results_main = [[self subviews] filteredArrayUsingPredicate:pred_main];	
	for (SMDSScreenView *screen in results_main) {
		//NSLog(@"%llu: %f %f",screen.displayid,roundf(screen.frame.origin.x/kDefaultDisplayScale),roundf(screen.frame.origin.y/kDefaultDisplayScale));
		//if (screen.isMain) {
			//if (!FloatEqual(roundf(screen.frame.origin.x/kDefaultDisplayScale), 0.f) || !FloatEqual(roundf(screen.frame.origin.y/kDefaultDisplayScale), 0.f)) {
				CGRect bounds = CGDisplayBounds(screen.displayid);
				
				x = roundf(screen.frame.origin.x/kDefaultDisplayScale);
				y = roundf(screen.frame.origin.y/kDefaultDisplayScale);
			//} else {
			//	NSLog(@"moving other display x: %f",roundf(screen.frame.origin.x/kDefaultDisplayScale));
			//	NSLog(@"moving other display y: %f",roundf(screen.frame.origin.y/kDefaultDisplayScale));	
			//}
		//}
		//NSLog(@" ");
	}
	NSLog(@"%f %f",x, y);
	/*NSPredicate *pred_dis = [NSPredicate predicateWithFormat:@"displayid == %llu",view.displayid];
	NSArray *results_dis = [[self subviews] filteredArrayUsingPredicate:pred_dis];	
	for (SMDSScreenView *screen in results_dis) {
			NSLog(@"%f %f",roundf(screen.frame.origin.x/kDefaultDisplayScale), roundf(screen.frame.origin.y/kDefaultDisplayScale));
		x = roundf(screen.frame.origin.x/kDefaultDisplayScale) - x;
		y = roundf(screen.frame.origin.y/kDefaultDisplayScale) - y;
	}*/
	//NSLog(@"---------------------------");
	/*NSPredicate *pred = [NSPredicate predicateWithFormat:@"displayid == %llu",CGMainDisplayID()];
	NSArray *results = [[self subviews] filteredArrayUsingPredicate:pred];	
	for (SMDSScreenView *screen in results) {
		if (screen != view) {
			NSLog(@"%f %f",screen.frame.origin.x, view.frame.origin.x);
			NSLog(@"%f %f",screen.frame.origin.y, view.frame.origin.y);
			x = (screen.frame.origin.x + view.frame.origin.x)/kDefaultDisplayScale;
			y = (screen.frame.origin.y + view.frame.origin.y)/kDefaultDisplayScale;
			NSLog(@"%f %f",x, y);
		}
	}*/
	return CGPointMake(x, y);
}

- (void)translateOrigin:(CGPoint)opoint translateDisplay:(NSUInteger)displayid toPoint:(CGPoint)dpoint {
	NSLog(@"==================");
	NSLog(@"%i %i", (int32_t)opoint.x, (int32_t)opoint.y);
	NSLog(@"%i %i", (int32_t)dpoint.x, (int32_t)dpoint.y);
	NSLog(@"==================");
	CGDisplayConfigRef config;
	CGError code = CGBeginDisplayConfiguration(&config);
	if (code == kCGErrorSuccess) {
		if (displayid == CGMainDisplayID()) {
			NSLog(@"moving main");
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"displayid != %llu",displayid];
			NSArray *results = [[self subviews] filteredArrayUsingPredicate:pred];	
			for (SMDSScreenView *screen in results) {
				CGRect bounds = CGDisplayBounds(screen.displayid);
				CGFloat x = bounds.origin.x + opoint.x;
				CGFloat y = bounds.origin.y + opoint.y;
				NSLog(@"%i %i", (int32_t)x, (int32_t)y);
				CGConfigureDisplayOrigin(config, screen.displayid, (int32_t)x, (int32_t)y);
			}
		} else {
			NSLog(@"moving other");
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"displayid == %llu",displayid];
			NSArray *results = [[self subviews] filteredArrayUsingPredicate:pred];	
			for (SMDSScreenView *screen in results) {
				CGRect bounds = CGDisplayBounds(screen.displayid);
				CGFloat x = bounds.origin.x + dpoint.x;
				CGFloat y = bounds.origin.y + dpoint.y;
				NSLog(@"%i %i", (int32_t)x, (int32_t)y);
				//CGConfigureDisplayOrigin(config, screen.displayid, (int32_t)x, (int32_t)y);
			}
		}
	}
	CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
}

- (void)dealloc {
	[displayHighlight release];
	[super dealloc];
}

@end