# JSONKit

JSONKit is licensed under the terms of the BSD License.  Copyright &copy; 2011, John Engelhart.

### A Very High Performance Objective-C JSON Library

<table>
<tr><th>Parsing</th><th>Serializing</th></tr>
<tr><td><img src="http://chart.googleapis.com/chart?chf=a,s,000000|b0,lg,0,6589C760,0,6589C7B4,1|bg,lg,90,EFEFEF,0,F8F8F8,1&chxl=0:|TouchJSON|XML+.plist|json-framework|YAJL-ObjC|gzip+JSONKit|Binary+.plist|JSONKit|2:|Time+to+Deserialize+in+%C2%B5sec&chxp=2,40&chxr=0,0,5|1,0,3250&chxs=0,676767,11.5,1,lt,676767&chxt=y,x,x&chbh=a,5,4&chs=350x185&cht=bhs&chco=6589C783&chds=0,3250&chd=t:410.517,510.262,539.614,1351.257,1683.346,1747.953,2955.881&chg=-1,0,1,3&chm=N+*s*+%C2%B5s,676767,0,0:5,10.5|N+*s*+%C2%B5s,3d3d3d,0,6,10.5,,r:-5:1&chem=y;s=text_outline;d=666,10.5,l,fff,_,Decompress+%2b+Parse+is+just;ds=0;dp=2;py=0;of=58,7|y;s=text_outline;d=666,10.5,l,fff,_,5.6%25+slower+than+Binary+.plist%21;ds=0;dp=2;py=0;of=53,-5" width="350" height="185" alt="Deserialize from JSON" /></td>
<td><img src="http://chart.googleapis.com/chart?chf=a,s,000000|b0,lg,0,699E7260,0,699E72B4,1|bg,lg,90,EFEFEF,0,F8F8F8,1&chxl=0:|TouchJSON|YAJL-ObjC|XML+.plist|json-framework|Binary+.plist|gzip+JSONKit|JSONKit|2:|Time+to+Serialize+in+%C2%B5sec&chxp=2,40&chxr=0,0,5|1,0,3250&chxs=0,676767,11.5,1,lt,676767&chxt=y,x,x&chbh=a,5,4&chs=350x175&cht=bhs&chco=699E7284&chds=0,3250&chd=t:96.387,466.947,626.153,1028.432,1945.511,2156.978,3051.976&chg=-1,0,1,3&chm=N+*s*+%C2%B5s,676767,0,0:5,10.5|N+*s*+%C2%B5s,4d4d4d,0,6,10.5,,r:-5:1&chem=y;s=text_outline;d=666,10.5,l,fff,_,Serialize+%2b+Compress+is+34%25;ds=0;dp=1;py=0;of=51,7|y;s=text_outline;d=666,10.5,l,fff,_,faster+than+Binary+.plist%21;ds=0;dp=1;py=0;of=62,-5" width="350" height="185" alt="Serialize to JSON" /></td></tr>
<tr><td align=center><em>23% Faster than Binary</em> <code><em>.plist</em></code><em>&thinsp;!</em></td><td align=center><em>549% Faster than Binary</em> <code><em>.plist</em></code><em>&thinsp;!</em></td></tr>
</table>

* Benchmarking was performed on a MacBook Pro with a 2.66GHz Core 2.
* All JSON libraries were compiled with `gcc-4.2 -DNS_BLOCK_ASSERTIONS -O3 -arch x86_64`.
* Timing results are the average of 1,000 iterations of the user + system time reported by [`getrusage`][getrusage].
* The JSON used was [`twitter_public_timeline.json`](https://github.com/samsoffes/json-benchmarks/blob/master/Resources/twitter_public_timeline.json) from [samsoffes / json-benchmarks](https://github.com/samsoffes/json-benchmarks).
* Since the `.plist` format does not support serializing [`NSNull`][NSNull], the `null` values in the original JSON were changed to `"null"`.
* The [experimental](https://github.com/johnezang/JSONKit/tree/experimental) branch contains the `gzip` compression changes.
    * JSONKit automagically links to `libz.dylib` on the fly at run time&ndash; no manual linking required.
    * Parsing / deserializing will automagically decompress a buffer if it detects a `gzip` signature header.
    * You can compress / `gzip` the serialized JSON by passing `JKSerializeOptionCompress` to `-JSONDataWithOptions:error:`.

***

JavaScript Object Notation, or [JSON][], is a lightweight, text-based, serialization format for structured data that is used by many web-based services and API's.  It is defined by [RFC 4627][].

JSON provides the following primitive types:

* `null`
* Boolean `true` and `false`
* Number
* String
* Array
* Object (a.k.a. Associative Arrays, Key / Value Hash Tables, Maps, Dictionaries, etc.)

These primitive types are mapped to the following Objective-C Foundation classes:

<table>
<tr><th>JSON</th><th>Objective-C</th></tr>
<tr><td><code>null</code></td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSNull_Class/index.html"><code>NSNull</code></a></td></tr>
<tr><td><code>true</code> and <code>false</code></td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSNumber_Class/index.html"><code>NSNumber</code></a></td></tr>
<tr><td>Number</td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSNumber_Class/index.html"><code>NSNumber</code></a></td></tr>
<tr><td>String</td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/index.html"><code>NSString</code></a></td></tr>
<tr><td>Array</td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/index.html"><code>NSArray</code></a></td></tr>
<tr><td>Object</td><td><a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/index.html"><code>NSDictionary</code></a></td></tr>
</table>

JSONKit uses Core Foundation internally, and it is assumed that Core Foundation &equiv; Foundation for every equivalent base type, i.e. [`CFString`][CFString] &equiv; [`NSString`][NSString].

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119][].

### JSON To Objective-C Primitive Mapping Details

*   The [JSON specification][RFC 4627] is somewhat ambiguous about the details and requirements when it comes to Unicode, and it does not specify how Unicode issues and errors should be handled.  Most of the ambiguity stems from the interpretation and scope [RFC 4627][] Section 3, Encoding: `JSON text SHALL be encoded in Unicode.`  It is the authors opinion and interpretation that the language of [RFC 4627][] requires that a JSON implementation MUST follow the requirements specified in the [Unicode Standard][], and in particular the [Conformance][Unicode Standard - Conformance] chapter of the [Unicode Standard][], which specifies requirements related to handling, interpreting, and manipulating Unicode text.
    
    The default behavior for JSONKit is strict [RFC 4627][] conformance.  It is the authors opinion and interpretation that [RFC 4627][] requires JSON to be encoded in Unicode, and therefore JSON that is not legal Unicode as defined by the [Unicode Standard][] is invalid JSON.  Therefore, JSONKit will not accept JSON that contains ill-formed Unicode.  The default, strict behavior implies that the `JKParseOptionLooseUnicode` option is not enabled.
    
    When the `JKParseOptionLooseUnicode` option is enabled, JSONKit follows the specifications and recommendations given in [The Unicode 6.0 standard, Chapter 3 - Conformance][Unicode Standard - Conformance], section 3.9 *Unicode Encoding Forms*.  As a general rule of thumb, the Unicode code point `U+FFFD` is substituted for any ill-formed Unicode encountered. JSONKit attempts to follow the recommended *Best Practice for Using U+FFFD*:  ***Replace each maximal subpart of an ill-formed subsequence by a single U+FFFD.***
    
    The following Unicode code points are treated as ill-formed Unicode, and if `JKParseOptionLooseUnicode` is enabled, cause `U+FFFD` to be substituted in their place:

    `U+0000`.<br>
    `U+D800` thru `U+DFFF`, inclusive.<br>
    `U+FDD0` thru `U+FDEF`, inclusive.<br>
    <code>U+<i>n</i>FFFE</code> and <code>U+<i>n</i>FFFF</code>, where *n* is from `0x0` to `0x10`

    The code points `U+FDD0` thru `U+FDEF`, <code>U+<i>n</i>FFFE</code>, and <code>U+<i>n</i>FFFF</code> (where *n* is from `0x0` to `0x10`), are defined as ***Noncharacters*** by the Unicode standard and "should never be interchanged".
    
    An exception is made for the code point `U+0000`, which is legal Unicode.  The reason for this is that this particular code point is used by C string handling code to specify the end of the string, and any such string handling code will incorrectly stop processing a string at the point where `U+0000` occurs.  Although reasonable people may have different opinions on this point, it is the authors considered opinion that the risks of permitting JSON Strings that contain `U+0000` outweigh the benefits.  One of the risks in allowing `U+0000` to appear unaltered in a string is that it has the potential to create security problems by subtly altering the semantics of the string which can then be exploited by a malicious attacker.  This is similar to the issue of [arbitrarily deleting characters from Unicode text][Unicode_UTR36_Deleting].
    
    [RFC 4627][] allows for these limitations under section 4, Parsers: `An implementation may set limits on the length and character contents of strings.`  While the [Unicode Standard][] permits the mutation of the original JSON (i.e., substituting `U+FFFD` for ill-formed Unicode), [RFC 4627][] is silent on this issue.  It is the authors opinion and interpretation that [RFC 4627][], section 3 &ndash; *Encoding*, `JSON text SHALL be encoded in Unicode.` implies that such mutations are not only permitted but MUST be expected by any strictly conforming [RFC 4627][] JSON implementation.  The author feels obligated to note that this opinion and interpretation may not be shared by others and, in fact, may be a minority opinion and interpretation.  You should be aware that any mutation of the original JSON may subtly alter its semantics and, as a result, may have security related implications for anything that consumes the final result.
    
    It is important to note that JSONKit will not delete characters from the JSON being parsed as this is a [requirement specified by the Unicode Standard][Unicode_UTR36_Deleting].  Additional information can be found in the [Unicode Security FAQ][Unicode_Security_FAQ] and [Unicode Technical Report #36 - Unicode Security Consideration][Unicode_UTR36], in particular the section on [non-visual security][Unicode_UTR36_NonVisualSecurity].

*   The [JSON specification][RFC 4627] does not specify the details or requirements for JSON String values, other than such strings must consist of Unicode code points, nor does it specify how errors should be handled.  While JSONKit makes an effort (subject to the reasonable caveats above regarding Unicode) to preserve the parsed JSON String exactly, it can not guarantee that [`NSString`][NSString] will preserve the exact Unicode semantics of the original JSON String.
    
    JSONKit does not perform any form of Unicode Normalization on the parsed JSON Strings, but can not make any guarantees that the [`NSString`][NSString] class will not perform Unicode Normalization on the parsed JSON String used to instantiate the [`NSString`][NSString] object.  The [`NSString`][NSString] class may place additional restrictions or otherwise transform the JSON String in such a way so that the JSON String is not bijective with the instantiated [`NSString`][NSString] object.  In other words, JSONKit can not guarantee that when you round trip a JSON String to a [`NSString`][NSString] and then back to a JSON String that the two JSON Strings will be exactly the same, even though in practice they are.  For clarity, "exactly" in this case means bit for bit identical.  JSONKit can not even guarantee that the two JSON Strings will be [Unicode equivalent][Unicode_equivalence], even though in practice they will be and would be the most likely cause for the two round tripped JSON Strings to no longer be bit for bit identical.
    
*   JSONKit maps `true` and `false` to the [`CFBoolean`][CFBoolean] values [`kCFBooleanTrue`][kCFBooleanTrue] and [`kCFBooleanFalse`][kCFBooleanFalse], respectively.  Conceptually, [`CFBoolean`][CFBoolean] values can be thought of, and treated as, [`NSNumber`][NSNumber] class objects.  The benefit to using [`CFBoolean`][CFBoolean] is that `true` and `false` JSON values can be round trip deserialized and serialized without conversion or promotion to a [`NSNumber`][NSNumber] with a value of `0` or `1`.

*   The [JSON specification][RFC 4627] does not specify the details or requirements for JSON Number values, nor does it specify how errors due to conversion should be handled.  In general, JSONKit will not accept JSON that contains JSON Number values that it can not convert with out error or loss of precision.

    For non-floating-point numbers (i.e., JSON Number values that do not include a `.` or `e|E`), JSONKit uses a 64-bit C primitive type internally, regardless of whether the target architecture is 32-bit or 64-bit.  For unsigned values (i.e., those that do not begin with a `-`), this allows for values up to <code>2<sup>64</sup>-1</code> and up to <code>-2<sup>63</sup></code>   for negative values.  As a special case, the JSON Number `-0` is treated as a floating-point number since the underlying floating-point primitive type is capable of representing a negative zero, whereas the underlying twos-complement non-floating-point primitive type can not.  JSON that contains Number values that exceed these limits will fail to parse and optionally return a [`NSError`][NSError] object. The functions [`strtoll()`][strtoll] and [`strtoull()`][strtoull] are used to perform the conversions.

    The C `double` primitive type, or [IEEE 754 Double 64-bit floating-point][Double Precision], is used to represent floating-point JSON Number values.  JSON that contains floating-point Number values that can not be represented as a `double` (i.e., due to over or underflow) will fail to parse and optionally return a [`NSError`][NSError] object.  The function [`strtod()`][strtod] is used to perform the conversion.  Note that the JSON standard does not allow for infinities or `NaN` (Not a Number).  The conversion and manipulation of [floating-point values is non-trivial](http://www.validlab.com/goldberg/paper.pdf).  Unfortunately, [RFC 4627][] is silent on how such details should be handled.  You should not depend on or expect that when a floating-point value is round tripped that it will have the same textual representation or even compare equal.  This is true even when JSONKit is used as both the parser and creator of the JSON, let alone when transferring JSON between different systems and implementations.
    
*   For JSON Objects (or [`NSDictionary`][NSDictionary] in JSONKit nomenclature), [RFC 4627][] says `The names within an object SHOULD be unique` (note: `name` is a `key` in JSONKit nomenclature). At this time the JSONKit behavior is `undefined` for JSON that contains names within an object that are not unique.  However, JSONKit currently tries to follow a "the last key / value pair parsed is the one chosen" policy. This behavior is not finalized and should not be depended on.
    
    The previously covered limitations regarding JSON Strings have important consequences for JSON Objects since JSON Strings are used as the `key`.  The [JSON specification][RFC 4627] does not specify the details or requirements for JSON Strings used as `keys` in JSON Objects, specifically what it means for two `keys` to compare equal.  Unfortunately, because [RFC 4627][] states `JSON text SHALL be encoded in Unicode.`, this means that one must use the [Unicode Standard][] to interpret the JSON, and the [Unicode Standard][] allows for strings that are encoded with different Unicode Code Points to "compare equal".  JSONKit uses [`NSString`][NSString] exclusively to manage the parsed JSON Strings.  Because [`NSString`][NSString] uses [Unicode][Unicode Standard] as its basis, there exists the possibility that [`NSString`][NSString] may subtly and silently convert the Unicode Code Points contained in the original JSON String in to a [Unicode equivalent][Unicode_equivalence] string.  Due to this, the JSONKit behavior for JSON Strings used as `keys` in JSON Objects that may be [Unicode equivalent][Unicode_equivalence] but not binary equivalent is `undefined`.

### Objective-C To JSON Primitive Mapping Details

*    When serializing, the top level container, and all of its children, are required to be *strictly* [invariant][wiki_invariant] during enumeration.  This property is used to make certain optimizations, such as if a particular object has already been serialized, the result of the previous serialized `UTF8` string can be reused (i.e., the `UTF8` string of the previous serialization can simply be copied instead of performing all the serialization work again).  While this is probably only of interest to those who are doing extraordinarily unusual things with the run-time or custom classes inheriting from the classes that JSONKit will serialize (i.e, a custom object whose value mutates each time the it receives a message requesting its value for serialization), it also covers the case where any of the objects to be serialized are mutated during enumeration (i.e., mutated by another thread).  The number of times JSONKit will request an objects value is non-deterministic, from a minimum of once up to the number of times it appears in the serialized JSON&ndash; therefore an object MUST NOT depend on receiving a message requesting its value each time it appears in the serialized output. The behavior is `undefined` if these requirements are violated.

*   The objects to be serialized MUST be acyclic.  If the objects to be serialized contain circular references the behavior is `undefined`.  For example,

    <pre>[arrayOne addObject:arrayTwo];
    [arrayTwo addObject:arrayOne];
    id json = [arrayOne JSONString];</pre>
    
    &hellip; will result in `undefined` behavior.

*   The contents of [`NSString`][NSString] objects are encoded as `UTF8` and added to the serialized JSON.  JSONKit assumes that [`NSString`][NSString] produces well-formed `UTF8` Unicode and does no additional validation of the conversion.  When `JKSerializeOptionEscapeUnicode` is enabled, JSONKit will encode Unicode code points that can be encoded as a single `UTF16` code unit as <code>\u<i>XXXX</i></code>, and will encode Unicode code points that require `UTF16` surrogate pairs as <code>\u<i>high</i>\u<i>low</i></code>.  While JSONKit makes every effort to serialize the contents of a [`NSString`][NSString] object exactly, modulo any [RFC 4627][] requirements, the [`NSString`][NSString] class uses the [Unicode Standard][] as its basis for representing strings.  You should be aware that the [Unicode Standard][] defines [string equivalence][Unicode_equivalence] in a such a way that two strings that compare equal are not required to be bit for bit identical.  Therefore there exists the possibility that [`NSString`][NSString] may mutate a string in such a way that it is [Unicode equivalent][Unicode_equivalence], but not bit for bit identical with the original string. 

*   The [`NSDictionary`][NSDictionary] class allows for any object, which can be of any class, to be used as a `key`.  JSON, however, only permits Strings to be used as `keys`. Therefore JSONKit will fail with an error if it encounters a [`NSDictionary`][NSDictionary] that contains keys that are not [`NSString`][NSString] objects during serialization.  More specifically, the keys must return `YES` when sent [`-isKindOfClass:[NSString class]`][-isKindOfClass:]. 

*   JSONKit will fail with an error if it encounters an object that is not a [`NSNull`][NSNull], [`NSNumber`][NSNumber], [`NSString`][NSString], [`NSArray`][NSArray], or [`NSDictionary`][NSDictionary] class object during serialization.  More specifically, JSONKit will fail with an error if it encounters an object where [`-isKindOfClass:`][-isKindOfClass:] returns `NO` for all of the previously mentioned classes.

*   JSON does not allow for Numbers that are <code>&plusmn;Infinity</code> or <code>&plusmn;NaN</code>.  Therefore JSONKit will fail with an error if it encounters a [`NSNumber`][NSNumber] that contains such a value during serialization.

*   Objects created with [`[NSNumber numberWithBool:YES]`][NSNumber_numberWithBool] and [`[NSNumber numberWithBool:NO]`][NSNumber_numberWithBool] will be mapped to the JSON values of `true` and `false`, respectively.  More specifically, an object must have pointer equality with [`kCFBooleanTrue`][kCFBooleanTrue] or [`kCFBooleanFalse`][kCFBooleanFalse] (i.e., `if((id)object == (id)kCFBooleanTrue)`) in order to be mapped to the JSON values `true` and `false`.

*   [`NSNumber`][NSNumber] objects that are not booleans (as defined above) are sent [`-objCType`][-objCType] to determine what type of C primitive type they represent.  Those that respond with a type from the set `cislq` are treated as `long long`, those that respond with a type from the set `CISLQB` are treated as `unsigned long long`, and those that respond with a type from the set `fd` are treated as `double`.  [`NSNumber`][NSNumber] objects that respond with a type not in the set of types mentioned will cause JSONKit to fail with an error.
    
    More specifically, [`CFNumberGetValue(object, kCFNumberLongLongType, &longLong)`][CFNumberGetValue] is used to retrieve the value of both the signed and unsigned integer values, and the type reported by [`-objCType`][-objCType] is used to determine whether the result is signed or unsigned.  For floating-point values, [`CFNumberGetValue`][CFNumberGetValue] is used to retrieve the value using [`kCFNumberDoubleType`][kCFNumberDoubleType] for the type argument.
    
    Floating-point numbers are converted to their decimal representation using the [`printf`][printf] format conversion specifier `%.17g`.  Theoretically this allows up to a `float`, or [IEEE 754 Single 32-bit floating-point][Single Precision], worth of precision to be represented.  This means that for practical purposes, `double` values are converted to `float` values with the associated loss of precision.  The [RFC 4627][] standard is silent on how floating-point numbers should be dealt with and the author has found that real world JSON implementations vary wildly in how they handle this issue.  Furthermore, the `%g` format conversion specifier may convert floating-point values that can be exactly represented as an integer to a textual representation that does not include a `.` or `e`&ndash; essentially silently promoting a floating-point value to an integer value (i.e, `5.0` becomes `5`).  Because of these and many other issues surrounding the conversion and manipulation of floating-point values, you should not expect or depend on floating point values to maintain their full precision, or when round tripped, to compare equal.


### Reporting Bugs

Please use the [github.com JSONKit Issue Tracker](https://github.com/johnezang/JSONKit/issues) to report bugs.

The author requests that you do not file a bug report with JSONKit regarding problems reported by the `clang` static analyzer unless you first manually verify that it is an actual, bona-fide problem with JSONKit and, if appropriate, is not "legal" C code as defined by the C99 language specification.  If the `clang` static analyzer is reporting a problem with JSONKit that is not an actual, bona-fide problem and is perfectly legal code as defined by the C99 language specification, then the appropriate place to file a bug report or complaint is with the developers of the `clang` static analyzer.

### Important Details

*   JSONKit is not designed to be used with the Mac OS X Garbage Collection.  The behavior of JSONKit when compiled with `-fobj-gc` is `undefined`.  It is extremely unlikely that Mac OS X Garbage Collection will ever be supported.

*   The JSON to be parsed by JSONKit MUST be encoded as Unicode.  In the unlikely event you end up with JSON that is not encoded as Unicode, you must first convert the JSON to Unicode, preferably as `UTF8`.  One way to accomplish this is with the [`NSString`][NSString] methods [`-initWithBytes:length:encoding:`][NSString_initWithBytes] and [`-initWithData:encoding:`][NSString_initWithData].

*   Internally, the low level parsing engine uses `UTF8` exclusively.  The `JSONDecoder` method `-objectWithData:` takes a [`NSData`][NSData] object as its argument and it is assumed that the raw bytes contained in the [`NSData`][NSData] is `UTF8` encoded, otherwise the behavior is `undefined`.

*   It is not safe to use the same instantiated `JSONDecoder` object from multiple threads at the same time.  If you wish to share a `JSONDecoder` between threads, you are responsible for adding mutex barriers to ensure that only one thread is decoding JSON using the shared `JSONDecoder` object at a time.

### Tips for speed

*   Enable the `NS_BLOCK_ASSERTIONS` pre-processor flag.  JSONKit makes heavy use of [`NSCParameterAssert()`][NSCParameterAssert] internally to ensure that various arguments, variables, and other state contains only legal and expected values.  If an assertion check fails it causes a run time exception that will normally cause a program to terminate.  These checks and assertions come with a price: they take time to execute and do not contribute to the work being performed.  It is perfectly safe to enable `NS_BLOCK_ASSERTIONS` as JSONKit always performs checks that are required for correct operation.  The checks performed with [`NSCParameterAssert()`][NSCParameterAssert] are completely optional and are meant to be used in "debug" builds where extra integrity checks are usually desired.  While your mileage may vary, the author has found that adding `-DNS_BLOCK_ASSERTIONS` to an `-O2` optimization setting can generally result in an approximate <span style="white-space: nowrap;">7-12%</span> increase in performance.

*   Since the very low level parsing engine works exclusively with `UTF8` byte streams, anything that is not already encoded as `UTF8` must first be converted to `UTF8`.  While JSONKit provides additions to the [`NSString`][NSString] class which allows you to conveniently convert JSON contained in a [`NSString`][NSString], this convenience does come with a price. JSONKit must allocate an autoreleased [`NSMutableData`][NSMutableData] large enough to hold the strings `UTF8` conversion and then convert the string to `UTF8` before it can begin parsing.  This takes both memory and time.  Once the parsing has finished, JSONKit sets the autoreleased [`NSMutableData`][NSMutableData] length to `0`, which allows the [`NSMutableData`][NSMutableData] to release the memory.  This helps to minimize the amount of memory that is in use but unavailable  until the autorelease pool pops. Therefore, if speed and memory usage are a priority, you should avoid using the [`NSString`][NSString] convenience methods if possible.

*   If you are receiving JSON data from a web server, and you are able to determine that the raw bytes returned by the web server is JSON encoded as `UTF8`, you should use the `JSONDecoder` method `-objectWithUTF8String:length:` which immediately begins parsing the pointers bytes. In practice, every JSONKit method that converts JSON to an Objective-C object eventually calls this method to perform the conversion.

*   If you are using one of the various ways provided by the `NSURL` family of classes to receive JSON results from a web server, which typically return the results in the form of a [`NSData`][NSData] object, and you are able to determine that the raw bytes contained in the [`NSData`][NSData] are encoded as `UTF8`, then you should use either the `JSONDecoder` method `objectWithData:` or the [`NSData`][NSData] method `-objectFromJSONData`.  If are going to be converting a lot of JSON, the better choice is to instantiate a `JSONDecoder` object once and use the same instantiated object to perform all your conversions.  This has two benefits:
    1. The [`NSData`][NSData] method `-objectFromJSONData` creates an autoreleased `JSONDecoder` object to perform the one time conversion.  By instantiating a `JSONDecoder` object once and using the `objectWithData:` method repeatedly, you can avoid this overhead.
    2. The instantiated object cache from the previous JSON conversion is reused.  This can result in both better performance and a reduction in memory usage if the JSON your are converting is very similar.  A typical example might be if you are converting JSON at periodic intervals that consists of real time status updates.

*   On average, the <code>JSONData&hellip;</code> methods are nearly four times faster than the <code>JSONString&hellip;</code> methods when serializing a [`NSDictionary`][NSDictionary] or [`NSArray`][NSArray] to JSON.  The difference in speed is due entirely to the instantiation overhead of [`NSString`][NSString].

### Parsing Interface

#### JSONDecoder Interface

The <code>objectWith&hellip;</code> methods return immutable collection objects and their respective <code>mutableObjectWith&hellip;</code> methods return mutable collection objects.

**Note:** The bytes contained in a [`NSData`][NSData] object ***MUST*** be `UTF8` encoded.

**Important:** Methods will raise [`NSInvalidArgumentException`][NSInvalidArgumentException] if `parseOptionFlags` is not valid.  
**Important:** `objectWithUTF8String:` and `mutableObjectWithUTF8String:` will raise [`NSInvalidArgumentException`][NSInvalidArgumentException] if `string` is `NULL`.  
**Important:** `objectWithData:` and `mutableObjectWithData:` will raise [`NSInvalidArgumentException`][NSInvalidArgumentException] if `jsonData` is `NULL`.

<pre>+ (id)decoder;
+ (id)decoderWithParseOptions:(JKParseOptionFlags)parseOptionFlags;
- (id)initWithParseOptions:(JKParseOptionFlags)parseOptionFlags;

- (void)clearCache;

- (id)objectWithUTF8String:(const unsigned char *)string length:(size_t)length;
- (id)objectWithUTF8String:(const unsigned char *)string length:(size_t)length error:(NSError **)error;
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(size_t)length;
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(size_t)length error:(NSError **)error;

- (id)objectWithData:(NSData *)jsonData;
- (id)objectWithData:(NSData *)jsonData error:(NSError **)error;
- (id)mutableObjectWithData:(NSData *)jsonData;
- (id)mutableObjectWithData:(NSData *)jsonData error:(NSError **)error;</pre>

#### NSString Interface

<pre>- (id)objectFromJSONString;
- (id)objectFromJSONStringWithParseOptions:(JKParseOptionFlags)parseOptionFlags;
- (id)objectFromJSONStringWithParseOptions:(JKParseOptionFlags)parseOptionFlags error:(NSError **)error;
- (id)mutableObjectFromJSONString;
- (id)mutableObjectFromJSONStringWithParseOptions:(JKParseOptionFlags)parseOptionFlags;
- (id)mutableObjectFromJSONStringWithParseOptions:(JKParseOptionFlags)parseOptionFlags error:(NSError **)error;</pre>

#### NSData Interface

<pre>- (id)objectFromJSONData;
- (id)objectFromJSONDataWithParseOptions:(JKParseOptionFlags)parseOptionFlags;
- (id)objectFromJSONDataWithParseOptions:(JKParseOptionFlags)parseOptionFlags error:(NSError **)error;
- (id)mutableObjectFromJSONData;
- (id)mutableObjectFromJSONDataWithParseOptions:(JKParseOptionFlags)parseOptionFlags;
- (id)mutableObjectFromJSONDataWithParseOptions:(JKParseOptionFlags)parseOptionFlags error:(NSError **)error;</pre>

#### JKParseOptionFlags

<table>
  <tr><th>Parsing Option</th><th>Description</th></tr>
  <tr><td><code>JKParseOptionNone</code></td><td>This is the default if no other other parse option flags are specified, and the option used when a convenience method does not provide an argument for explicitly specifying the parse options to use.  Synonymous with <code>JKParseOptionStrict</code>.</td></tr>
  <tr><td><code>JKParseOptionStrict</code></td><td>The JSON will be parsed in strict accordance with the <a href="http://tools.ietf.org/html/rfc4627">RFC 4627</a> specification.</td></tr>
  <tr><td><code>JKParseOptionComments</code></td><td>Allow C style <code>//</code> and <code>/* &hellip; */</code> comments in JSON.  This is a fairly common extension to JSON, but JSON that contains C style comments is not strictly conforming JSON.</td></tr>
  <tr><td><code>JKParseOptionUnicodeNewlines</code></td><td>Allow Unicode recommended <code>(?:\r\n|[\n\v\f\r\x85\p{Zl}\p{Zp}])</code> newlines in JSON.  The <a href="http://tools.ietf.org/html/rfc4627">JSON specification</a> only allows the newline characters <code>\r</code> and <code>\n</code>, but this option allows JSON that contains the <a href="http://en.wikipedia.org/wiki/Newline#Unicode">Unicode recommended newline characters</a> to be parsed.  JSON that contains these additional newline characters is not strictly conforming JSON.</td></tr>
  <tr><td><code>JKParseOptionLooseUnicode</code></td><td>Normally the decoder will stop with an error at any malformed Unicode. This option allows JSON with malformed Unicode to be parsed without reporting an error. Any malformed Unicode is replaced with <code>\uFFFD</code>, or <code>REPLACEMENT CHARACTER</code>, as specified in <a href="http://www.unicode.org/versions/Unicode6.0.0/ch03.pdf">The Unicode 6.0 standard, Chapter 3</a>, section 3.9 <em>Unicode Encoding Forms</em>.</td></tr>
  <tr><td><code>JKParseOptionPermitTextAfterValidJSON</code></td><td>Normally, <code>non-white-space</code> that follows the JSON is interpreted as a parsing failure. This option allows for any trailing <code>non-white-space</code> to be ignored and not cause a parsing error.</td></tr>
</table>

### Serializing Interface

The serializing interface includes [`NSString`][NSString] convenience methods for those that need to serialize a single [`NSString`][NSString].  For those that need this functionality, the [`NSString`][NSString] additions are much more convenient than having to wrap a single [`NSString`][NSString] in a [`NSArray`][NSArray], which then requires stripping the unneeded `[`&hellip;`]` characters from the serialized JSON result.  When serializing a single [`NSString`][NSString], you can control whether or not the serialized JSON result is surrounded by quotation marks using the `includeQuotes:` argument:

<table>
<tr><th>Example</th><th>Result</th><th>Argument</th></tr>
<tr><td><code>a "test"...</code></td><td><code>"a \"test\"..."</code></td><td><code>includeQuotes:YES</code></td></tr>
<tr><td><code>a "test"...</code></td><td><code>a \"test\"...</code></td><td><code>includeQuotes:NO</code></td></tr>
</table>

**Note:** The [`NSString`][NSString] methods that do not include a `includeQuotes:` argument behave as if invoked with `includeQuotes:YES`.  
**Note:** The bytes contained in the returned [`NSData`][NSData] object are `UTF8` encoded.

#### NSArray and NSDictionary Interface

<pre>- (NSData *)JSONData;
- (NSData *)JSONDataWithOptions:(JKSerializeOptionFlags)serializeOptions error:(NSError **)error;
- (NSString *)JSONString;
- (NSString *)JSONStringWithOptions:(JKSerializeOptionFlags)serializeOptions error:(NSError **)error;</pre>

#### NSString Interface

<pre>- (NSData *)JSONData;
- (NSData *)JSONDataWithOptions:(JKSerializeOptionFlags)serializeOptions includeQuotes:(BOOL)includeQuotes error:(NSError **)error;
- (NSString *)JSONString;
- (NSString *)JSONStringWithOptions:(JKSerializeOptionFlags)serializeOptions includeQuotes:(BOOL)includeQuotes error:(NSError **)error;</pre>

#### JKSerializeOptionFlags

<table>
  <tr><th>Serializing Option</th><th>Description</th></tr>
  <tr><td><code>JKSerializeOptionNone</code></td><td>This is the default if no other other serialize option flags are specified, and the option used when a convenience method does not provide an argument for explicitly specifying the serialize options to use.</td></tr>
  <tr><td><code>JKSerializeOptionPretty</code></td><td>Normally the serialized JSON does not include any unnecessary <code>white-space</code>.  While this form is the most compact, the lack of any <code>white-space</code> means that it's something only another JSON parser could love.  Enabling this option causes JSONKit to add additional <code>white-space</code> that makes it easier for people to read.  Other than the extra <code>white-space</code>, the serialized JSON is identical to the JSON that would have been produced had this option not been enabled.</td></tr>
  <tr><td><code>JKSerializeOptionEscapeUnicode</code></td><td>When JSONKit encounters Unicode characters in <a href="http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/index.html"><code>NSString</code></a> objects, the default behavior is to encode those Unicode characters as <code>UTF8</code>.  This option causes JSONKit to encode those characters as <code>\u<i>XXXX</i></code>.  For example,<br/><code>["w&isin;L&#10234;y(&#8739;y&#8739;&le;&#8739;w&#8739;)"]</code><br/>becomes:<br/><code>["w\u2208L\u27fa\u2203y(\u2223y\u2223\u2264\u2223w\u2223)"]</code></td></tr>
</table>

[JSON]: http://www.json.org/
[RFC 4627]: http://tools.ietf.org/html/rfc4627
[RFC 2119]: http://tools.ietf.org/html/rfc2119
[Single Precision]: http://en.wikipedia.org/wiki/Single_precision_floating-point_format
[Double Precision]: http://en.wikipedia.org/wiki/Double_precision_floating-point_format
[wiki_invariant]: http://en.wikipedia.org/wiki/Invariant_(computer_science)
[CFBoolean]: http://developer.apple.com/mac/library/documentation/CoreFoundation/Reference/CFBooleanRef/index.html
[kCFBooleanTrue]: http://developer.apple.com/mac/library/documentation/CoreFoundation/Reference/CFBooleanRef/Reference/reference.html#//apple_ref/doc/c_ref/kCFBooleanTrue
[kCFBooleanFalse]: http://developer.apple.com/mac/library/documentation/CoreFoundation/Reference/CFBooleanRef/Reference/reference.html#//apple_ref/doc/c_ref/kCFBooleanFalse
[kCFNumberDoubleType]: http://developer.apple.com/library/mac/documentation/CoreFoundation/Reference/CFNumberRef/Reference/reference.html#//apple_ref/doc/c_ref/kCFNumberDoubleType
[CFNumberGetValue]: http://developer.apple.com/library/mac/documentation/CoreFoundation/Reference/CFNumberRef/Reference/reference.html#//apple_ref/c/func/CFNumberGetValue
[Unicode Standard]: http://www.unicode.org/versions/Unicode6.0.0/
[Unicode Standard - Conformance]: http://www.unicode.org/versions/Unicode6.0.0/ch03.pdf
[Unicode_equivalence]: http://en.wikipedia.org/wiki/Unicode_equivalence
[UnicodeNewline]: http://en.wikipedia.org/wiki/Newline#Unicode
[Unicode_UTR36]: http://www.unicode.org/reports/tr36/
[Unicode_UTR36_NonVisualSecurity]: http://www.unicode.org/reports/tr36/#Canonical_Represenation
[Unicode_UTR36_Deleting]: http://www.unicode.org/reports/tr36/#Deletion_of_Noncharacters
[Unicode_Security_FAQ]: http://www.unicode.org/faq/security.html
[NSNull]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSNull_Class/index.html
[NSNumber]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSNumber_Class/index.html
[NSNumber_numberWithBool]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSNumber_Class/Reference/Reference.html#//apple_ref/occ/clm/NSNumber/numberWithBool:
[NSString]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/index.html
[NSString_initWithBytes]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/Reference/NSString.html#//apple_ref/occ/instm/NSString/initWithBytes:length:encoding:
[NSString_initWithData]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/Reference/NSString.html#//apple_ref/occ/instm/NSString/initWithData:encoding:
[NSString_UTF8String]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/Reference/NSString.html#//apple_ref/occ/instm/NSString/UTF8String
[NSArray]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/index.html
[NSDictionary]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/index.html
[NSError]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSError_Class/index.html
[NSData]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSData_Class/index.html
[NSMutableData]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSMutableData_Class/index.html
[NSInvalidArgumentException]: http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Constants/Reference/reference.html#//apple_ref/doc/c_ref/NSInvalidArgumentException
[CFString]: http://developer.apple.com/library/mac/#documentation/CoreFoundation/Reference/CFStringRef/Reference/reference.html
[NSCParameterAssert]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Functions/Reference/reference.html#//apple_ref/c/macro/NSCParameterAssert
[-mutableCopy]: http://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSObject_Class/Reference/Reference.html%23//apple_ref/occ/instm/NSObject/mutableCopy
[-isKindOfClass:]: http://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Protocols/NSObject_Protocol/Reference/NSObject.html%23//apple_ref/occ/intfm/NSObject/isKindOfClass:
[-objCType]: http://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSNumber_Class/Reference/Reference.html#//apple_ref/occ/instm/NSNumber/objCType
[strtoll]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/strtoll.3.html
[strtod]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/strtod.3.html
[strtoull]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/strtoull.3.html
[getrusage]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man2/getrusage.2.html
[printf]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/printf.3.html
