//
//  FBRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBRequest.h"
#import "FBConnect.h"

@interface FBRequest (Private)

- (NSError *)errorForResponse:(NSXMLDocument *)xml;

@end


@interface FBConnect (FBRequestResults)

- (void)failedQuery:(FBRequest *)query withError:(NSError *)err;

@end


@implementation FBRequest

-(id)initWithRequest:(NSURLRequest *)req
              target:(id)tar
            selector:(SEL)sel
              parent:(FBConnect *)parent
               error:(SEL)err
{
  if (!(self = [super initWithRequest:req delegate:self])) {
    return nil;
  }

  target = [tar retain];
  method = sel;
  parentConnect = parent;
  errorMethod = err;
  responseBuffer = [[NSMutableData alloc] init];

  return self;
}

-(void)dealloc
{
  [target release];
  [responseBuffer release];
  [super dealloc];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseBuffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  BOOL isError = ([[[xml rootElement] name] isEqualToString:@"error_response"]);
  if (isError) {
    NSError *err = [self errorForResponse:xml];

    [parentConnect failedQuery:self withError:err];

    if (target && errorMethod && [target respondsToSelector:errorMethod]) {
      [target performSelector:errorMethod withObject:err];
    }
  } else {
    if (target && method && [target respondsToSelector:method]) {
      [target performSelector:method withObject:xml];
    }
  }

  // peace!
  [xml release];
  [self release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err
{
  [parentConnect failedQuery:self withError:err];

  if (target && errorMethod && [target respondsToSelector:errorMethod]) {
    [target performSelector:errorMethod withObject:err];
  }

  // laaater!
  [self release];
}

#pragma mark Private Methods
- (NSError *)errorForResponse:(NSXMLDocument *)xml
{
  if (![[[xml rootElement] name] isEqualToString:@"error_response"]) {
    return nil;
  }

  int code = -1;
  NSString *message = nil;
  for (NSXMLNode *node in [[xml rootElement] children]) {
    if ([[node name] isEqualToString:@"error_code"]) {
      code = [[node stringValue] intValue];
    } else if ([[node name] isEqualToString:@"error_msg"]) {
      message = [node stringValue];
    }
  }

  return [NSError errorWithDomain:kFBErrorDomainKey
                             code:code
                         userInfo:[NSDictionary dictionaryWithObject:message
                                                              forKey:kFBErrorMessageKey]];
}

@end
