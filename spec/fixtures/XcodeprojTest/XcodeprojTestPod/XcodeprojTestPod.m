#import "XcodeprojTestPod.h"

#import "Subproject/Subproject/Subproject.h"

@implementation XcodeprojTestPod

+ (NSInteger)twenty
{
    return [Subproject twelve] + 8;
}

@end
