
#import "CoffeeMachine.h"
#import <Coffee/Coffee.h>

@implementation CoffeeMachine

- (instancetype)initWithCoffee:(Coffee *)coffee;
{
    self = [super init];
    _coffee = coffee;
    return self;
}

- (void)brew;
{
    NSLog(@"Brewing %@ with density %f", self.coffee.name, self.coffee.density);
}

@end
