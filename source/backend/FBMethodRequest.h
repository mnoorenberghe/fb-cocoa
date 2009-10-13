//
//  FBRequest.h
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBConnect.h"
#import "FBCallback.h"
#import "FBRequest.h"


@interface FBMethodRequest : FBCallback <FBRequest> {
  BOOL requestStarted;
  BOOL requestFinished;

  NSString* request;
  NSMutableData *responseBuffer;
  FBConnect *parentConnect;
  NSURLConnection *connection;
}

+(FBMethodRequest*) requestWithRequest:(NSString *)requestString
                          parent:(FBConnect *)parent
                          target:(id)tar
                        selector:(SEL)sel
                           error:(SEL)err;

- (void)start;

@end
