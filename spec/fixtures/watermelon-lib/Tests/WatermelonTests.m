#import <XCTest/XCTest.h>

#import "WatermelonTestHeader.h"


@interface WatermelonTests : XCTestCase

@end

@implementation WatermelonTests

- (void)testResourceLoading {
    NSString *testResourcesBundlePath = [[NSBundle bundleForClass:[WatermelonTests class]] pathForResource:@"WatermelonLibTestResources" ofType:@"bundle"];
    NSBundle *testResourcesbundle = [NSBundle bundleWithPath:testResourcesBundlePath];
    XCTAssertNotNil([WatermelonTests imageFromBundle:testResourcesbundle image:@"watermelon-xxl-blue"]);
    XCTAssertNotNil([WatermelonTests imageFromBundle:testResourcesbundle image:@"watermelon-xxl-green"]);
    XCTAssertNotNil([WatermelonTests imageFromBundle:testResourcesbundle image:@"watermelon-xxl-purple"]);
    XCTAssertNotNil([WatermelonTests imageFromBundle:testResourcesbundle image:@"watermelon-xxl-yellow1"]);
}

+(UIImage *)imageFromBundle:(NSBundle *)bundle image:(NSString *)image
{
    NSString *imagePath = [bundle pathForResource:image ofType:@"png"];
    return [UIImage imageWithContentsOfFile:imagePath];
}

@end
