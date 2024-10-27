//
//  RKValueTransformers.h
//  RestKit
//
//  Created by Blake Watters on 8/18/13.
//  Copyright (c) 2013 RestKit. All rights reserved.
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

#import <Foundation/Foundation.h>

/**
 Objects wish to perform transformation on values as part of a RestKit object mapping operation much adopt the `RKValueTransforming` protocol. Value transformers must introspect a given input value to determine if they are capable of performing a transformation and if so, perform the transformation and assign the new value to the given pointer to an output value and return `YES` or else construct an error describing the failure and return `NO`. Value transformers may also optionally implement a validation method that enables callers to determine if a given value transformer object is capable of performing a transformation on an input value.
 */
@protocol RKValueTransforming <NSObject>

@required

/**
 Transforms a given value into a new representation.
 
 Attempts to perform a transformation of a given value into a new representation and returns a Boolean value indicating if the transformation was successful. Transformers are responsible for introspecting their input values before attempting to perform the transformation. If the transformation cannot be performed, then the transformer must construct an `NSError` object describing the nature of the failure else a warning will be emitted.
 
 @param inputValue The value to be transformed.
 @param outputValue A pointer to an `id` object that will be assigned to the transformed representation. May be assigned to `nil` if that is the result of the transformation.
 @param outputValueClass The class of the `outputValue` variable. Specifies the expected type of a successful transformation. May be `nil` to indicate that the type is unknown or unimportant.
 @param error A pointer to an `NSError` object that must be assigned to a newly constructed `NSError` object if the transformation cannot be performed.
 @return A Boolean value indicating if the transformation was successful. This is used to determine whether another transformer should be given an opportunity to attempt a transformation.
 */
- (BOOL)transformValue:(id)inputValue toValue:(id *)outputValue ofClass:(Class)outputValueClass error:(NSError **)error;

@optional

/**
 Asks the transformer if it is capable of performing a transformation from a given class into a new representation of another given class. 
 
 This is an optional method that need only be implemented by transformers that are tightly bound to values with specific types.
 
 @param inputValueClass The `Class` of an input value being inspected.
 @param outputValueClass The `Class` of an output value being inspected.
 @return `YES` if the receiver can perform a transformation between the given source and destination classes.
 */
- (BOOL)validateTransformationFromClass:(Class)inputValueClass toClass:(Class)outputValueClass;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 The domain for errors emitted by RKValueTransformers
 */
extern NSString *const RKValueTransformersErrorDomain;

/**
 If multiple errors occur in one operation, they are collected in an array and added with this key to the "top-level error" of the operation
 */
extern NSString *const RKValueTransformersDetailedErrorsKey;

typedef NS_ENUM(NSUInteger, RKValueTransformationError) {
    RKValueTransformationErrorUntransformableInputValue     = 3000,     // The input value was determined to be unacceptable and no transformation was performed.
    RKValueTransformationErrorUnsupportedOutputClass        = 3001,     // The specified class type for the output value is unsupported and no transformation was performed.
    RKValueTransformationErrorTransformationFailed          = 3002      // A transformation was attempted, but failed.
};

/**
 Tests if a given input value is of an expected class and returns a failure if it is not.
 
 This macro is useful for quickly verifying that a transformer can work with a given input value by checking if the value is an instance of an expected class. On failure, the macro constructs an error describing the class mismatch.
 
 @param inputValue The input value to test.
 @param expectedClass The expected class or array of classes of the input value.
 @param error A pointer to an `NSError` object in which to assign a newly constructed error if the test fails. Cannot be `nil`.
 */
#define RKValueTransformerTestInputValueIsKindOfClass(inputValue, expectedClass, error) ({ \
    NSArray *supportedClasses = [expectedClass isKindOfClass:[NSArray class]] ? (NSArray *)expectedClass : @[ expectedClass ];\
    BOOL success = NO; \
    for (Class supportedClass in supportedClasses) {\
        if ([inputValue isKindOfClass:supportedClass]) { \
            success = YES; \
            break; \
        }; \
    } \
    if (! success) { \
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `inputValue` of type `%@`, but got a `%@`.", expectedClass, [inputValue class]] };\
        if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo]; \
        return NO; \
    } \
})

/**
 Tests if a given output value class is of an expected class and returns a failure if it is not.
 
 This macro is useful for quickly verifying that a transformer can work with a given input value by checking if the value is an instance of an expected class. On failure, the macro constructs an error describing the class mismatch.
 
 @param outputValueClass The input value to test.
 @param expectedClass The expected class or array of classes of the input value.
 @param error A pointer to an `NSError` object in which to assign a newly constructed error if the test fails. Cannot be `nil`.
 */
#define RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, expectedClass, error) ({ \
    NSArray *supportedClasses = [expectedClass isKindOfClass:[NSArray class]] ? (NSArray *)expectedClass : @[ expectedClass ];\
    BOOL success = NO; \
    for (Class supportedClass in supportedClasses) {\
        if ([outputValueClass isSubclassOfClass:supportedClass]) { \
            success = YES; \
            break; \
        }; \
    } \
    if (! success) { \
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `outputValueClass` of type `%@`, but got a `%@`.", expectedClass, outputValueClass] };\
        if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorUnsupportedOutputClass userInfo:userInfo]; \
        return NO; \
    } \
})

/**
 Tests a condition to evaluate the success of an attempted value transformation and returns a failure if it is not true.
 
 This macro is useful for quickly verifying that an attempted transformation was successful. If the condition is not true, than an error is constructed describing the failure.
 
 @param condition The condition to test.
 @param expectedClass The expected class of the input value.
 @param error A pointer to an `NSError` object in which to assign a newly constructed error if the test fails. Cannot be `nil`.
 @param ... A string describing what the failure was that occurred. This may be a format string with additional arguments.
 */
#define RKValueTransformerTestTransformation(condition, error, ...) ({ \
if (! (condition)) { \
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:__VA_ARGS__] };\
    if (error) *error = [NSError errorWithDomain:RKValueTransformersErrorDomain code:RKValueTransformationErrorTransformationFailed userInfo:userInfo]; \
        return NO; \
    } \
})

////////////////////////////////////////////////////////////////////////////////////////////////////

@class RKCompoundValueTransformer;

/**
 The `RKValueTransformer` class is an abstract base class for implementing a value transformer that conforms to the `RKValueTransforming` protocol. The class is provided to enable third-party extensions of the value transformer to be implemented through subclassing. The default implementation contains no behavior and will raise an exception if an implementation of `transformValue:toValue:ofClass:error:` is not provided by the subclass. `RKValueTransformer` also exposes accessors for the default value transformer implementations that are provided with the library.
 */
@interface RKValueTransformer : NSObject <RKValueTransforming>

///--------------------------------------
/// @name Retrieving Default Transformers
///--------------------------------------

/**
 Returns a transformer that will return the input value if it is already of the desired output class.
 */
+ (instancetype)identityValueTransformer;

/**
 Returns a transformer capable of transforming between `NSString` and `NSURL` representations.
 */
+ (instancetype)stringToURLValueTransformer;

/**
 Returns a transformer capable of transforming between `NSNumber` and `NSString` representations.
 */
+ (instancetype)numberToStringValueTransformer;

/**
 Returns a transformer capable of transforming between `NSArray` and `NSOrderedSet` representations.
 */
+ (instancetype)arrayToOrderedSetValueTransformer;

/**
 Returns a transformer capable of transforming between `NSArray` and `NSSet` representations.
 */
+ (instancetype)arrayToSetValueTransformer;

/**
 Returns a transformer capable of transforming between `NSDecimalNumber` and `NSNumber` representations.
 */
+ (instancetype)decimalNumberToNumberValueTransformer;

/**
 Returns a transformer capable of transforming between `NSDecimalNumber` and `NSString` representations.
 */
+ (instancetype)decimalNumberToStringValueTransformer;

/**
 Returns a transformer capable of transforming from `[NSNull null]` to `nil` representations.
 */
+ (instancetype)nullValueTransformer;

/**
 Returns a transformer capable of transforming between objects that conform to the `NSCoding` protocol and `NSData` representations by using an `NSKeyedArchiver`/`NSKeyedUnarchiver` to serialize as a property list.
 */
+ (instancetype)keyedArchivingValueTransformer;

/**
 Returns a transformer capable of transforming between `NSNumber` or `NSString` and `NSDate` representations by evaluating the input value as a time interval since the UNIX epoch (1 January 1970, GMT).

 The transformation treats numeric values as a `double` in order to provide sub-second accuracy.
 */
+ (instancetype)timeIntervalSince1970ToDateValueTransformer;

/**
 Returns a transformer capable of transforming between `NSDate` and `NSString` representations in which the string encodes date and time information in the ISO 8601 timestamp format.
 
 Note that this transformer is only capable of handling a fully qualified timestamp string rather than the complete ISO 8601 format. For a more complete implementation of the ISO 8601 standard, see the []() project.
 */
+ (instancetype)iso8601TimestampToDateValueTransformer;

/**
 Returns a transformer capable of transforming any `NSObject` that implements the `stringValue` method into an `NSString` representation.
 */
+ (instancetype)stringValueTransformer;

/**
 Returns a transformer capable of enclosing any singular `NSObject` into a collection type such as `NSArray`, `NSSet`, or `NSOrderedSet` (and its mutable descendents).
 */
+ (instancetype)objectToCollectionValueTransformer;

/**
 Returns a transformer capable of transforming any object that conforms to the `NSCopying` protocol into a dictionary representation keyed by the transformed object.
 */
+ (instancetype)keyOfDictionaryValueTransformer;

/**
 Returns a transformer capable of transforming any object conforming to the `NSMutableCopying` protocol into a mutable representation of itself.
 */
+ (instancetype)mutableValueTransformer;

/**
 Returns the singleton instance of the default value transformer. The default transformer is a compound transformer that includes all the individual value transformers implemented on the `RKValueTransformer` base class as well as `NSDateFormatter` instances for the following date format strings:
 
    * MM/dd/yyyy
    * yyyy-MM-dd
 
 All date formatters are configured to the use `en_US_POSIX` locale and the UTC time zone.
 */
+ (RKCompoundValueTransformer *)defaultValueTransformer;

/**
 Sets the default value transformer to a new instance. Setting the default transformer to `nil` will result in a new singleton instance with the default configuration being rebuilt.

 @param compoundValueTransformer The new default compound transformer. Passing `nil` will reset the transformer to the default configuration.
 */
+ (void)setDefaultValueTransformer:(RKCompoundValueTransformer *)compoundValueTransformer;

@end

/**
 The `RKBlockValueTransformer` class provides a concrete implementation of the `RKValueTransforming` protocol using blocks to provide the implementation of the transformer.
 */
@interface RKBlockValueTransformer : RKValueTransformer

///-----------------------------------
/// @name Creating a Block Transformer
///-----------------------------------

/**
 Creates and returns a new value transformer with the given validation and transformation blocks. The blocks are used to provide the implementation of the corresponding methods from the `RKValueTransforming` protocol.
 
 @param validationBlock A block that evaluates whether the transformer can perform a transformation between a given pair of input and output classes.
 */
+ (instancetype)valueTransformerWithValidationBlock:(BOOL (^)(Class inputValueClass, Class outputValueClass))validationBlock
                                transformationBlock:(BOOL (^)(id inputValue, id *outputValue, Class outputClass, NSError **error))transformationBlock;

/**
 An optional name for the transformer.
 */
@property (nonatomic, copy) NSString *name;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 The `RKCompoundValueTransformer` class provides an implementation of the `RKValueTransforming` protocol in which a collection of underlying value transformers are assembled into a composite value transformer. Compound values transformers are ordered collections in which each underlying transformer is given the opportunity to transform a value in the order in which it appears within the receiver. Compound transformers are copyable, enumerable and support subscripted access to the underlying value transformers.
 */
@interface RKCompoundValueTransformer : NSObject <RKValueTransforming, NSCopying, NSFastEnumeration>

///--------------------------------------
/// @name Creating a Compound Transformer
///--------------------------------------

/**
 Creates and returns a new compound transformer from an array of individual value transformers.
 
 @param valueTransformers An array containining an arbitrary number of objects that conform to the `RKValueTransforming` protocol. Cannot be `nil`.
 @return A new compound transformer initialized with the given collection of underlying transformers.
 @raises NSInvalidArgumentException Raised if `valueTransformers` is `nil` or any objects in the given collection do not conform to the `RKValueTransforming` protocol.
 */
+ (instancetype)compoundValueTransformerWithValueTransformers:(NSArray *)valueTransformers;

///----------------------------------------------------
/// @name Manipulating the Value Transformer Collection
///----------------------------------------------------

/**
 Adds the given value transformer to the end of the receiver's transformer collection.
 
 Adding a transformer appends it to the end of the collection meaning that it will be consulted after all other transformers.
 
 @param valueTransformer The transformer to add to the receiver.
 */
- (void)addValueTransformer:(id<RKValueTransforming>)valueTransformer;

/**
 Removes the given value transformer from the receiver.

 @param valueTransformer The transformer to remove from the receiver.
 */
- (void)removeValueTransformer:(id<RKValueTransforming>)valueTransformer;

/**
 Inserts the given value transformer into the receiver at a specific position. If the transformer already exists within the receiver then it is moved to the specified position.
 
 @param valueTransformer The value transformer to be added to (or moved within) the receiver.
 @param index The position at which the transformer should be consulted within the collection. An index of 0 would mean that the transformer is consulted before all other transformers.
 */
- (void)insertValueTransformer:(id<RKValueTransforming>)valueTransformer atIndex:(NSUInteger)index;

/**
 Returns a count of the number of value transformers in the receiver.
 
 @return An integer specifying the number of transformers within the receiver.
 */
- (NSUInteger)numberOfValueTransformers;

///------------------------------------------
/// @name Retrieving Constituent Transformers
///------------------------------------------

/**
 Returns a new array containing a subset of the value transformers contained within the receiver that are valid for a transformation between a representation with a given input class and a given output class. 
 
 Whether or not a given transformer is returned is determined by the invocation of the optional `RKValueTransforming` method `validateTransformationFromClass:toClass:`. Any transformer that does not respond to `validateTransformationFromClass:toClass:` will be included within the returned array. The sequencing of the transformers within the returned array is determined by their position within the receiver.
 
 If you wish to obtain an array containing all of the transformers contained within the receiver then pass `Nil` for both the `inputValueClass` and `outputValueClass` arguments.

 @param inputValueClass The class of input values that you wish to retrieve the transformers for. Can only be `Nil` if `outputValueClass` is also `Nil`.
 @param outputValueClass The class of output values that you wish to retrieve the transformers for. Can only be `Nil` if `inputValueClass` is also `Nil`.
 @raises NSInvalidArgumentException Raised if `Nil` is given exclusively for `inputValueClass` or `outputValueClass`.
 */
- (NSArray *)valueTransformersForTransformingFromClass:(Class)inputValueClass toClass:(Class)outputValueClass;

@end

// Adopts `RKValueTransforming` to provide transformation from `NSString` <-> `NSNumber`
@interface NSNumberFormatter (RKValueTransformers) <RKValueTransforming>
@end

// Adopts `RKValueTransforming` to provide transformation from `NSString` <-> `NSDate`
@interface NSDateFormatter (RKValueTransformers) <RKValueTransforming>
@end
