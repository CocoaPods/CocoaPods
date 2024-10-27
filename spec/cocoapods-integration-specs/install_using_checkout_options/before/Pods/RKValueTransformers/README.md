RKValueTransformers
===================

[![Build Status](http://img.shields.io/travis/RestKit/RKValueTransformers/master.svg?style=flat)](https://travis-ci.org/RestKit/RKValueTransformers) 
![Pod Version](http://cocoapod-badges.herokuapp.com/v/RKValueTransformers/badge.png) 
![Pod Platform](http://cocoapod-badges.herokuapp.com/p/RKValueTransformers/badge.png)

**A simple, powerful Objective-C value transformation API extracted from RestKit**

RKValueTransformers is a standalone library that provides a simple value transformation API in Objective-C. Value transformation is the process of converting a value between representations and is a core part of any system that requires that data be transmitted and received in a serialization format distinct from the local data model. 

In the general context of a RESTful API this means the transformation between values encoded in an XML or JSON document and local attributes of your data model. The most familiar and obvious example is the transformation of date and time data encoded as a string in a JSON document and represented locally as an `NSDate` attribute of an `NSObject` or `NSManagedObject` derived class. RKValueTransformers provides a simple, well-designed API for generalizing and simplifying the task of handling an arbitrarily complex set of value transformation requirements for your iOS or Mac OS X application.

Value transformation is a core feature of [RestKit](http://github.com/RestKit/RestKit) and RKValueTransformers was extracted from the parent project to benefit the larger Cocoa development community. If you are looking for a comprehensive solution for your RESTful API needs then be sure to give RestKit a closer look.

### Features

RKValueTransformers is a "batteries included" library that ships with value transformers handling the most common transformations. The core set of transformers can be customized and new transformers are easily implemented to meet the needs of any application.

* Includes a rich set of transformers covering the most common transformations:
  * `NSString` <-> `NSURL`
  * `NSNumber` <-> `NSString`
  * `NSArray` <-> `NSOrderedSet`
  * `NSArray` <-> `NSSet`
  * `NSDecimalNumber` <-> `NSNumber`
  * `NSDecimalNumber` <-> `NSString`
  * `NSNull` <-> `nil`
  * Any class conforming to `NSCoding` <-> `NSData`
  * UNIX Time Interval encoded as `NSNumber` or `NSString` <-> `NSDate`
  * ISO 8601 Timestamp strings <-> `NSDate` (Only supports complete timestamp strings. On 32 bit systems such as iOS devices pre-iPhone 5s only years < 2038 are supported)
  * Any object implementing `stringValue` -> `NSString`
  * Any singular object to a collection (`NSArray`, `NSSet`, `NSOrderedSet` and their mutable counterparts)
  * Any object and an `NSDictionary` (object becomes a key for empty nested dictionary)
  * Any class conforming to `NSMutableCoding` -> mutable representation of itself
  * `NSString` <-> `NSDate` via `NSDateFormatter`. Default formats include:
  	* RFC 1123 format
    * RFC 850 format
    * ANSI C's asctime() format
  * `NSString` <-> `NSNumber` via `NSNumberFormatter`
* Lightweight. Implemented in a single pair or header and implementation files.
* Fully unit tested and documented.
* Extensible by implementing the `RKValueTransforming` protocol, subclassing `RKValueTransformer` or with blocks via `RKBlockValueTransformer`.
* Multiple value transformers can be assembled into a composite transformer via the `RKCompoundValueTransformer` class.
* Transparently improves date transformation performance by providing a cache of date formatters.
* Fully integrated with RestKit.

## Examples

All value transformation is performed via an abstract common interface defined by the `RKValueTransforming` protocol:

```objc
NSString *stringContainingDecimalNumber = @"3.4593895835";
NSError *error = nil;
NSDecimalNumber *decimalNumber = nil;
BOOL success = [[RKValueTransformers decimalNumberToStringValueTransformer] transformValue:stringContainingDecimalNumber toValue:&decimalNumber ofClass:[NSDecimalNumber class] error:&error];
```

The `transformValue:toValue:ofClass:error:` method is always the same regardless of the implementation details of the underlying transformation. It is guaranteed to always return a Boolean value indicating if the transformation was successful and value transformers **must** return an `NSError` in the event the transformation could not be performed.

### Validating a Transformation

In many cases, whether or not a given transformation can be performed can be determined entirely by the types involved in the transformation. In these cases, a value transformer may implement the optional `RKValueTransforming` method `validateTransformationFromClass:(Class)inputValueClass toClass:(Class)outputValueClass`:

```objc
BOOL isTransformationPossible = [[RKValueTransformers arrayToSetValueTransformer] validateTransformationFromClass:[NSSet class] toClass:[NSArray class]];
NSAssert(isTransformationPossible == YES, @"Should be `YES`");
isTransformationPossible = [[RKValueTransformers arrayToSetValueTransformer] validateTransformationFromClass:[NSSet class] toClass:[NSData class]];
NSAssert(isTransformationPossible == NO, @"Should be `NO`");
```

Note that as this is an optional method you must check that a given instance responds to the validation selector. If it does not then the transformation cannot be validated and a transformation must be attempted to determine success or failure.

### Compound Transformers

Individual transformers are very convenient -- they abstract away the need to remember how to implement a given transformation and present a simple interface for transformations. But the real power of RKValueTransformers emerges when you assemble a collection of value transformers into a compound transformer via the `RKCompoundValueTransformer` class. Compound value transformers also implement the `RKValueTransforming` protocol -- but instead of providing any value transformation and validation themselves they proxy the calls to a collection of underlying value transformers in programmer defined order. This allows you to configure a set of transformers in a specific order such that the first transformer that is capable of performing a given transformation will handle it.

Consider for example that a given application may interact with several API's that return dates as strings in several different formats. We wish to be able to transform any given string value into an `NSDate` without worrying about the details. We could configure a compound transformer to handle this task like so:

```objc
NSArray *dateFormats = @[ @"MM/dd/yyyy", @"yyyy-MM-dd'T'HH:mm:ss'Z'", @"yyyy-MM-dd" ];
RKCompoundValueTransformer *compoundValueTransformer = [RKCompoundValueTransformer new];
for (NSString *dateFormat in dateFormats) {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = dateFormat;
    [compoundValueTransformer addValueTransformer:dateFormatter];
}

[compoundValueTransformer addValueTransformer:[RKValueTransformer timeIntervalSince1970ToDateValueTransformer]];

NSArray *dateStrings = @[ @"11/27/1982", @"1378767519.18176508", @"2013-11-27", @"2013-04-23T16:29:05Z" ];
NSError *error = nil;
for (NSString *dateString in dateStrings) {
    NSDate *date = nil;
    BOOL success = [compoundValueTransformer transformValue:dateString toValue:&date ofClass:[NSDate class]];
    NSLog(@"Transformed value '%@' to value '%@' successfully=%@, error=%@", dateString, date, success ? @"YES" : @"NO", error);
}
```

### Block Value Transformers

RKValueTransformers supports the creation of ad-hoc value transformer instances implemented via blocks. For example, one could implement a value transformer that turns all `NSString` instances into uppercase strings like so:

```objc
RKValueTransformer *uppercaseStringTransformer = [RKBlockValueTransformer valueTransformerWithValidationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
    // We transform a `NSString` into another `NSString`
    return ([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSString class]]);
} transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, Class outputValueClass, NSError *__autoreleasing *error) {
	// Validate the input and output
    RKValueTransformerTestInputValueIsKindOfClass(inputValue, [NSString class], error);
    RKValueTransformerTestOutputValueClassIsSubclassOfClass(outputValueClass, [NSString class], error);
    
    // Perform the transformation
    *outputValue = [(NSString *)inputValue uppercaseString];
    return YES;
}];
```

## Installation

RKValueTransformers is extremely lightweight and has no direct dependencies outside of the Cocoa Foundation framework. As such, the library can be trivially be installed into any Cocoa project by directly adding the source code. Despite this fact, we recommend installing via CocoaPods as it provides modularity and enables the easy installation of new value transformers that are dependent on RKValueTransformers itself.

### Via CocoaPods

The recommended approach for installing RKValueTransformers is via the [CocoaPods](http://cocoapods.org/) package manager, as it provides flexible dependency management and dead simple installation. For best results, it is recommended that you install via CocoaPods **>= 0.24.0** using Git **>= 1.8.0** installed via Homebrew.

Install CocoaPods if not already available:

``` bash
$ [sudo] gem install cocoapods
$ pod setup
```

Change to the directory of your Xcode project, and Create and Edit your Podfile and add RKValueTransformers:

``` bash
$ cd /path/to/MyProject
$ touch Podfile
$ edit Podfile
platform :ios, '5.0' 
# Or platform :osx, '10.7'
pod 'RKValueTransformers', '~> 1.0.0'
```

Install into your project:

``` bash
$ pod install
```

Open your project in Xcode from the .xcworkspace file (not the usual project file)

``` bash
$ open MyProject.xcworkspace
```

### Via Source Code

Simply add `RKValueTransformers.h` and `RKValueTransformers.m` to your project and `#import "RKValueTransformers.h"`.

## Design & Implementation Details

RKValueTransformers is designed to be simple to integrate and use. The entire library consists of a single protocol, three classes, and a handful of category implementations:

* `RKValueTransforming` - Defines the value transformation API. Adopted by any class that wishes to act as a value transformer.
* `RKValueTransformer` - An abstract base class that implements `RKValueTransforming`. The base class includes static accessors for retrieving singleton instances of the bundled value transformers. Extension libraries can subclass `RKValueTransformer` to provide new transformers.
* `RKBlockValueTransformer` - A concrete subclass of `RKValueTransformer` that enables the creation of ad-hoc value transformers defined via blocks.
* `RKCompoundValueTransformer` - A concrete implementation of `RKValueTransforming` that proxies calls to an underlying collection of value transformers and provides support for composing value transformers.

For those implementing value transformers, a few macros are included to simplify the implementation of validation and transformation methods:

* `RKValueTransformerTestInputValueIsKindOfClass` - Tests that a given input value is an instance of a given class or one of its subclasses. If the test evaluates negatively, then `NO` is returned and an appropriate `NSError` is emitted.
* `RKValueTransformerTestOutputValueClassIsSubclassOfClass` - Tests that a given output value class is equal to a given class or is a subclass there of. If the test evaluates negatively, then `NO` is returned an appropriate `NSError` is emitted.
* `RKValueTransformerTestTransformation` - Tests that a given transformation was successful. If the test evaluates negatively, then `NO` is returned an appropriate `NSError` is emitted.

### Why not NSValueTransformer?

In developing RKValueTransformers we looked closely at `NSValueTransformer` and ultimately determined that it was not a great fit for our needs. Specifically we found the following issues:

1. `NSValueTransformer` defines a notion of 'forward' and 'reverse' transformation that doesn't map cleanly in a system primarilly concerned with type transformations. Which side do you consider forward? This gets worse when you consider transformations that can occur between more than just two types.
2. `NSValueTransformer` exposes the class of the "output" object via the class method `transformedValueClass`. This becomes annoying as you are forced to use inheritance to express type knowledge. This necessitates directly inheriting from `NSValueTransformer` or using fancy run-time hackery such as that [utilized by TransformerKit](https://github.com/mattt/TransformerKit/blob/master/TransformerKit/NSValueTransformer%2BTransformerKit.m).
3. `NSValueTransformer` exposes a single global name based registry for value transformers via the `setValueTransformer:forName:` and `valueTransformerForName:` methods. Ultimately this is not granular enough to provide necessary flexibility and requires the use of names (as opposed to type information) to look up transformers.

Given all of the above it just made sense to go back to a clean slate and design a solution to the value transformation problem from scratch.

## Unit Tests

RKValueTransformers is tested using the [Expecta](https://github.com/specta/Expecta) library of unit testing matchers. In order to run the tests, you must do the following:

1. Install the dependencies via CocoaPods: `pod install`
1. Open the workspace: `open RKValueTransformers.xcworkspace`
1. Run the specs via the **Product** menu > **Test**

## Credits

Blake Watters

- http://github.com/blakewatters
- http://twitter.com/blakewatters
- blakewatters@gmail.com

Samuel E. Giddins

- https://github.com/segiddins
- http://twitter.com/segiddins
- segiddins@segiddins.me

## License

RKValueTransformers is available under the Apache 2 License. See the LICENSE file for more info.
