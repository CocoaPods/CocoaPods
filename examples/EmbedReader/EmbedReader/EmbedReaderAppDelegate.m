//
//  EmbedReaderAppDelegate.m
//  EmbedReader
//
//  Created by spadix on 5/2/11.
//

#import "EmbedReaderAppDelegate.h"
#import "EmbedReaderViewController.h"

@implementation EmbedReaderAppDelegate
@synthesize window=_window;
@synthesize viewController=_viewController;

- (BOOL)            application: (UIApplication*) application
  didFinishLaunchingWithOptions: (NSDictionary*) launchOptions
{
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];

    // force view class to load so it may be referenced directly from NIB
    [ZBarReaderView class];

    return(YES);
}

- (void) dealloc
{
    [_window release];
    [_viewController release];
    [super dealloc];
}

@end
