//
//  SEGModule.m
//  SEGModules
//
//  Created by Samuel E. Giddins on 1/24/14.
//  Copyright (c) 2014 Samuel E. Giddins. All rights reserved.
//

#import "SEGModule.h"
#import <objc/runtime.h>

#ifdef DEBUG
#define MDBLog(...) NSLog(__VA_ARGS__)
static const char *true_s = "YES";
static const char *false_s = "NO";
#else
#define MDBLog(...)
#endif

@implementation SEGModule

@end

@interface NSObject (SEGModule)

@end

static void SEGCopyProtocolMethodsToClass(Protocol *protocol, Class protocolClass, Class class, BOOL requiredMethods, BOOL instanceMethods)
{
    unsigned int methodCount = 0;
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, requiredMethods, instanceMethods, &methodCount);
    for (int j = 0; j < methodCount; j++) {
        struct objc_method_description method = methods[j];
        if (instanceMethods) {
            Method moduleMethod = class_getInstanceMethod(protocolClass, method.name);
            IMP moduleIMP = method_getImplementation(moduleMethod);
            if (moduleMethod) {
                class_addMethod(class, method.name, moduleIMP, method.types);
                MDBLog(@"Added %@ method %s (required method: %s, class method: %s) to %@", protocolClass, sel_getName(method_getName(moduleMethod)), requiredMethods ? true_s : false_s, !instanceMethods ? true_s : false_s, class);
            } else {
                MDBLog(@"Failed to add %@ method %s (required method: %s, class method: %s) to %@", protocolClass, sel_getName(method_getName(moduleMethod)), requiredMethods ? true_s : false_s, !instanceMethods ? true_s : false_s, class);
            }
        } else {
            Method moduleMethod = class_getClassMethod(protocolClass, method.name);
            IMP moduleIMP = method_getImplementation(moduleMethod);
            if (moduleMethod) {
                class_addMethod(object_getClass(class), method.name, moduleIMP, method.types);
                MDBLog(@"Added %@ method %s (required method: %s, class method: %s) to %@", protocolClass, sel_getName(method_getName(moduleMethod)), requiredMethods ? true_s : false_s, !instanceMethods ? true_s : false_s, class);
            } else {
                MDBLog(@"Failed to add %@ method %s (required method: %s, class method: %s) to %@", protocolClass, sel_getName(method_getName(moduleMethod)), requiredMethods ? true_s : false_s, !instanceMethods ? true_s : false_s, class);
            }
        }
    }
    free(methods);
}

static void SEGLoadModulesForClass(Class class)
{
    unsigned int protocolCount = 0;
    Protocol **protocols = class_copyProtocolList(class, &protocolCount);
    for (int i = 0; i < protocolCount; i++) {
        Protocol *protocol = protocols[i];
        const char *protocolName = protocol_getName(protocol);
        Class protocolClass = objc_getClass(protocolName);
        BOOL protocolClassIsModule = [protocolClass isSubclassOfClass:[SEGModule class]];
        if (protocolClass && protocolClassIsModule && protocolClass != class) {
            SEGCopyProtocolMethodsToClass(protocol, protocolClass, class, YES, YES);
            SEGCopyProtocolMethodsToClass(protocol, protocolClass, class, YES, NO);
            SEGCopyProtocolMethodsToClass(protocol, protocolClass, class, NO, YES);
            SEGCopyProtocolMethodsToClass(protocol, protocolClass, class, NO, NO);
        }
    }
    free(protocols);
}

@implementation NSObject (SEGModule)

+ (void)load
{
    int numClasses;
    Class *classes = NULL;

    classes = NULL;
    numClasses = objc_getClassList(NULL, 0);

    if (numClasses > 0) {
        classes = malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class class = classes[i];
            SEGLoadModulesForClass(class);
        }
        free(classes);
    }
}

@end
