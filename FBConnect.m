//
//  FBConnect.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBConnect.h"
#import "FBRequest.h"
#import "FBCrypto.h"
#import "FBWebViewWindowController.h"
#import "FBSession.h"
#import "NSStringAdditions.h"

#define kRESTServerURL @"http://api.facebook.com/restserver.php?"
#define kAPIVersion @"1.0"
#define kErrorCodeInvalidSession 102

/*
 * These are shortcuts for calling delegate methods. They check to see if there
 * is a delegate and if the delegate responds to the selector passed as the
 * first argument. DELEGATEn is the call you use when there are n additional
 * arguments beyond "self" (since delegate methods should have the delegating
 * object as the first parameter).
 */
#define DELEGATE(sel) {if (delegate && [delegate respondsToSelector:(sel)]) {\
[delegate performSelector:(sel)];}}


@interface FBConnect (Private)

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj;

+ (NSString *)sigForArguments:(NSDictionary *)dict;

+ (void)validateSession;
+ (void)refreshSession;

@end


@implementation FBConnect

static FBConnect *instance;

static NSString *APIKey;
static NSString *appSecret;
static FBSession *session;

static BOOL isLoggedIn;
static id delegate;

static FBWebViewWindowController *windowController;

+ (void)setupWithAPIKey:(NSString *)key
                 secret:(NSString *)secret
               delegate:(id)obj
{
  instance = [[self alloc] initWithAPIKey:key secret:secret delegate:obj];
}

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj
{
  if (!(self = [super init])) {
    return nil;
  }

  APIKey     = [key retain];
  appSecret  = [secret retain];
  session    = [[FBSession alloc] init];
  delegate   = obj;
  isLoggedIn = NO;

  return self;
}

- (void)dealloc
{
  [APIKey      release];
  [appSecret   release];
  [session     release];
  [super dealloc];
}

//==============================================================================
//==============================================================================
//==============================================================================

+ (BOOL)isLoggedIn
{
  return isLoggedIn;
}

+ (NSString *)uid
{
  if (![session isValid]) {
    return nil;
  }
  return [session uid];
}

+ (void)login
{
  [FBConnect loginWithPermissions:nil];
}

+ (void)loginWithPermissions:(NSArray *)permissions
{
  if ([session isValid]) {
    [FBConnect validateSession];
  } else {
    NSMutableDictionary *loginParams = [[NSMutableDictionary alloc] init];
    if (permissions) {
      [session setPermissions:permissions];
      NSString *permissionsString = [permissions componentsJoinedByString:@","];
      [loginParams setObject:permissionsString forKey:@"req_perms"];
    }
    [loginParams setObject:APIKey      forKey:@"api_key"];
    [loginParams setObject:kAPIVersion forKey:@"v"];
    windowController =
    [[FBWebViewWindowController alloc] initWithCloseTarget:instance
                                                  selector:@selector(webViewWindowClosed)];
    [windowController showWithParams:loginParams];
  }
}

+ (void)logout
{
  [FBConnect callMethod:@"Auth.expireSession"
     withArguments:nil
            target:instance
          selector:@selector(expireSessionResponseComplete:)
             error:@selector(failedLogout:)];
}

+ (void)validateSession
{
  [FBConnect callMethod:@"users.isAppUser"
     withArguments:nil
            target:instance
          selector:@selector(gotLoggedInUser:)
             error:nil];
}

+ (void)refreshSession
{
  isLoggedIn = NO;
  NSArray *permissions = [[session permissions] retain];
  [session clear];
  [FBConnect loginWithPermissions:permissions];
  [permissions release];
}

+ (BOOL)hasPermission:(NSString *)perm
{
  return [[session permissions] containsObject:perm];
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Connect Methods
+ (void)callMethod:(NSString *)method
     withArguments:(NSDictionary *)dict
            target:(id)target
          selector:(SEL)selector
             error:(SEL)error
{
  NSMutableDictionary *args;

  if (dict) {
    args = [NSMutableDictionary dictionaryWithDictionary:dict];
  } else {
    args = [NSMutableDictionary dictionary];
  }
  [args setObject:method forKey:@"method"];
  [args setObject:APIKey forKey:@"api_key"];
  [args setObject:kAPIVersion forKey:@"v"];
  [args setObject:@"XML" forKey:@"format"];
  [args setObject:[[NSNumber numberWithLong:time(NULL)] stringValue]
           forKey:@"call_id"];
  if ([session isValid]) {
    [args setObject:[session key] forKey:@"session_key"];
  }

  NSString *sig = [self sigForArguments:args];
  [args setObject:sig forKey:@"sig"];

  NSString *server = kRESTServerURL;
  NSURL *url = [NSURL URLWithString:[server stringByAppendingString:[NSString urlEncodeArguments:args]]];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setHTTPMethod:@"GET"];
  [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];

  FBRequest *currentConnection = [[FBRequest alloc] initWithRequest:req
                                                             target:target
                                                           selector:selector
                                                              error:error];
  [currentConnection start];
}

+ (void)sendFQLQuery:(NSString *)query
              target:(id)target
            selector:(SEL)selector
               error:(SEL)error
{
  NSDictionary *dict = [NSDictionary dictionaryWithObject:query forKey:@"query"];
  [FBConnect callMethod:@"Fql.query"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

+ (void)sendFQLMultiquery:(NSDictionary *)queries
                   target:(id)target
                 selector:(SEL)selector
                    error:(SEL)error
{
  // Encode the NSDictionary in JSON.
  NSString *entryFormat = @"\"%@\" : \"%@\"";
  NSMutableArray *entries = [NSMutableArray array];
  for (NSString *key in queries) {
    NSString *escapedKey = [key stringByEscapingQuotesAndBackslashes];
    NSString *escapedVal = [[queries objectForKey:key] stringByEscapingQuotesAndBackslashes];
    [entries addObject:[NSString stringWithFormat:entryFormat, escapedKey,
                        escapedVal]];
  }

  NSString *finalString = [NSString stringWithFormat:@"{%@}",
                           [entries componentsJoinedByString:@","]];

  NSDictionary *dict = [NSDictionary dictionaryWithObject:finalString forKey:@"queries"];
  [FBConnect callMethod:@"Fql.multiquery"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

+ (void)failedQuery:(FBRequest *)query withError:(NSError *)err
{
  if ([session isValid] && [err code] == kErrorCodeInvalidSession) {
    // We were using a session key that we'd saved as permanent, and got
    // back an error saying it was invalid. Throw away the saved session
    // data and start a login from scratch.
    [FBConnect refreshSession];
  }

}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Callbacks
- (void)gotLoggedInUser:(NSXMLDocument *)xml
{
  if ([xml rootElement] != nil) {
    isLoggedIn = YES;
    DELEGATE(@selector(fbConnectLoggedIn));
  } else {
    [FBConnect refreshSession];
  }
}

- (void)expireSessionResponseComplete:(NSXMLDocument *)xml
{
  [session clear];
  DELEGATE(@selector(fbConnectLoggedOut));
}

- (void)failedLogout:(NSError *)error
{
  NSLog(@"fbConnect logout failed: %@", [[error userInfo] objectForKey:kFBErrorMessageKey]);
  DELEGATE(@selector(fbConnectErrorLoggingOut));
}

- (void)webViewWindowClosed
{
  if ([windowController success]) {
    isLoggedIn = YES;

    NSString *url = [[windowController lastURL] absoluteString];
    NSRange startSession = [url rangeOfString:@"session="];
    if (startSession.location != NSNotFound) {
      NSString *rawSession = [url substringFromIndex:(startSession.location + startSession.length)];
      NSDictionary *sessDict = [[rawSession stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] simpleJSONDecode];
      [session setWithDictionary:sessDict];
    } else {
      isLoggedIn = NO;
    }
  } else {
    isLoggedIn = NO;
  }
  [windowController release];

  if (isLoggedIn) {
    DELEGATE(@selector(fbConnectLoggedIn));
  } else {
    DELEGATE(@selector(fbConnectErrorLoggingIn));
  }
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Private Methods
+ (NSString *)sigForArguments:(NSDictionary *)dict
{
  NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableString *args = [NSMutableString string];
  for (NSString *key in sortedKeys) {
    [args appendString:key];
    [args appendString:@"="];
    [args appendString:[dict objectForKey:key]];
  }

  if ([session isValid]) {
    [args appendString:[session secret]];
  } else {
    [args appendString:appSecret];
  }
  return [FBCrypto hexMD5:args];
}

@end
