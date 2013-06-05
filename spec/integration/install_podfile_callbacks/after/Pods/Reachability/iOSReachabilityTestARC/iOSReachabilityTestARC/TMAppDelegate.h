//
//  TMAppDelegate.h
//  iOSReachabilityTestARC
//
//  Created by Tony Million on 21/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TMViewController;

@interface TMAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) TMViewController *viewController;

@end
