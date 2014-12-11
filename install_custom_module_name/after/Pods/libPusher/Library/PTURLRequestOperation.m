//
//  LRURLConnectionOperation.m
//  LRResty
//
//  Created by Luke Redpath on 04/10/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "PTURLRequestOperation.h"

@interface PTURLRequestOperation ()
@property (nonatomic, strong, readwrite) NSURLResponse *URLResponse;
@property (nonatomic, strong, readwrite) NSError *connectionError;
@property (nonatomic, strong, readwrite) NSData *responseData;

- (void)setExecuting:(BOOL)isExecuting;
- (void)setFinished:(BOOL)isFinished;
@end

#pragma mark -

@implementation PTURLRequestOperation

@synthesize URLRequest;
@synthesize URLResponse;
@synthesize connectionError;
@synthesize responseData;

- (id)initWithURLRequest:(NSURLRequest *)request;
{
  if ((self = [super init])) {
    URLRequest = request;
  }
  return self;
}


- (void)start 
{
  NSAssert(URLRequest, @"Cannot start URLRequestOperation without a NSURLRequest.");
  
  if (![NSThread isMainThread]) {
    return [self performSelector:@selector(start) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
  }
  
  if ([self isCancelled]) {
    [self finish];
    return;
  }
  
  [self setExecuting:YES];
  
  URLConnection = [[NSURLConnection alloc] initWithRequest:URLRequest delegate:self startImmediately:NO];
  
  if (URLConnection == nil) {
    [self setFinished:YES]; 
  }
  
  // Common modes instead of default so it won't stall uiscrollview scrolling
  [URLConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  [URLConnection start];
}

- (void)finish;
{
  [self setFinished:YES];
}

- (BOOL)isConcurrent
{
  return YES;
}

- (BOOL)isExecuting
{
  return _isExecuting;
}

- (BOOL)isFinished
{
  return _isFinished;
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)theResponse
{ 
  self.URLResponse = theResponse;
  self.responseData = [NSMutableData data];
  
  [self checkForCancellation];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  if (self.responseData == nil) { // this might be called before didReceiveResponse
    self.responseData = [NSMutableData data];
  }
  
  [responseData appendData:data];
  
  [self checkForCancellation];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  self.connectionError = error;
  [self finish];
}

- (void)cancelImmediately
{
  [URLConnection cancel];
  [self finish];
}

- (void)checkForCancellation
{
  if ([self isCancelled]) {
    [self cancelImmediately];
  }
}

#pragma mark -
#pragma mark Private methods

- (void)setExecuting:(BOOL)isExecuting;
{
  [self willChangeValueForKey:@"isExecuting"];
  _isExecuting = isExecuting;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)isFinished;
{
  [self willChangeValueForKey:@"isFinished"];
  [self setExecuting:NO];
  _isFinished = isFinished;
  [self didChangeValueForKey:@"isFinished"];
}

@end
