/**
 * TableViewRowExtension
 *
 * Created by Your Name
 * Copyright (c) 2015 Your Company. All rights reserved.
 */

#import "DeMarcbenderTableviewextensionModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

// Forward declaration — defined in TiUITableView+SmoothScrolling.m
extern void TVECleanupCaches(void);

@implementation DeMarcbenderTableviewextensionModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"4d5dcf39-79ad-4fb6-826b-b966ed7faaeb";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"de.marcbender.tableviewextension";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];

	NSLog(@"[INFO] %@ loaded",self);
}

-(void)shutdown:(id)sender
{
	// Clean up caches and locks to prevent memory leaks on module unload
	TVECleanupCaches();

	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup

-(void)dealloc
{
	// release any resources that have been retained by the module
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// Clear caches to free memory when the system is under pressure
	TVECleanupCaches();

	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
	if (count == 1 && [type isEqualToString:@"my_event"])
	{
		// the first (of potentially many) listener is being added
		// for event named 'my_event'
	}
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
	if (count == 0 && [type isEqualToString:@"my_event"])
	{
		// the last listener called for event named 'my_event' has
		// been removed, we can optionally clean up any resources
		// since no body is listening at this point for that event
	}
}

#pragma Public APIs

-(id)example:(id)args
{
	// example method
	return @"hello world";
}

-(id)exampleProp
{
	// example property getter
	return @"hello world";
}

-(void)setExampleProp:(id)value
{
	// example property setter
}

@end
