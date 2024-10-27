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

  NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
  URLSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
  NSURLSessionDataTask *task = [URLSession dataTaskWithRequest:URLRequest];

  if (URLSession == nil) {
    [self setFinished:YES];
  }

  [task resume];
}

- (void)finish;
{
  if (self.isExecuting) {
    [self setExecuting:NO];
    [self setFinished:YES];
  }
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
#pragma mark NSURLSession delegate methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
  if (self.responseData == nil) { // this might be called before didReceiveResponse
    self.responseData = [NSMutableData data];
  }

  [responseData appendData:data];

  [self checkForCancellation];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
  self.connectionError = error;
  [self finish];
}

- (void)cancelImmediately
{
  [URLSession invalidateAndCancel];
  [self finish];
}

- (void)checkForCancellation
{
  if ([self isCancelled]) {
    [self cancelImmediately];
  }
}

#pragma mark -
#pragma mark NSURLSessionData delegate methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    self.URLResponse = response;
    self.responseData = [NSMutableData data];
    completionHandler(NSURLSessionResponseAllow);
}

#pragma mark -
#pragma mark Private methods

- (void)setExecuting:(BOOL)isExecuting;
{
  if (_isExecuting != isExecuting)
  {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
  }
}

- (void)setFinished:(BOOL)isFinished;
{
  if (_isFinished != isFinished)
  {
    [self willChangeValueForKey:@"isFinished"];
    [self setExecuting:NO];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
  }
}

@end
