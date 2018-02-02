//
//  ModelThing.m
//  Static Swift
//
//  Created by Samuel Giddins on 1/23/18.
//  Copyright © 2018 Samuel Giddins. All rights reserved.
//

#import "ModelThing.h"

@import MixedPod;
@import SwiftPod;
@import ObjCPod;

@import CustomModuleMapPod;

@import CustomModuleMapPod.Private;

@implementation ModelThing
+ (instancetype)copy {
    [CMM log]; // CustomModuleMapPod
    CMM_doThing(); // CustomModuleMapPod.Private
    [BCE meow]; // MixedPod
    [ABC bark]; // ObjCPod
    [XYZ.new doThing:@"objc thing?"]; // from SwiftPod
    return [self.class new];
}
@end
