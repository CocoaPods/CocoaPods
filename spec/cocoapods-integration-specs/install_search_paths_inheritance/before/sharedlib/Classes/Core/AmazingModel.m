#import <CocoaLumberjack/CocoaLumberjack.h>
#import <logger/Logger.h>
#import <asserts/Asserts.h>

#import "AmazingModel.h"

@implementation AmazingModel

- (NSString *)description {
    [Logger whatever];
}

- (void)_nothing {
    DDLogInfo(@"using cocoa lumberjack");
}

@end