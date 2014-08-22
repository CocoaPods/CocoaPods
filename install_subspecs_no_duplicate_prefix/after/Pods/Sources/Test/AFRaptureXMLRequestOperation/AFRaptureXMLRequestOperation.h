//
//  AFRaptureXMLRequestOperation.h
//
//  Created by Jan Sanchez on 5/13/12.
//  Copyright (c) 2013 Jan Sanchez (http://jansanchez.com)
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import "AFHTTPRequestOperation.h"
#import "RXMLElement.h"

#import <Availability.h>

/**
 `AFRaptureXMLRequestOperation` is a subclass of `AFHTTPRequestOperation` for downloading and working with XML response data.
 
 ## Acceptable Content Types
 
 By default, `AFRaptureXMLRequestOperation` accepts the following MIME types, which includes the official standard, `application/xml`, as well as other commonly-used types:
 
 - `application/xml`
 - `text/xml`
 
 @warning `AFRaptureXMLRequestOperation` requires RaptureXML to also be added to the project. Please consult the RaptureXML documentation for details on how to add it to your project.
 
 ## Use With AFHTTPClient
 
 When `AFRaptureXMLRequestOperation` is registered with `AFHTTPClient`, the response object in the success callback of `HTTPRequestOperationWithRequest:success:failure:` will be an instance of `RXMLElement`.
 */

@interface AFRaptureXMLRequestOperation : AFHTTPRequestOperation

///----------------------------
/// @name Getting Response Data
///----------------------------

/**
 A RXMLElement constructed from the response data. If an error occurs while parsing, `nil` will be returned, and the `error` property will be set to the error.
 */
@property (readonly, nonatomic, strong) RXMLElement *responseXMLElement;

/**
 Creates and returns an `AFRaptureXMLRequestOperation` object and sets the specified success and failure callbacks.
 
 @param urlRequest The request object to be loaded asynchronously during execution of the operation
 @param success A block object to be executed when the operation finishes successfully. This block has no return value and takes three arguments: the request sent from the client, the response received from the server, and the XML parser constructed with the response data of request.
 @param failure A block object to be executed when the operation finishes unsuccessfully. This block has no return value and takes three arguments: the request sent from the client, the response received from the server, and the error describing the network error that occurred.
 
 @return A new XML request operation
 */
+ (AFRaptureXMLRequestOperation *)XMLParserRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                               success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, RXMLElement *XMLElement))success
                                                               failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, RXMLElement *XMLElement))failure;

@end
