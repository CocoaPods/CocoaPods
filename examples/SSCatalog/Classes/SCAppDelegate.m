//
//  SCAppDelegate.m
//  SSCatalog
//
//  Created by Sam Soffes on 9/21/09.
//  Copyright 2009 Sam Soffes, Inc. All rights reserved.
//

#import "SCAppDelegate.h"
#import "SCRootViewController.h"

@implementation SCAppDelegate {
	UIWindow *_window;
	UINavigationController *_navigationController;
}


#pragma mark - Accessors

@synthesize window = _window;
@synthesize navigationController = _navigationController;


#pragma mark - NSObject

- (void)dealloc {
	[_navigationController release];
    [_window release];
    [super dealloc];
}


#pragma mark - UIApplicationDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application {    

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	SCRootViewController *viewController = [[SCRootViewController alloc] initWithStyle:UITableViewStyleGrouped];
	UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:viewController];

	self.navigationController = aNavigationController;

	[viewController release];
	[aNavigationController release];
	
	[_window addSubview:_navigationController.view];
    [_window makeKeyAndVisible];
}

@end
