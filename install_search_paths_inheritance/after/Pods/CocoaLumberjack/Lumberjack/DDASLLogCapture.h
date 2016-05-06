//
//  DDASLLogCapture.h
//  Lumberjack
//
//  Created by Dario Ahdoot on 3/17/14.
//
//

#import "DDASLLogger.h"

@protocol DDLogger;

@interface DDASLLogCapture : NSObject

+ (void)start;
+ (void)stop;

// Default log level: LOG_LEVEL_VERBOSE (i.e. capture all ASL messages).
+ (int)captureLogLevel;
+ (void)setCaptureLogLevel:(int)LOG_LEVEL_XXX;

@end

