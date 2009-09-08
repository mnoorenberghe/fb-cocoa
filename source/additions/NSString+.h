//
//  NSString+.h
//  FBCocoa
//
//  Created by Owen Yamauchi on 7/22/09.
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (Additions)

+ (BOOL)exists:(NSString *)string;

+ (NSString *)urlEncodeArguments:(NSDictionary *)dict;

- (NSString *)urlEncode;

- (NSString *)hexMD5;

- (BOOL)containsString:(NSString *)string;

@end
