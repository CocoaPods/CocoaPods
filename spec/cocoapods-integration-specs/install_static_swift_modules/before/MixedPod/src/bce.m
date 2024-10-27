#import <MixedPod/bce.h>

#if __has_include(<MixedPod/MixedPod-Swift.h>)
#    import <MixedPod/MixedPod-Swift.h>
#else
// This really shouldn't be neccessary (ideally the first would just work)
// Additionally, it shouldn't show as "not found" in the navigator
#    import "MixedPod-Swift.h"
#endif

@import ObjCPod;
@import SwiftPod;

#import <Foundation/Foundation.h>

@implementation BCE
+ (void)meow {
    id a = [ABC new]; // from ObjCPod
    [[XYZ new] doThing:@"in bce.m"]; // from SwiftPod
    NSLog(@"meow meow");
    (void)[[Foo alloc] initWithS:a]; // from MixedPod
}
@end
