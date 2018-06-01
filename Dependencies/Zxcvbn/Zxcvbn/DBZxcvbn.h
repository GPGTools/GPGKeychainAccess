//
//  DBZxcvbn.h
//  Zxcvbn
//
//  Created by Leah Culver on 2/9/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBMatcher.h"
#import "DBScorer.h"

@interface DBZxcvbn : NSObject

- (DBResult *)passwordStrength:(NSString *)password;
- (DBResult *)passwordStrength:(NSString *)password userInputs:(NSArray *)userInputs;

@end
