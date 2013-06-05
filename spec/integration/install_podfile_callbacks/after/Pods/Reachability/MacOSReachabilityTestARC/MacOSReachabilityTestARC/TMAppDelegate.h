//
//  TMAppDelegate.h
//  MacOSReachabilityTestARC
//
//  Created by Tony Million on 21/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (assign, nonatomic) IBOutlet NSTextField * blockLabel;
@property (assign, nonatomic) IBOutlet NSTextField * notificationLabel;

@end
