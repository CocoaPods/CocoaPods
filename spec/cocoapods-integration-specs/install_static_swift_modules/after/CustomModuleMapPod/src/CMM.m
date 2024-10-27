#import <CustomModuleMapPod/CMM.h>
#import <CustomModuleMapPod/CMM+Private.h>
#import <CustomModuleMapPod/CMMFunctions.h>

#import <Foundation/Foundation.h>

@implementation CMM
+ (void)log { NSLog(@"module maps are the wurst"); }
@end

void CMM_doThing(void) {
    NSLog(@"CMM doing thing");
}
