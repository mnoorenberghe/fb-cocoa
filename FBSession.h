//
//  FBSession.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kFBErrorDomainKey @"kFBErrorDomainKey"
#define kFBErrorMessageKey @"kFBErrorMessageKey"

@class FBSession;
@class FBWebViewWindowController;

/*!
 * @category FBSessionDelegate(NSObject)
 * These are methods that FBSession may call on its delegate. They are all
 * optional.
 */
@interface NSObject (FBSessionDelegate)

/*!
 * Called when the FBSession has completed logging into Facebook. This means
 * that it has obtained a valid session key and session secret, and that a
 * meaningful value will be returned from -uid.
 * @param session The caller.
 */
- (void)sessionCompletedLogin:(FBSession *)session;

/*!
 * Called when the FBSession has completed logging out of Facebook.
 * @param session The caller.
 */
- (void)sessionCompletedLogout:(FBSession *)session;

/*!
 * Called when login has failed. The reason for failure is encapsulated in the
 * NSError passed.
 * @param session The caller.
 * @param error An NSError detailing why the login failed. The error code
 * returned by Facebook can be obtained by calling [error code], and the error
 * message returned by Facebook is under the key kFBErrorMessageKey in the
 * error's userInfo dictionary.
 */
- (void)session:(FBSession *)session failedLogin:(NSError *)error;

/*!
 * Called when a logout request has failed.
 * @param session The caller.
 * @param error An NSError detailing why the logout failed. The error code
 * returned by Facebook can be obtained by calling [error code], and the error
 * message returned by Facebook is under the key kFBErrorMessageKey in the
 * error's userInfo dictionary.
 */
- (void)session:(FBSession *)session failedLogout:(NSError *)error;

@end


/*!
 * @class FBSession
 *
 * FBSession handles all transactions with the Facebook API: logging in and
 * sending FQL queries.
 */
@interface FBSession : NSObject {
  NSString *APIKey;
  NSString *appSecret;
  NSString *sessionSecret;
  NSString *sessionKey;
  NSString *authToken;
  NSString *uid;
  NSString *userDefaultsKey;
  BOOL usingSavedSession;

  id delegate;

  FBWebViewWindowController *windowController;
}

+ (FBSession *)session;

/*!
 * Convenience constructor for an FBSession.
 * @param key Your API key, provided by Facebook.
 * @param secret Your application secret, provided by Facebook.
 * @param delegate An object that will receive delegate method calls when
 * certain events happen in the session. See FBSessionDelegate.
 */
+ (FBSession *)sessionWithAPIKey:(NSString *)key
                          secret:(NSString *)secret
                        delegate:(id)obj;

/*!
 * @result true if the active session has been saved
 */
- (BOOL)usingSavedSession;

/*!
 * If a user defaults key has been set with this method, two things will change:
 * - Before attempting a fresh login, the FBSession will check user defaults
 *   under this key for a non-expiring login session, and if one exists, will
 *   use it instead of logging in from scratch.
 * - In the event of a successful login, if the user has selected "keep me
 *   logged in", the FBSession will store the login session in user defaults
 *   under this key, for future use.
 * @param key The user defaults key to use.
 */
- (void)setPersistentSessionUserDefaultsKey:(NSString *)key;

/*!
 * Clears the login session information stored under the key set using
 * -setPersistentSessionUserDefaultsKey:.
 */
- (void)clearStoredPersistentSession;

/*!
 * Causes the session to start the login process. This method is asynchronous;
 * i.e. it returns immediately, and the session is not necessarily logged in
 * when this method returns. The receiver's delegate will receive a
 * -sessionCompletedLogin: or -session:failedLogin: message when the process
 * completes. See FBSessionDelegate.
 *
 * Note that in the process of logging in, FBSession may cause a window to
 * appear onscreen, displaying a Facebook webpage where the user must enter
 * their login credentials.
 *
 * @result Whether the request was sent. Returns NO if this session already has
 * a request in flight.
 */
- (void)startLogin;

/*!
 * Logs out the current session. If a user defaults key for storing persistent
 * sessions has been set, this method clears the stored session, if any.
 *
 * @result Whether the request was sent. Returns NO if this session already has
 * a request in flight.
 */
- (void)logout;

/*!
 * Sends an API request with a particular method.
 */
- (void)callMethod:(NSString *)method
     withArguments:(NSDictionary *)dict
            target:(id)target
          selector:(SEL)selector
             error:(SEL)error;

/*!
 * Sends an FQL query within the session. See the Facebook Developer Wiki for
 * information about FQL. This method is asynchronous; the receiver's delegate
 * will receive a -session:receivedResponse: message when the process completes.
 * See FBSessionDelegate.
 */
- (void)sendFQLQuery:(NSString *)query
              target:(id)target
            selector:(SEL)selector
               error:(SEL)error;

/*!
 * Sends an FQL.multiquery request. See the Facebook Developer Wiki for
 * information about FQL. This method is asynchronous; the receiver's delegate
 * will receive a -session:receivedResponse: message when the process completes.
 * See FBSessionDelegate.
 *
 * @param queries A dictionary mapping strings (query names) to strings
 * (FQL query strings).
 */
- (void)sendFQLMultiquery:(NSDictionary *)queries
                   target:(id)target
                 selector:(SEL)selector
                    error:(SEL)error;

/*!
 * Returns whether the session currently has a session key. Note that the
 * session key may have expired, in which case any operation requiring a
 * session key will fail, and a new one will have to be obtained by calling
 * -startLogin again.
 */
- (BOOL)hasSessionKey;

/*!
 * Returns the logged-in user's uid as a string. If the session has not been
 * logged in, returns nil. Note that this may return a non-nil value despite
 * the session key being expired.
 */
- (NSString *)uid;

- (void)refreshSession;

@end
