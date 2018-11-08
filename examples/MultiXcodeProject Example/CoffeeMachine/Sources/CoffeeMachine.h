
#import <Foundation/Foundation.h>
@class Coffee;

NS_ASSUME_NONNULL_BEGIN

@interface CoffeeMachine : NSObject

- (instancetype)initWithCoffee:(Coffee *)coffee;

- (void)brew;

@property (nonatomic) Coffee *coffee;

@end

NS_ASSUME_NONNULL_END
