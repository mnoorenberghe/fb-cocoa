//
//  FBWebViewWindowController.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBWebViewWindowController.h"
#import "NSString+.h"

#define kLoginURL @"http://www.facebook.com/login.php?"
#define kLoginFailureURL @"http://www.facebook.com/connect/login_failure.html"
#define kLoginSuccessURL @"http://www.facebook.com/connect/login_success.html"


@interface FBWebViewWindowController (Private)

- (void)queueRetryWithDelay:(NSTimeInterval)delay;
- (void)cancelRetry;

@end


@implementation FBWebViewWindowController

@synthesize lastURL;

- (id)initWithCloseTarget:(id)obj selector:(SEL)sel
{
  self = [super initWithWindowNibName:@"FBWebViewWindow"];
  if (self) {
    target = obj;
    selector = sel;
    success = NO;

    // Force the window to be loaded
    [[self window] center];
  }

  return self;
}

- (void)dealloc
{
  [retryTimer release];
  [super dealloc];
}

-(BOOL)success
{
  return success;
}

- (void)windowDidLoad
{
  [[[webView mainFrame] frameView] setAllowsScrolling:NO];

  // keep the window on top (modal) and make it the key.
  if ([[self window] respondsToSelector:@selector(setCollectionBehavior:)]) {
    [[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
  }
  [[self window] setLevel:NSFloatingWindowLevel];
  [[self window] makeKeyAndOrderFront:self];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)showWithParams:(NSDictionary *)params
{
  NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
  [allParams setObject:@"true"  forKey:@"fbconnect"];
  [allParams setObject:@"true"  forKey:@"nochome"];
  [allParams setObject:@"popup" forKey:@"connect_display"];
  [allParams setObject:@"popup" forKey:@"display"];

  [allParams setObject:kLoginFailureURL forKey:@"cancel_url"];
  [allParams setObject:kLoginSuccessURL forKey:@"next"];
  [allParams setObject:@"true"          forKey:@"return_session"];

  NSString *url = [NSString stringWithFormat:@"%@%@", kLoginURL, [NSString urlEncodeArguments:allParams]];
  req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  [self attemptLoad];
}

- (void)keyDown:(NSEvent *)event
{
  if ((([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) &&
      [[event charactersIgnoringModifiers] isEqualToString:@"w"]) {
    [[self window] close];
  } else {
    [super keyDown:event];
  }
}

- (void)windowWillClose:(NSNotification *)notification
{
  [self cancelRetry];
  if (target && selector && [target respondsToSelector:selector]) {
    [target performSelector:selector withObject:nil];
  }
}
    
- (void)queueRetryWithDelay:(NSTimeInterval)delay
{
  if (retryTimer) {
    [self cancelRetry];
  }
  retryTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                target:self 
                                              selector:@selector(attemptLoad)
                                              userInfo:nil
                                               repeats:NO];
}

- (void)cancelRetry
{
  if (retryTimer) {
    [retryTimer invalidate];
  }
  retryTimer = nil;
}

- (void)attemptLoad
{
  if (req == nil) {
    NSLog(@"No request was provided");
    success = NO;
    [[self window] close];
    return;
  }

  [[webView mainFrame] loadRequest:req];
  [[self window] center];
  [self showWindow:self];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
  NSLog(@"start load");
  [[self window] setTitle:@"Facebook Connect — Loading\u2026"];
  [progressIndicator startAnimation:self];

  // reset timer before retry
  [self queueRetryWithDelay:10.0];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
  NSLog(@"commit load");
  // reset timer before retry
  [self queueRetryWithDelay:20.0];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
  NSLog(@"fail load");
  // stop timer for retry and retry immediately!
  [self cancelRetry];
  [self attemptLoad];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  NSLog(@"finish load");
  // stop timer for retry
  [self cancelRetry];

  [[self window] setTitle:@"Facebook Connect"];
  [progressIndicator stopAnimation:self];
}

-                (void)webView:(WebView *)webView
decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
                       request:(NSURLRequest *)request
                  newFrameName:(NSString *)frameName
              decisionListener:(id < WebPolicyDecisionListener >)listener
{
  // This is a delegate method where we decide what to do when the WebView
  // wants to open a new window, such as when a link that wants a new window
  // is clicked. We want to show those in the user's web browser, not in the
  // WebView. (Note this method also gets called on the initial -loadRequest:.)
  if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue]
      == WebNavigationTypeLinkClicked) {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
  } else {
    [listener use];
  }
}

-                 (void)webView:(WebView *)webView
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
                        request:(NSURLRequest *)request
                          frame:(WebFrame *)frame
               decisionListener:(id < WebPolicyDecisionListener >)listener
{
  // This is a delegate method where we decide what to do when a navigation
  // action occurs. The only reason the WebView should be going to another
  // page is if a form (the login form) is submitted; if the user clicks a link,
  // we want to take them there in their normal web browser.
  if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue]
      == WebNavigationTypeLinkClicked) {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    return;
  }

  [lastURL release];
  lastURL = [[[request URL] copy] retain];

  // We want to detect when we've come across the success or failure URLs and act
  // accordingly
  if ([[[request URL] absoluteString] containsString:kLoginURL]) {
    [listener use];
  } else if ([[[request URL] absoluteString] containsString:kLoginSuccessURL]) {
    success = YES;
    [listener ignore];
    [[self window] close];
  } else if ([[[request URL] absoluteString] containsString:kLoginFailureURL] ||
             [[[request URL] absoluteString] containsString:@"home.php"]) {
    // Sometimes we get kicked to home.php, which is basically failure
    success = NO;
    [listener ignore];
    [[self window] close];
  } else {
    [listener use];
  }
}

@end
