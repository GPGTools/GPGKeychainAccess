//
//  DBMatcher.m
//  Zxcvbn
//
//  Created by Leah Culver on 2/9/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//
//  Modified by Mento on 8.5.2018
//  Copyright © 2018 Mento. All rights reserved.
//

#import "DBMatcher.h"

typedef NSArray* (^MatcherBlock)(NSString *password);

@interface DBMatcher ()

@property (nonatomic, strong) NSArray *dictionaryMatchers;
@property (nonatomic, strong) NSDictionary *graphs;
@property (nonatomic, strong) NSMutableArray *matchers;

@end

@implementation DBMatcher

- (id)init
{
    self = [super init];

    if (self != nil) {
        DBMatchResources *resource = [DBMatchResources sharedDBMatcherResources];
        self.dictionaryMatchers = resource.dictionaryMatchers;
        self.graphs = resource.graphs;

        self.keyboardAverageDegree = [self calcAverageDegree:[self.graphs objectForKey:@"qwerty"]];
        self.keypadAverageDegree = [self calcAverageDegree:[self.graphs objectForKey:@"keypad"]]; // slightly different for keypad/mac keypad, but close enough

        self.keyboardStartingPositions = [[self.graphs objectForKey:@"qwerty"] count];
        self.keypadStartingPositions = [[self.graphs objectForKey:@"keypad"] count];

        self.matchers = [[NSMutableArray alloc] initWithArray:self.dictionaryMatchers];
        [self.matchers addObjectsFromArray:@[[self l33tMatch],
                                             [self digitsMatch], [self yearMatch], [self dateMatch],
                                             [self repeatMatch], [self sequenceMatch],
                                             [self spatialMatch]]];
    }

    return self;
}

#pragma mark - omnimatch -- combine everything

- (NSArray *)omnimatch:(NSString *)password userInputs:(NSArray *)userInputs
{
    if ([userInputs count]) {
        NSMutableDictionary *rankedUserInputsDict = [[NSMutableDictionary alloc] initWithCapacity:[userInputs count]];
        for (int i = 0; i < [userInputs count]; i++) {
            [rankedUserInputsDict setObject:[NSNumber numberWithInt:i + 1] forKey:[userInputs[i] lowercaseString]];
        }
        [self.matchers addObject:[self buildDictMatcher:@"user_inputs" rankedDict:rankedUserInputsDict]];
    }
    
    NSMutableArray *matches = [[NSMutableArray alloc] init];

    for (MatcherBlock matcher in self.matchers) {
        [matches addObjectsFromArray:matcher(password)];
    }

    return [matches sortedArrayUsingDescriptors: @[[[NSSortDescriptor alloc] initWithKey:@"i" ascending:YES],
                                                   [[NSSortDescriptor alloc] initWithKey:@"j" ascending:NO]]];
}

#pragma mark - dictionary match (common passwords, english, last names, etc)

- (NSMutableArray *)dictionaryMatch:(NSString *)password rankedDict:(NSMutableDictionary *)rankedDict
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSUInteger length = [password length];
    NSString *passwordLower = [password lowercaseString];

    for (int i = 0; i < length; i++) {
        for (int j = i; j < length; j++) {
            NSString *word = [passwordLower substringWithRange:NSMakeRange(i, j - i + 1)];
            NSNumber *rank = [rankedDict objectForKey:word];

            if (rank != nil) {
                DBMatch *match = [[DBMatch alloc] init];
                match.pattern = @"dictionary";
                match.i = i;
                match.j = j;
                match.token = [password substringWithRange:NSMakeRange(i, j - i + 1)];
                match.matchedWord = word;
                match.rank = [rank intValue];
                [result addObject:match];
            }
        }
    }

    return result;
}

- (MatcherBlock)buildDictMatcher:(NSString *)dictName rankedDict:(NSMutableDictionary *)rankedDict
{
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {

        NSMutableArray *matches = [weakSelf dictionaryMatch:password rankedDict:rankedDict];
        
        for (DBMatch *match in matches) {
            match.dictionaryName = dictName;
        }

        return matches;
    };

    return block;
}

- (float)calcAverageDegree:(NSDictionary *)graph
{
    // on qwerty, 'g' has degree 6, being adjacent to 'ftyhbv'. '\' has degree 1.
    // this calculates the average over all keys.
    float average = 0.0;
    for (NSString *key in [graph allKeys]) {
        NSMutableArray *neighbors = [[NSMutableArray alloc] init];
        for (NSString *n in (NSArray *)[graph objectForKey:key]) {
            if (n != (id)[NSNull null]) {
                [neighbors addObject:n];
            }
        }
        average += [neighbors count];
    }
    average /= [graph count];
    return average;
}

#pragma mark - dictionary match with common l33t substitutions

- (NSDictionary *)l33tTable
{
    return @{
             @"a": @[@"4", @"@"],
             @"b": @[@"8"],
             @"c": @[@"(", @"{", @"[", @"<"],
             @"e": @[@"3"],
             @"g": @[@"6", @"9"],
             @"i": @[@"1", @"!", @"|"],
             @"l": @[@"1", @"|", @"7"],
             @"o": @[@"0"],
             @"s": @[@"$", @"5"],
             @"t": @[@"+", @"7"],
             @"x": @[@"%"],
             @"z": @[@"2"],
             };
}

- (NSDictionary *)relevantL33tSubtable:(NSString *)password
{
    // makes a pruned copy of l33t_table that only includes password's possible substitutions
    NSMutableDictionary *filtered = [[NSMutableDictionary alloc] init];

    for (NSString *letter in [self l33tTable]) {
        NSArray *subs = [[self l33tTable] objectForKey:letter];
        NSMutableArray *relevantSubs = [[NSMutableArray alloc] initWithCapacity:[subs count]];
        for (NSString *sub in subs) {
            if ([password rangeOfString:sub].location != NSNotFound) {
                [relevantSubs addObject:sub];
            }
        }
        if ([relevantSubs count] > 0) {
            [filtered setObject:relevantSubs forKey:letter];
        }
    }

    return filtered;
}

- (NSArray *)enumerateL33tSubs:(NSDictionary *)table
{
    // returns the list of possible 1337 replacement dictionaries for a given password
    NSMutableArray *subs = [[NSMutableArray alloc] initWithObjects:[[NSMutableArray alloc] init], nil];

    NSMutableArray* (^dedup)(NSArray *) = ^ NSMutableArray* (NSArray *subs) {
        NSMutableArray *deduped = [[NSMutableArray alloc] init];
        NSMutableArray *members = [[NSMutableArray alloc] init];
        for (NSArray *sub in subs) {
            NSArray *assoc = [sub sortedArrayUsingComparator:^NSComparisonResult(NSArray *kv1, NSArray *kv2) {
                return [kv1[0] caseInsensitiveCompare:kv2[0]];
            }];
            NSMutableArray *kvs = [[NSMutableArray alloc] initWithCapacity:[assoc count]];
            for (NSArray *kv in assoc) {
                [kvs addObject:[kv componentsJoinedByString:@","]];
            }
            NSString *label = [kvs componentsJoinedByString:@"-"];
            if (![members containsObject:label]) {
                [members addObject:label];
                [deduped addObject:sub];
            }
        }
        return deduped;
    };

    NSArray *keys = [table allKeys];

    while ([keys count] > 0) {
        NSString *firstKey = [keys objectAtIndex:0];
        NSArray *restKeys = [keys count] > 1 ? [keys subarrayWithRange:NSMakeRange(1, [keys count] - 1)] : @[];
        NSMutableArray *nextSubs = [[NSMutableArray alloc] init];

        for (NSString *l33tChr in (NSArray *)[table objectForKey:firstKey]) {
            for (NSMutableArray *sub in subs) {

                int dupL33tIndex = -1;
                for (int i = 0; i < [sub count]; i++) {
                    if ([[[sub objectAtIndex:i] objectAtIndex:0] isEqualToString:l33tChr]) {
                        dupL33tIndex = i;
                        break;
                    }
                }

                if (dupL33tIndex == -1) {
                    NSMutableArray *subExtension = [[NSMutableArray alloc] initWithArray:sub];
                    [subExtension addObject:@[l33tChr, firstKey]];
                    [nextSubs addObject:subExtension];
                } else {
                    NSMutableArray *subAlternative = [[NSMutableArray alloc] initWithArray:sub];
                    [subAlternative removeObjectAtIndex:dupL33tIndex];
                    [subAlternative addObject:@[l33tChr, firstKey]];
                    [nextSubs addObject:sub];
                    [nextSubs addObject:subAlternative];
                }
            }
        }

        subs = dedup(nextSubs);
        keys = restKeys;
    }

    NSMutableArray *subDicts = [[NSMutableArray alloc] init]; // convert from assoc lists to dicts
    for (NSMutableArray *sub in subs) {
        NSMutableDictionary *subDict = [[NSMutableDictionary alloc] initWithCapacity:[sub count]];
        for (NSArray *pair in sub) {
            [subDict setObject:[pair objectAtIndex:1] forKey:[pair objectAtIndex:0]];
        }
        [subDicts addObject:subDict];
    }
    return subDicts;
}

- (MatcherBlock)l33tMatch
{
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {

        NSMutableArray *matches = [[NSMutableArray alloc] init];

        for (NSDictionary *sub in [weakSelf enumerateL33tSubs:[weakSelf relevantL33tSubtable:password]]) {
            if ([sub count] == 0) { break; } // corner case: password has no relevent subs.

            NSString *subbedPassword = [weakSelf translate:password characterMap:sub];

            for (MatcherBlock matcher in weakSelf.dictionaryMatchers) {
                for (DBMatch *match in matcher(subbedPassword)) {

                    NSString *token = [password substringWithRange:NSMakeRange(match.i, match.j - match.i + 1)];
                    if ([[token lowercaseString] isEqualToString:match.matchedWord]) {
                        continue; // only return the matches that contain an actual substitution
                    }

                    NSMutableDictionary *matchSub = [[NSMutableDictionary alloc] init]; // subset of mappings in sub that are in use for this match
                    NSMutableArray *subDisplay = [[NSMutableArray alloc] init];
                    for (NSString *subbedChr in sub) {
                        NSString *chr = [sub objectForKey:subbedChr];
                        if ([token rangeOfString:subbedChr].location != NSNotFound) {
                            [matchSub setObject:chr forKey:subbedChr];
                            [subDisplay addObject:[NSString stringWithFormat:@"%@ -> %@", subbedChr, chr]];
                        }
                    }

                    match.l33t = YES;
                    match.token = token;
                    match.sub = matchSub;
                    match.subDisplay = [subDisplay componentsJoinedByString:@","];
                    [matches addObject:match];
                }
            }
        }

        return matches;
    };

    return block;
}

#pragma mark - spatial match (qwerty/dvorak/keypad)

- (MatcherBlock)spatialMatch
{
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {
        NSMutableArray *matches = [[NSMutableArray alloc] init];

        for (NSString *graphName in weakSelf.graphs) {
            NSDictionary *graph = [weakSelf.graphs objectForKey:graphName];
            [matches addObjectsFromArray:[weakSelf spatialMatchHelper:password graph:graph graphName:graphName]];
        }

        return matches;
    };

    return block;
}

- (NSArray *)spatialMatchHelper:(NSString *)password graph:(NSDictionary *)graph graphName:(NSString *)graphName
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    int i = 0;
    while (i < [password length] - 1 && [password length] > 0) {
        int j = i + 1;
        int lastDirection = -1;
        int turns = 0;
        int shiftedCount = 0;
        while (YES) {
            NSString *prevChar = [password substringWithRange:NSMakeRange(j - 1, 1)];
            BOOL found = NO;
            int foundDirection = -1;
            int curDirection = -1;
            NSArray *adjacents = [[graph allKeys] containsObject:prevChar] ? [graph objectForKey:prevChar] : @[];
            // consider growing pattern by one character if j hasn't gone over the edge.
            if (j < [password length]) {
                NSString *curChar = [password substringWithRange:NSMakeRange(j, 1)];
                for (NSString *adj in adjacents) {
                    curDirection++;
                    if (adj != (id)[NSNull null] && [adj rangeOfString:curChar].location != NSNotFound) {
                        found = YES;
                        foundDirection = curDirection;
                        if ([adj rangeOfString:curChar].location == 1) {
                            // index 1 in the adjacency means the key is shifted, 0 means unshifted: A vs a, % vs 5, etc.
                            // for example, 'q' is adjacent to the entry '2@'. @ is shifted w/ index 1, 2 is unshifted.
                            shiftedCount++;
                        }
                        if (lastDirection != foundDirection) {
                            // adding a turn is correct even in the initial case when last_direction is null:
                            // every spatial pattern starts with a turn.
                            turns++;
                            lastDirection = foundDirection;
                        }
                        break;
                    }
                }
            }
            // if the current pattern continued, extend j and try to grow again
            if (found) {
                j ++;
            // otherwise push the pattern discovered so far, if any...
            } else {
                if (j - i > 2) { // don't consider length 1 or 2 chains.
                    DBMatch *match = [[DBMatch alloc] init];
                    match.pattern = @"spatial";
                    match.i = i;
                    match.j = j - 1;
                    match.token = [password substringWithRange:NSMakeRange(i, j - i)];
                    match.graph = graphName;
                    match.turns = turns;
                    match.shiftedCount = shiftedCount;
                    [result addObject:match];
                }
                // ...and then start a new search for the rest of the password.
                i = j;
                break;
            }
        }
    }

    return result;
}

#pragma mark - repeats (aaa) and sequences (abcdef)

- (MatcherBlock)repeatMatch
{
    MatcherBlock block = ^ NSArray* (NSString *password) {
        NSMutableArray *result = [[NSMutableArray alloc] init];
        int i = 0;
        while (i < [password length]) {
            int j = i + 1;
            while (YES) {
                NSString *prevChar = [password substringWithRange:NSMakeRange(j - 1, 1)];
                NSString *curChar = j < [password length] ? [password substringWithRange:NSMakeRange(j, 1)] : @"";
                if ([prevChar isEqualToString:curChar]) {
                    j++;
                } else {
                    if (j - i > 2) { // don't consider length 1 or 2 chains.
                        DBMatch *match = [[DBMatch alloc] init];
                        match.pattern = @"repeat";
                        match.i = i;
                        match.j = j - 1;
                        match.token = [password substringWithRange:NSMakeRange(i, j - i)];
                        match.repeatedChar = [password substringWithRange:NSMakeRange(i, 1)];
                        [result addObject:match];
                    }
                    break;
                }
            }
            i = j;
        }
        return result;
    };

    return block;
}

- (MatcherBlock)sequenceMatch
{
    NSDictionary *sequences = @{
                                @"lower": @"abcdefghijklmnopqrstuvwxyz",
                                @"upper": @"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                                @"digits": @"01234567890",
                                };

    MatcherBlock block = ^ NSArray* (NSString *password) {
        NSMutableArray *result = [[NSMutableArray alloc] init];
        int i = 0;
        while (i < [password length]) {
            int j = i + 1;
            NSString *seq = nil; // either lower, upper, or digits
            NSString *seqName = nil;
            NSUInteger seqDirection = 0; // 1 for ascending seq abcd, -1 for dcba
            for (NSString *seqCandidateName in sequences) {
                NSString *seqCandidate = [sequences objectForKey:seqCandidateName];
                NSUInteger iN = [seqCandidate rangeOfString:[password substringWithRange:NSMakeRange(i, 1)]].location;
                NSUInteger jN = j < [password length] ? [seqCandidate rangeOfString:[password substringWithRange:NSMakeRange(j, 1)]].location : NSNotFound;
                if (iN != NSNotFound && jN != NSNotFound) {
                    NSUInteger direction = jN - iN;
                    if (direction == 1 || direction == -1) {
                        seq = seqCandidate;
                        seqName = seqCandidateName;
                        seqDirection = direction;
                        break;
                    }
                }
            }
            if (seq) {
                while (YES) {
                    NSString *prevChar = [password substringWithRange:NSMakeRange(j - 1, 1)];
                    NSString *curChar = j < [password length] ? [password substringWithRange:NSMakeRange(j, 1)] : nil;
                    NSUInteger prevN = [seq rangeOfString:prevChar].location;
                    NSUInteger curN = curChar == nil ? NSNotFound : [seq rangeOfString:curChar].location;
                    if (curN - prevN == seqDirection) {
                        j++;
                    } else {
                        if (j - i > 2) { // don't consider length 1 or 2 chains.
                            DBMatch *match = [[DBMatch alloc] init];
                            match.pattern = @"sequence";
                            match.i = i;
                            match.j = j - 1;
                            match.token = [password substringWithRange:NSMakeRange(i, j - i)];
                            match.sequenceName = seqName;
                            match.sequenceSpace = (int)[seq length];
                            match.ascending = seqDirection == 1;
                            [result addObject:match];
                        }
                        break;
                    }
                }
            }
            i = j;
        }

        return result;
    };

    return block;
}

#pragma mark - digits, years, dates

- (NSArray *)findAll:(NSString *)password patternName:(NSString *)patternName rx:(NSRegularExpression *)rx
{
    NSMutableArray *matches = [[NSMutableArray alloc] init];

    for (NSTextCheckingResult *result in [rx matchesInString:password options:0 range:NSMakeRange(0, [password length])]) {
        
        DBMatch *match = [[DBMatch alloc] init];
        match.pattern = patternName;
        match.i = [result range].location;
        match.j = [result range].length + match.i - 1;
        match.token = [password substringWithRange:[result range]];
        
        if ([match.pattern isEqualToString:@"date"] && [result numberOfRanges] == 6) {
            int month;
            int day;
            int year;
            @try {
                month = [[password substringWithRange:[result rangeAtIndex:1]] intValue];
                day = [[password substringWithRange:[result rangeAtIndex:3]] intValue];
                year = [[password substringWithRange:[result rangeAtIndex:5]] intValue];
            }
            @catch (NSException *exception) {
                continue;
            }
            
            match.separator = [result rangeAtIndex:2].location < [password length] ? [password substringWithRange:[result rangeAtIndex:2]] : @"";
            
            if (month >= 12 && month <= 31 && day <= 12) { // tolerate both day-month and month-day order
                int temp = day;
                day = month;
                month = temp;
            }
            if (day > 31 || month > 12) {
                continue;
            }
            if (year < 20) {
                year += 2000; // hey, it could be 1920, but this is only for display
            } else if (year < 100) {
                year += 1900;
            }
            
            match.day = day;
            match.month = month;
            match.year = year;
        }
        
        [matches addObject:match];
    }

    return matches;
}

- (MatcherBlock)digitsMatch
{
    NSRegularExpression *digitsRx = [NSRegularExpression regularExpressionWithPattern:@"\\d{3,}" options:0 error:nil];
    
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {
        return [weakSelf findAll:password patternName:@"digits" rx:digitsRx];
    };
    
    return block;
}

- (MatcherBlock)yearMatch
{
    // 4-digit years only. 2-digit years have the same entropy as 2-digit brute force.
    NSRegularExpression *yearRx = [NSRegularExpression regularExpressionWithPattern:@"19\\d\\d|200\\d|201\\d" options:0 error:nil];
    
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {
        return [weakSelf findAll:password patternName:@"year" rx:yearRx];
    };

    return block;
}

- (MatcherBlock)dateMatch
{
    // known bug: this doesn't cover all short dates w/o separators like 111911.
    NSRegularExpression *dateRx = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,2})( |-|\\/|\\.|_)?(\\d{1,2})( |-|\\/|\\.|_)?(19\\d{2}|200\\d|201\\d|\\d{2})" options:0 error:nil];
    
    __weak typeof(self) weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {
        return [weakSelf findAll:password patternName:@"date" rx:dateRx];
    };
    
    return block;
}

#pragma mark - utilities

- (NSString *)translate:(NSString *)string characterMap:(NSDictionary *)chrMap
{
    for (NSString *key in chrMap) {
        string = [string stringByReplacingOccurrencesOfString:key withString:[chrMap objectForKey:key]];
    }
    return string;
}

@end

@implementation DBMatchResources

+ (DBMatchResources *)sharedDBMatcherResources
{
    // singleton containing adjacency graphs and frequency graphs
    static DBMatchResources *sharedMatcher = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedMatcher = [[self alloc] init];
    });
    
    return sharedMatcher;
}

- (id)init
{
    self = [super init];
    
    if (self != nil) {
        _dictionaryMatchers = [self loadFrequencyLists];
        _graphs = [self loadAdjacencyGraphs];
    }
    
    return self;
}

- (NSArray *)loadFrequencyLists
{
    NSMutableArray *dictionaryMatchers = [[NSMutableArray alloc] init];
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"frequency_lists" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    NSError *error;
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if (error == nil) {
        for (NSString *dictName in (NSDictionary *)json) {
            
            NSArray *wordList = [(NSDictionary *)json objectForKey:dictName];
            NSMutableDictionary *rankedDict = [self buildRankedDict:wordList];
            
            [dictionaryMatchers addObject:[self buildDictMatcher:dictName rankedDict:rankedDict]];
        }
    } else {
        NSLog(@"Error parsing frequency lists: %@", error);
    }
    
    return dictionaryMatchers;
}

- (NSDictionary *)loadAdjacencyGraphs
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"adjacency_graphs" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    NSError *error;
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if (error == nil) {
        return (NSDictionary *)json;
    } else {
        NSLog(@"Error parsing adjacency graphs: %@", error);
    }
    
    return nil;
}


- (NSMutableDictionary *)buildRankedDict:(NSArray *)unrankedList
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    int i = 1; // rank starts at 1, not 0
    
    for (NSString *word in unrankedList) {
        [result setObject:[NSNumber numberWithInt:i] forKey:word];
        i++;
    }
    
    return result;
}

- (MatcherBlock)buildDictMatcher:(NSString *)dictName rankedDict:(NSMutableDictionary *)rankedDict
{
    __typeof__(self) __weak weakSelf = self;
    MatcherBlock block = ^ NSArray* (NSString *password) {
        
        NSMutableArray *matches = [weakSelf dictionaryMatch:password rankedDict:rankedDict];
        
        for (DBMatch *match in matches) {
            match.dictionaryName = dictName;
        }
        
        return matches;
    };
    
    return block;
}

#pragma mark - dictionary match (common passwords, english, last names, etc)

- (NSMutableArray *)dictionaryMatch:(NSString *)password rankedDict:(NSMutableDictionary *)rankedDict
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSUInteger length = [password length];
    NSString *passwordLower = [password lowercaseString];
    
    for (int i = 0; i < length; i++) {
        for (int j = i; j < length; j++) {
            NSString *word = [passwordLower substringWithRange:NSMakeRange(i, j - i + 1)];
            NSNumber *rank = [rankedDict objectForKey:word];
            
            if (rank != nil) {
                DBMatch *match = [[DBMatch alloc] init];
                match.pattern = @"dictionary";
                match.i = i;
                match.j = j;
                match.token = [password substringWithRange:NSMakeRange(i, j - i + 1)];
                match.matchedWord = word;
                match.rank = [rank intValue];
                [result addObject:match];
            }
        }
    }
    
    return result;
}

@end


@implementation DBMatch

@end
