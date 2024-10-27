//
//  RKValueTransformers.m
//  RestKit
//
//  Created by Blake Watters on 8/18/13.
//  Copyright (c) 2012 RestKit. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#include <time.h>
#include <xlocale.h>
#import "RKValueTransformers.h"

NSString *const RKValueTransformersErrorDomain = @"org.restkit.RKValueTransformers.ErrorDomain";
NSString *const RKValueTransformersDetailedErrorsKey = @"detailedErrors";

static BOOL RKVTClassIsCollection(Class aClass)
{
    return (aClass && ([aClass isSubclassOfClass:[NSSet class]] ||
                       [aClass isSubclassOfClass:[NSArray class]] ||
                       [aClass isSubclassOfClass:[NSOrderedSet class]]));
}

@implementation RKValueTransformer

- (id)init
{
    if ([self class] == [RKValueTransformer class]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"`%@` is abstract and cannot be directly instantiated. "
                                               @"Instantiate a subclass implementation instead.",
                                               NSStringFromClass([self class])]
                                     userInfo:nil];
    }
    return [super init];
}

#pragma mark RKValueTransforming

- (BOOL)transformValue:(id)inputValue toValue:(__autoreleasing id *)outputValue ofClass:(Class)outputValueClass error:(NSError *__autoreleasing *)error
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"`RKValueTransformer` subclasses must provide a concrete implementation of `%@`.",
                                           NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

#pragma mark Default Transformers

+ (instancetype)singletonValueTransformer:(RKBlockValueTransformer * __strong *)valueTransformer
                                     name:(NSString *)name
                                onceToken:(dispatch_once_t *)onceToken
                          validationBlock:(BOOL (^)(Class sourceClass, Class destinationClass))validationBlock
                      transformationBlock:(BOOL (^)(id inputValue, id *outputValue, Class outputValueClass, NSError **error))transformationBlock
{
    dispatch_once(onceToken, ^{
        RKBlockValueTransformer *transformer = [RKBlockValueTransformer valueTransformerWithValidationBlock:validationBlock transformationBlock:transformationBlock];
        transformer.name = name;
        *valueTransformer = transformer;
    });
    return *valueTransformer;
}

+ (instancetype)identityValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:nil transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, __unsafe_unretained Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestTransformation([inputValue isKindOfClass:outputValueClass], error, @"The given value is not already an instance of '%@'", outputValueClass);
        *outputValue = inputValue;
        return YES;
    }];
}

+ (instancetype)stringToURLValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSURL class]]) ||
                ([sourceClass isSubclassOfClass:[NSURL class]] && [destinationClass isSubclassOfClass:[NSString class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSURL class]]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSString class], [NSURL class]]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSURL *URL = [NSURL URLWithString:inputValue];
            RKValueTransformerTestTransformation(URL != nil, error, @"Failed transformation of '%@' to URL: the string is malformed and cannot be transformed to an `NSURL` representation.", inputValue);
            *outputValue = URL;
        } else if ([inputValue isKindOfClass:[NSURL class]]) {
            *outputValue = [(NSURL *)inputValue absoluteString];
        }
        return YES;
    }];
}

+ (instancetype)numberToStringValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSNumber class]] && [destinationClass isSubclassOfClass:[NSString class]]) ||
                ([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSString class] ]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSNumber class], [NSString class]]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSString *lowercasedString = [inputValue lowercaseString];
            NSSet *trueStrings = [NSSet setWithObjects:@"true", @"t", @"yes", @"y", nil];
            NSSet *booleanStrings = [trueStrings setByAddingObjectsFromSet:[NSSet setWithObjects:@"false", @"f", @"no", @"n", nil]];
            if ([booleanStrings containsObject:lowercasedString]) {
                // Handle booleans encoded as Strings
                *outputValue = [NSNumber numberWithBool:[trueStrings containsObject:lowercasedString]];
            } else if ([lowercasedString rangeOfString:@"."].location != NSNotFound) {
                // String -> Floating Point Number
                // Only use floating point if needed to avoid losing precision on large integers
                *outputValue = [NSNumber numberWithDouble:[lowercasedString doubleValue]];
            } else {
                // String -> Signed Integer
                *outputValue = [NSNumber numberWithLongLong:[lowercasedString longLongValue]];
            }
        } else if ([inputValue isKindOfClass:[NSNumber class]]) {
            if (NSClassFromString(@"__NSCFBoolean") && [inputValue isKindOfClass:NSClassFromString(@"__NSCFBoolean")]) {
                *outputValue = [inputValue boolValue] ? @"true" : @"false";
            } else if (NSClassFromString(@"NSCFBoolean") && [inputValue isKindOfClass:NSClassFromString(@"NSCFBoolean")]) {
                *outputValue = [inputValue boolValue] ? @"true" : @"false";
            } else {
                *outputValue = [inputValue stringValue];
            }
        }
        return YES;
    }];
}

+ (instancetype)arrayToOrderedSetValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSArray class]] && [destinationClass isSubclassOfClass:[NSOrderedSet class]]) ||
                ([sourceClass isSubclassOfClass:[NSOrderedSet class]] && [destinationClass isSubclassOfClass:[NSArray class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSArray class], [NSOrderedSet class]]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSArray class], [NSOrderedSet class]]), error);
        if ([inputValue isKindOfClass:[NSArray class]]) {
            *outputValue = [NSOrderedSet orderedSetWithArray:inputValue];
        } else if ([inputValue isKindOfClass:[NSOrderedSet class]]) {
            *outputValue = [inputValue array];
        }
        return YES;
    }];
}

+ (instancetype)arrayToSetValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSArray class]] && [destinationClass isSubclassOfClass:[NSSet class]]) ||
                ([sourceClass isSubclassOfClass:[NSSet class]] && [destinationClass isSubclassOfClass:[NSArray class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSSet class], [NSArray class]]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSSet class], [NSArray class]]), error);
        if ([inputValue isKindOfClass:[NSArray class]]) {
            if ([outputValueClass isSubclassOfClass:[NSMutableSet class]]) *outputValue = [NSMutableSet setWithArray:inputValue];
            else *outputValue = [NSSet setWithArray:inputValue];
        } else if ([inputValue isKindOfClass:[NSSet class]]) {
            if ([outputValueClass isSubclassOfClass:[NSMutableArray class]]) *outputValue = [[inputValue allObjects] mutableCopy];
            else *outputValue = [inputValue allObjects];
        }
        return YES;
    }];
}

+ (instancetype)decimalNumberToStringValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSDecimalNumber class]] && [destinationClass isSubclassOfClass:[NSString class]]) ||
                ([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSDecimalNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSDecimalNumber class]]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSString class], [NSDecimalNumber class]]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSDecimalNumber *decimalNumber = [NSDecimalNumber decimalNumberWithString:inputValue];
            RKValueTransformerTestTransformation(! [decimalNumber isEqual:[NSDecimalNumber notANumber]], error, @"Failed transformation of '%@' to `NSDecimalNumber`: the input string was transformed into Not a Number (NaN) value.", inputValue);
            *outputValue = decimalNumber;
        } else if ([inputValue isKindOfClass:[NSDecimalNumber class]]) {
            *outputValue = [inputValue stringValue];
        }
        return YES;
    }];
}

+ (instancetype)decimalNumberToNumberValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSDecimalNumber class]] && [destinationClass isSubclassOfClass:[NSNumber class]]) ||
                ([sourceClass isSubclassOfClass:[NSNumber class]] && [destinationClass isSubclassOfClass:[NSDecimalNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSDecimalNumber class]]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSNumber class], [NSDecimalNumber class]]), error);
        if ([inputValue isKindOfClass:[NSNumber class]]) {
            *outputValue = [NSDecimalNumber decimalNumberWithDecimal:[inputValue decimalValue]];
        } else if ([inputValue isKindOfClass:[NSDecimalNumber class]]) {
            *outputValue = inputValue;
        }
        return YES;
    }];
}

+ (instancetype)nullValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:nil transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, [NSNull class], error);
        *outputValue = nil;
        return YES;
    }];
}

+ (instancetype)keyedArchivingValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass conformsToProtocol:@protocol(NSCoding)] && [destinationClass isSubclassOfClass:[NSData class]]) ||
                ([sourceClass isSubclassOfClass:[NSData class]] && [destinationClass conformsToProtocol:@protocol(NSCoding)]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        if ([inputValue isKindOfClass:[NSData class]]) {
            id unarchivedValue = nil;
            @try {
                unarchivedValue = [NSKeyedUnarchiver unarchiveObjectWithData:inputValue];
            }
            @catch (NSException *exception) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"An `%@` exception was encountered while attempting to unarchive the given inputValue.", [exception name]], @"exception": exception };
                if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorTransformationFailed userInfo:userInfo];
                return NO;
            }
            if (! [unarchivedValue isKindOfClass:outputValueClass]) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `outputValueClass` of type `%@`, but the unarchived object is a `%@`.", outputValueClass, [unarchivedValue class]] };
                if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorTransformationFailed userInfo:userInfo];
                return NO;
            }
            *outputValue = unarchivedValue;
        } else if ([inputValue conformsToProtocol:@protocol(NSCoding)]) {
            RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, [NSData class], error);
            *outputValue = [NSKeyedArchiver archivedDataWithRootObject:inputValue];
        } else {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `inputValue` of type `NSData` or conforming to `NSCoding`, but got a `%@` which does not satisfy these expectation.", [inputValue class]] };
            if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        return YES;
    }];
}

+ (instancetype)timeIntervalSince1970ToDateValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return ((([sourceClass isSubclassOfClass:[NSString class]] || [sourceClass isSubclassOfClass:[NSNumber class]]) && [destinationClass isSubclassOfClass:[NSDate class]]) ||
                ([sourceClass isSubclassOfClass:[NSDate class]] && ([destinationClass isSubclassOfClass:[NSNumber class]] || [destinationClass isSubclassOfClass:[NSString class]])));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, __unsafe_unretained Class outputValueClass, NSError *__autoreleasing *error) {
        static dispatch_once_t onceToken;
        static NSNumberFormatter *numberFormatter;
        dispatch_once(&onceToken, ^{
            numberFormatter = [NSNumberFormatter new];
            numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        });
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSString class], [NSDate class] ]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSNumber class], [NSString class], [NSDate class] ]), error);
        if ([outputValueClass isSubclassOfClass:[NSDate class]]) {
            if ([inputValue isKindOfClass:[NSNumber class]]) {
                *outputValue = [NSDate dateWithTimeIntervalSince1970:[inputValue doubleValue]];
            } else if ([inputValue isKindOfClass:[NSString class]]) {
                if ([[inputValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
                    *outputValue = nil;
                    return YES;
                }
                NSString *errorDescription = nil;
                NSNumber *formattedNumber;
                BOOL success = [numberFormatter getObjectValue:&formattedNumber forString:inputValue errorDescription:&errorDescription];
                RKValueTransformerTestTransformation(success, error, @"%@", errorDescription);
                *outputValue = [NSDate dateWithTimeIntervalSince1970:[formattedNumber doubleValue]];
            }
        } else if ([outputValueClass isSubclassOfClass:[NSNumber class]]) {
            *outputValue = @([inputValue timeIntervalSince1970]);
        } else if ([outputValueClass isSubclassOfClass:[NSString class]]) {
            *outputValue = [numberFormatter stringForObjectValue:@([inputValue timeIntervalSince1970])];
        }
        return YES;
    }];
}

+ (instancetype)iso8601TimestampToDateValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSDate class]]) ||
                ([sourceClass isSubclassOfClass:[NSDate class]] && [destinationClass isSubclassOfClass:[NSString class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, __unsafe_unretained Class outputValueClass, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSDate class] ]), error);
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSString class], [NSDate class] ]), error);
        if ([outputValueClass isSubclassOfClass:[NSDate class]]) {
            static unsigned int const ISO_8601_MAX_LENGTH = 29;

            if ([(NSString *)inputValue length] == 0) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot transform a zero length string"] };
                if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
                return NO;
            }

            static NSRegularExpression *validISO8601RegularExpression = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSError *error = nil;
                static const char * REGEX_ISO8601_TIMESTAMP =
                "\\A(\\d{4})-(\\d{2})-(\\d{2})[T\\s](\\d{2}):(\\d{2}):(\\d{2})" // Mandatory - YYYY-MM-DD(T|\s)hh:mm:ss
                "(?:"
                "[.](\\d{1,6})"                                   // Optional - .nnnnnn
                ")?"
                "(?:"
                "([+-])(\\d{2}):?(\\d{2})|Z"                       // Optional -[+-]hh:?mm or Z
                ")?\\z";
                NSString *regexString = [[NSString alloc] initWithUTF8String:REGEX_ISO8601_TIMESTAMP];
                validISO8601RegularExpression = [NSRegularExpression regularExpressionWithPattern:regexString
                                                                                          options:NSRegularExpressionCaseInsensitive
                                                                                            error:&error];

                if (! validISO8601RegularExpression) [NSException raise:NSInternalInconsistencyException format:@"The ISO 8601 validation regex failed to parse: %@", error];
            });

            if (! [validISO8601RegularExpression numberOfMatchesInString:(NSString *)inputValue options:0 range:NSMakeRange(0, [inputValue length])]) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Input value is not a valid ISO 8601 string: '%@'", inputValue] };
                if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
                return NO;
            }
            
            /* Strip milliseconds prior to parsing */
            double milliseconds = 0.f;
            if (19 < [inputValue length] && ([inputValue characterAtIndex:19] == '.' || [inputValue characterAtIndex:19] == ':')) {
                NSMutableString *newInputString = [NSMutableString stringWithString:[inputValue substringToIndex:19]];
                NSMutableString *millisecondsString = [NSMutableString new];
                
                NSUInteger index = 20;
                for (; index < [inputValue length]; index++)
                {
                    unichar digit = [inputValue characterAtIndex:index];
                    if(digit >= '0' && digit <= '9')
                        [millisecondsString appendString:[NSString stringWithFormat:@"%C", digit]];
                    else
                        break;
                }
                
                if (index != 20 && index < [inputValue length])
                    [newInputString appendString:[inputValue substringFromIndex:index]];
                
                inputValue = [NSString stringWithString:newInputString];
                milliseconds = [millisecondsString doubleValue]/1000.f;
            }
            
            const char *constSource = [(NSString *)inputValue cStringUsingEncoding:NSUTF8StringEncoding];
            size_t length = strlen(constSource);
            
            char source[ISO_8601_MAX_LENGTH];
            memcpy(source, constSource, sizeof (source));
            if (constSource[10] != 'T')
                source[10] = 'T';
            
            char destination[ISO_8601_MAX_LENGTH];
            if (length == 19) {
                memcpy(destination, source, length);
                strncpy(destination + length, "+0000\0", 6);
            }else if (length == 20 && source[length - 1] == 'Z') {
                memcpy(destination, source, length - 1);
                strncpy(destination + length - 1, "+0000\0", 6);
            } else {
                memcpy(destination, source, sizeof (destination));
                if (length == 25 && source[22] == ':') {
                    destination[22] = destination[23];
                    destination[23] = destination[24];
                    destination[24] = '\0';
                }
            }
            
            struct tm time = {
                .tm_isdst = -1,
            };
            
            strptime_l(destination, "%FT%T%z", &time, NULL);
            
            time_t timeIntervalSince1970 = mktime(&time);
            RKValueTransformerTestTransformation(timeIntervalSince1970 != -1, error, @"Failed transformation to date representation: time range is beyond the bounds supported by mktime");
            *outputValue = [NSDate dateWithTimeIntervalSince1970:((double)timeIntervalSince1970 + milliseconds)];
        } else if ([outputValueClass isSubclassOfClass:[NSString class]]) {
            static NSDateFormatter *iso8601DateFormatter = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                iso8601DateFormatter = [[NSDateFormatter alloc] init];
                [iso8601DateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
                [iso8601DateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                [iso8601DateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
            });
            *outputValue = [iso8601DateFormatter stringFromDate:(NSDate *)inputValue];
        }
        return YES;
    }];
}

+ (instancetype)stringValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return ([sourceClass instancesRespondToSelector:@selector(stringValue)] && [destinationClass isSubclassOfClass:[NSString class]]);
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        if (! [inputValue respondsToSelector:@selector(stringValue)]) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Expected an `inputValue` that responds to `stringValue`, but it does not." };
            if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, [NSString class], error);
        *outputValue = [inputValue stringValue];
        return YES;
    }];
}

+ (instancetype)objectToCollectionValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (!RKVTClassIsCollection(sourceClass) && RKVTClassIsCollection(destinationClass));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        if (RKVTClassIsCollection([inputValue class])) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `inputValue` that is not a collection, but got a `%@`.", [inputValue class]] };
            if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSArray class], [NSSet class], [NSOrderedSet class]]), error);
        if ([outputValueClass isSubclassOfClass:[NSMutableArray class]]) *outputValue = [NSMutableArray arrayWithObject:inputValue];
        else if ([outputValueClass isSubclassOfClass:[NSMutableSet class]]) *outputValue = [NSMutableSet setWithObject:inputValue];
        else if ([outputValueClass isSubclassOfClass:[NSMutableOrderedSet class]]) *outputValue = [NSMutableOrderedSet orderedSetWithObject:inputValue];
        else if ([outputValueClass isSubclassOfClass:[NSArray class]]) *outputValue = @[ inputValue ];
        else if ([outputValueClass isSubclassOfClass:[NSSet class]]) *outputValue = [NSSet setWithObject:inputValue];
        else if ([outputValueClass isSubclassOfClass:[NSOrderedSet class]]) *outputValue = [NSOrderedSet orderedSetWithObject:inputValue];
        RKValueTransformerTestTransformation(*outputValue, error, @"Failed to transform value into collection %@", outputValueClass);
        return YES;
    }];
}

+ (instancetype)mutableValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    NSArray *mutableClasses = @[ [NSMutableArray class], [NSMutableDictionary class], [NSMutableString class], [NSMutableSet class], [NSMutableOrderedSet class], [NSMutableData class], [NSMutableIndexSet class], [NSMutableString class], [NSMutableAttributedString class] ];
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        /**
         NOTE: Because of class clusters in Foundation you cannot make any assumptions about mutability based on classes. For example, given `__NSArrayI` (immutable array) and a destination class of `NSMutableArray`, `isSubClassOfClass:` will not evaluate to `YES`. If you want a mutable result, you need to invoke `mutableCopy`.
         */
        return [sourceClass conformsToProtocol:@protocol(NSMutableCopying)] && [mutableClasses containsObject:destinationClass];
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, __unsafe_unretained Class outputValueClass, NSError *__autoreleasing *error) {
        if (! [inputValue conformsToProtocol:@protocol(NSMutableCopying)]) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `inputValue` that conforms to `NSMutableCopying`, but `%@` objects do not.", [inputValue class]] };
            if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, mutableClasses, error);
        *outputValue = [inputValue mutableCopy];
        return YES;
    }];
}

+ (instancetype)keyOfDictionaryValueTransformer
{
    static dispatch_once_t onceToken;
    static RKBlockValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer name:NSStringFromSelector(_cmd) onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return ([sourceClass conformsToProtocol:@protocol(NSCopying)] && [destinationClass isSubclassOfClass:[NSDictionary class]]);
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
        if (! [inputValue conformsToProtocol:@protocol(NSCopying)]) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Expected an `inputValue` that conforms to `NSCopying`, but it does not." };
            if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, [NSDictionary class], error);
        if ([outputValueClass isSubclassOfClass:[NSMutableDictionary class]]) {
            *outputValue = [NSMutableDictionary dictionaryWithObject:[NSMutableDictionary dictionary] forKey:inputValue];
        } else {
            *outputValue = @{ inputValue: @{} };
        }

        return YES;
    }];
}

static RKCompoundValueTransformer *RKDefaultValueTransformer;
static dispatch_once_t RKDefaultValueTransformerOnceToken;

+ (RKCompoundValueTransformer *)defaultValueTransformer
{
    dispatch_once(&RKDefaultValueTransformerOnceToken, ^{
        if (! RKDefaultValueTransformer) {
            RKDefaultValueTransformer = [RKCompoundValueTransformer compoundValueTransformerWithValueTransformers:@[
                                         [self identityValueTransformer],
                                         [self stringToURLValueTransformer],

                                         // `NSDecimalNumber` transformers must be consulted ahead of `NSNumber` transformers because `NSDecimalNumber` is a subclass thereof
                                         [self decimalNumberToNumberValueTransformer],
                                         [self decimalNumberToStringValueTransformer],

                                         [self numberToStringValueTransformer],
                                         [self arrayToOrderedSetValueTransformer],
                                         [self arrayToSetValueTransformer],
                                         [self nullValueTransformer],
                                         [self keyedArchivingValueTransformer],
                                         [self stringValueTransformer],
                                         [self objectToCollectionValueTransformer],
                                         [self stringValueTransformer],
                                         [self keyOfDictionaryValueTransformer],
                                         [self mutableValueTransformer],
                                         ]];

            // Default date formatters
            [RKDefaultValueTransformer addValueTransformer:[self iso8601TimestampToDateValueTransformer]];
            [RKDefaultValueTransformer addValueTransformer:[self timeIntervalSince1970ToDateValueTransformer]];

            // The latter three date format strings below represent the three
            // date formats specified by the HTTP/1.1 protocol.  See
            // http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1
            // for details
            NSArray *defaultDateFormatStrings = @[
                                                  @"MM/dd/yyyy",
                                                  @"yyyy-MM-dd",
                                                  @"EEE, dd MMM yyyy HH:mm:ss zzz", // RFC 1123
                                                  @"EEEE, dd-MMM-yy HH:mm:ss zzz", // RFC 850
                                                  @"EEE MMM d HH:mm:ss yyyy" // ANSI C asctime()
                                                  ];
            for (NSString *dateFormatString in defaultDateFormatStrings) {
                NSDateFormatter *dateFormatter = [NSDateFormatter new];
                dateFormatter.dateFormat = dateFormatString;
                dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                [RKDefaultValueTransformer addValueTransformer:dateFormatter];
            }
        }
    });
    return RKDefaultValueTransformer;
}

+ (void)setDefaultValueTransformer:(RKCompoundValueTransformer *)compoundValueTransformer
{
    RKDefaultValueTransformerOnceToken = 0; // resets the once_token so dispatch_once will run again
    RKDefaultValueTransformer = compoundValueTransformer;
}

@end

@interface RKBlockValueTransformer ()
@property (nonatomic, copy) BOOL (^validationBlock)(Class, Class);
@property (nonatomic, copy) BOOL (^transformationBlock)(id, id *, Class, NSError **);
@end

@implementation RKBlockValueTransformer

+ (instancetype)valueTransformerWithValidationBlock:(BOOL (^)(Class sourceClass, Class destinationClass))validationBlock
                                transformationBlock:(BOOL (^)(id inputValue, id *outputValue, Class outputClass, NSError **error))transformationBlock
{
    if (! transformationBlock) [NSException raise:NSInvalidArgumentException format:@"The `transformationBlock` cannot be `nil`."];
    RKBlockValueTransformer *valueTransformer = [self new];
    valueTransformer.validationBlock = validationBlock;
    valueTransformer.transformationBlock = transformationBlock;
    return valueTransformer;
}

#pragma mark RKValueTransforming

- (BOOL)transformValue:(id)inputValue toValue:(__autoreleasing id *)outputValue ofClass:(Class)outputValueClass error:(NSError *__autoreleasing *)error
{
    NSError *blockError = nil;
    BOOL success = self.transformationBlock(inputValue, outputValue, outputValueClass, &blockError);
    if (error) *error = blockError;
    return success;
}

- (BOOL)validateTransformationFromClass:(Class)sourceClass toClass:(Class)destinationClass
{
    if (self.validationBlock) return self.validationBlock(sourceClass, destinationClass);
    else return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, name: %@>", NSStringFromClass([self class]), self, self.name];
}

@end

@interface RKCompoundValueTransformer ()
@property (nonatomic, strong) NSMutableArray *valueTransformers;
@end

@implementation RKCompoundValueTransformer

+ (instancetype)compoundValueTransformerWithValueTransformers:(NSArray *)valueTransformers
{
    if (! valueTransformers) [NSException raise:NSInvalidArgumentException format:@"`valueTransformers` argument cannot be `nil`."];
    for (id<RKValueTransforming> valueTransformer in valueTransformers) {
        if (! [valueTransformer conformsToProtocol:@protocol(RKValueTransforming)]) {
            [NSException raise:NSInvalidArgumentException format:@"All objects in the given `valueTransformers` collection must conform to the `RKValueTransforming` protocol."];
        }
    }
    RKCompoundValueTransformer *valueTransformer = [self new];
    valueTransformer.valueTransformers = [valueTransformers mutableCopy];
    return valueTransformer;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.valueTransformers = [NSMutableArray new];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, valueTransformers=%@>", NSStringFromClass([self class]), self, self.valueTransformers];
}

- (void)addValueTransformer:(id<RKValueTransforming>)valueTransformer
{
    if (! valueTransformer) [NSException raise:NSInvalidArgumentException format:@"Cannot add `nil` to a compound transformer."];
    [self.valueTransformers addObject:valueTransformer];
}

- (void)removeValueTransformer:(id<RKValueTransforming>)valueTransformer
{
    if (! valueTransformer) [NSException raise:NSInvalidArgumentException format:@"Cannot remove `nil` from a compound transformer."];
    [self.valueTransformers removeObject:valueTransformer];
}

- (void)insertValueTransformer:(id<RKValueTransforming>)valueTransformer atIndex:(NSUInteger)index
{
    if (! valueTransformer) [NSException raise:NSInvalidArgumentException format:@"Cannot insert `nil` into a compound transformer."];
    [self removeValueTransformer:valueTransformer];
    [self.valueTransformers insertObject:valueTransformer atIndex:index];
}

- (NSUInteger)numberOfValueTransformers
{
    return [self.valueTransformers count];
}

- (NSArray *)valueTransformersForTransformingFromClass:(Class)sourceClass toClass:(Class)destinationClass
{
    if (sourceClass == Nil && destinationClass == Nil) return [self.valueTransformers copy];
    else if (sourceClass == Nil || destinationClass == Nil) [NSException raise:NSInvalidArgumentException format:@"If you specify a source or destination class then you must specify both."];
    NSMutableArray *matchingTransformers = [NSMutableArray arrayWithCapacity:[self.valueTransformers count]];
    for (RKValueTransformer *valueTransformer in self) {
        if (! [valueTransformer respondsToSelector:@selector(validateTransformationFromClass:toClass:)]
            || [valueTransformer validateTransformationFromClass:sourceClass toClass:destinationClass]) {
            [matchingTransformers addObject:valueTransformer];
        }
    }
    return [matchingTransformers copy];
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return [self.valueTransformers objectAtIndex:index];
}

#pragma mark RKValueTransforming

- (BOOL)transformValue:(id)inputValue toValue:(__autoreleasing id *)outputValue ofClass:(__unsafe_unretained Class)outputValueClass error:(NSError *__autoreleasing *)error
{
    NSArray *matchingTransformers = [self valueTransformersForTransformingFromClass:[inputValue class] toClass:outputValueClass];
    NSMutableArray *errors = [NSMutableArray array];
    NSError *underlyingError = nil;
    for (id<RKValueTransforming> valueTransformer in matchingTransformers) {
        BOOL success = [valueTransformer transformValue:inputValue toValue:outputValue ofClass:outputValueClass error:&underlyingError];
        if (success) return YES;
        else [errors addObject:underlyingError];
    }
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed transformation of value '%@' to %@: none of the %lu value transformers consulted were successful.", inputValue, outputValueClass, (unsigned long)[matchingTransformers count]], RKValueTransformersDetailedErrorsKey: errors };
    if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorTransformationFailed userInfo:userInfo];
    return NO;
}

- (BOOL)validateTransformationFromClass:(Class)sourceClass toClass:(Class)destinationClass
{
    return [[self valueTransformersForTransformingFromClass:sourceClass toClass:destinationClass] count] > 0;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    RKCompoundValueTransformer *compoundValueTransformer = [[[self class] allocWithZone:zone] init];
    compoundValueTransformer.valueTransformers = [self.valueTransformers mutableCopy];
    return compoundValueTransformer;
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [self.valueTransformers countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@implementation NSNumberFormatter (RKValueTransformers)

- (BOOL)validateTransformationFromClass:(Class)inputValueClass toClass:(Class)outputValueClass
{
    return (([inputValueClass isSubclassOfClass:[NSNumber class]] && [outputValueClass isSubclassOfClass:[NSString class]]) ||
            ([inputValueClass isSubclassOfClass:[NSString class]] && [outputValueClass isSubclassOfClass:[NSNumber class]]));
}

- (BOOL)transformValue:(id)inputValue toValue:(id *)outputValue ofClass:(Class)outputValueClass error:(NSError **)error
{
    RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSNumber class] ]), error);
    RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSString class], [NSNumber class] ]), error);
    if ([inputValue isKindOfClass:[NSString class]]) {
        NSString *errorDescription = nil;
        BOOL success = [self getObjectValue:outputValue forString:inputValue errorDescription:&errorDescription];
        RKValueTransformerTestTransformation(success, error, @"%@", errorDescription);
    } else if ([inputValue isKindOfClass:[NSNumber class]]) {
        *outputValue = [self stringFromNumber:inputValue];
    }
    return YES;
}

@end

@implementation NSDateFormatter (RKValueTransformers)

- (BOOL)validateTransformationFromClass:(Class)inputValueClass toClass:(Class)outputValueClass
{
    return (([inputValueClass isSubclassOfClass:[NSDate class]] && [outputValueClass isSubclassOfClass:[NSString class]]) ||
            ([inputValueClass isSubclassOfClass:[NSString class]] && [outputValueClass isSubclassOfClass:[NSDate class]]));
}

- (BOOL)transformValue:(id)inputValue toValue:(id *)outputValue ofClass:(Class)outputValueClass error:(NSError **)error
{
    RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSDate class] ]), error);
    RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, (@[ [NSString class], [NSDate class] ]), error);
    if ([inputValue isKindOfClass:[NSString class]]) {
        NSString *errorDescription = nil;
        BOOL success = [self getObjectValue:outputValue forString:inputValue errorDescription:&errorDescription];
        RKValueTransformerTestTransformation(success, error, @"%@", errorDescription);
    } else if ([inputValue isKindOfClass:[NSDate class]]) {
        *outputValue = [self stringFromDate:inputValue];
    }
    return YES;
}

@end
