//
//  DBScorer.m
//  Zxcvbn
//
//  Created by Leah Culver on 2/9/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//
//  Modified by Mento on 8.5.2018
//  Copyright © 2018 Mento. All rights reserved.
//

#import "DBScorer.h"

#import "DBMatcher.h"

@implementation DBScorer

- (DBResult *)minimumEntropyMatchSequence:(NSString *)password matches:(NSArray *)matches
{
    /* minimum entropy search
     
     takes a list of overlapping matches, returns the non-overlapping sublist with
     minimum entropy. O(nm) dp alg for length-n password with m candidate matches.
     */
    
    double bruteforceCardinality = [self calcBruteforceCardinality:password]; // e.g. 26 for lowercase
    
    NSMutableArray *upToK = [[NSMutableArray alloc] init]; // minimum entropy up to k.
    NSMutableArray *backpointers = [[NSMutableArray alloc] init]; // for the optimal sequence of matches up to k, holds the final match (match.j == k). null means the sequence ends w/ a brute-force character.
    
    for (int k = 0; k < [password length]; k++) {
        // starting scenario to try and beat: adding a brute-force character to the minimum entropy sequence at k-1.
		[upToK insertObject:[NSNumber numberWithDouble:[get(upToK, k-1) doubleValue] + log2(bruteforceCardinality)] atIndex:k];
        [backpointers insertObject:[NSNull null] atIndex:k];
        for (DBMatch *match in matches) {
            NSUInteger i = match.i;
            NSUInteger j = match.j;
            if (j != k) {
                continue;
            }
            // see if best entropy up to i-1 + entropy of this match is less than the current minimum at j.
            double candidateEntropy = [get(upToK, (int)i-1) doubleValue] + [self calcEntropy:match];
            if (candidateEntropy < [[upToK objectAtIndex:j] doubleValue]) {
                [upToK insertObject:[NSNumber numberWithDouble:candidateEntropy] atIndex:j];
                [backpointers insertObject:match atIndex:j];
            }
        }
    }

    // walk backwards and decode the best sequence
    NSMutableArray *matchSequence = [[NSMutableArray alloc] init];
    NSInteger k = [password length] - 1;
    while (k >= 0) {
        DBMatch *match = [backpointers objectAtIndex:k];
        if (![match isEqual:[NSNull null]]) {
            [matchSequence addObject:match];
            k = match.i - 1;
        } else {
            k -= 1;
        }
    }
    matchSequence = [[NSMutableArray alloc] initWithArray:[[matchSequence reverseObjectEnumerator] allObjects]];

    // fill in the blanks between pattern matches with bruteforce "matches"
    // that way the match sequence fully covers the password: match1.j == match2.i - 1 for every adjacent match1, match2.
    DBMatch* (^makeBruteforceMatch)(NSUInteger i, NSUInteger j) = ^ DBMatch* (NSUInteger i, NSUInteger j) {
        DBMatch *match = [[DBMatch alloc] init];
        match.pattern = @"bruteforce";
        match.i = i;
        match.j = j;
        match.token = [password substringWithRange:NSMakeRange(i, j - i + 1)];
        match.entropy = log2(pow(bruteforceCardinality, j - i + 1));
        match.cardinality = bruteforceCardinality;
        return match;
    };
    k = 0;
    NSMutableArray *matchSequenceCopy = [[NSMutableArray alloc] init];
    for (DBMatch *match in matchSequence) {
        NSUInteger i = match.i;
        NSUInteger j = match.j;
        if (i - k > 0) {
            [matchSequenceCopy addObject:makeBruteforceMatch(k, i-1)];
        }
        k = j + 1;
        [matchSequenceCopy addObject:match];
    }
    if (k < [password length]) {
        [matchSequenceCopy addObject:makeBruteforceMatch(k, [password length] - 1)];
        matchSequence = matchSequenceCopy;
    }

    double minEntropy = 0.0;
    if ([password length] > 0) { // corner case is for an empty password ''
        minEntropy = [[upToK objectAtIndex:[password length] - 1] doubleValue];
    }
    double crackTime = [self entropyToCrackTime:minEntropy];

    // final result object
    DBResult *result = [[DBResult alloc] init];
    result.password = password;
    result.entropy = minEntropy;
    result.matchSequence = matchSequence;
    result.crackTime = crackTime;
    result.crackTimeDisplay = [self displayTime:crackTime];
    return result;
}

- (double)entropyToCrackTime:(double)entropy
{
	/*
	 * threat model -- encrypted secret key stolen
	 *
	 * assumes:
	 *   attacker has stolen the whole secring.
	 *   attacker uses some Amazon EC2 P3-Instances.
	 */
	
	
	/*
	 * Guesses a Tesla c2070 GPU can made der second.
	 * Source: "A fast, GPU based, dictionary attack to OpenPGP secret keyrings" DOI: 10.1016/j.jss.2011.05.027
	 */
	double guessesPerSec_c2070 = 450000;
	
	/*
	 * The S2K Count used in the paper above.
	 */
	double paperS2KCount = 1024;
	
	/*
	 * By default GnuPG sets the S2K count to a value which requires about 100ms of time on the machine, running GnuPG.
	 * With a not brand new CPU, the S2K count is something like 15000000 to 20000000.
	 */
	double currentS2KCount = 15000000;

	/*
	 * The factor a Tesla V100 is faster than a c2070. 15.7 vs. 1.03 TeraFLOPS.
	 */
	double speedFactor_V100 = 15;
	
	/*
	 * Number of GPUs guessing in parallel.
	 */
	double numberGPUs = 500;
	
	/*
	 * Technical development or so.
	 */
	double safetyMargin = 10;

	/*
	 * The number of guesses the attacker can make per second.
	 */
	double guessesPerSec = guessesPerSec_c2070 * speedFactor_V100 * numberGPUs * safetyMargin * paperS2KCount / currentS2KCount;
	
	
	if (entropy > 1000) {
		// Prevent possiblePasswords from getting +inf.
		entropy = 1000;
	}
	
	/*
	 * Number of passwords the attacker has to try.
	 */
	double possiblePasswords = pow(2, entropy);
	
	
	/*
	 * Average time in seconds an attackers need to find the password.
	 * The attacker finds the password after trying only the half of the passwords.
	 */
	double time = possiblePasswords / guessesPerSec / 2;
	
	return time;
}


#pragma mark - entropy calcs -- one function per match pattern

- (double)calcEntropy:(DBMatch *)match
{
    if (match.entropy > 0) {
        // a match's entropy doesn't change. cache it.
        return match.entropy;
    }

    if ([match.pattern isEqualToString:@"repeat"]) {
        match.entropy = [self repeatEntropy:match];
    } else if ([match.pattern isEqualToString:@"sequence"]) {
        match.entropy = [self sequenceEntropy:match];
    } else if ([match.pattern isEqualToString:@"digits"]) {
        match.entropy = [self digitsEntropy:match];
    } else if ([match.pattern isEqualToString:@"year"]) {
        match.entropy = [self yearEntropy:match];
    } else if ([match.pattern isEqualToString:@"date"]) {
        match.entropy = [self dateEntropy:match];
    } else if ([match.pattern isEqualToString:@"spatial"]) {
        match.entropy = [self spatialEntropy:match];
    } else if ([match.pattern isEqualToString:@"dictionary"]) {
        match.entropy = [self dictionaryEntropy:match];
    }

    return match.entropy;
}

- (double)repeatEntropy:(DBMatch *)match
{
    double cardinality = [self calcBruteforceCardinality:match.token];
    return log2(cardinality * [match.token length]);
}

- (double)sequenceEntropy:(DBMatch *)match
{
    NSString *firstChr = [match.token substringToIndex:1];
    double baseEntropy = 0;
    if ([@[@"a", @"1"] containsObject:firstChr]) {
        baseEntropy = 1;
    } else {
        unichar chr = [firstChr characterAtIndex:0];
        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:chr]) {
            baseEntropy = log2(10); // digits
        } else if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:chr]) {
            baseEntropy = log2(26); // lower
        } else {
            baseEntropy = log2(26) + 1; // extra bit for uppercase
        }
    }
    if (!match.ascending) {
        baseEntropy += 1; // extra bit for descending instead of ascending
    }
    return baseEntropy + log2([match.token length]);
}

- (double)digitsEntropy:(DBMatch *)match
{
    return log2(pow(10, [match.token length]));
}

static int kNumYears = 119; // years match against 1900 - 2019
static int kNumMonths = 12;
static int kNumDays = 31;

- (double)yearEntropy:(DBMatch *)match
{
    return log2(kNumYears);
}

- (double)dateEntropy:(DBMatch *)match
{
    double entropy = 0.0;
    if (match.year < 100) {
        entropy = log2(kNumDays * kNumMonths * 100); // two-digit year
    } else {
        entropy = log2(kNumDays * kNumMonths * kNumYears); // four-digit year
    }
    if ([match.separator length]) {
        entropy += 2; // add two bits for separator selection [/,-,.,etc]
    }
    return entropy;
}

- (double)spatialEntropy:(DBMatch *)match
{
    DBMatcher *matcher = [[DBMatcher alloc] init];
    NSUInteger s;
    NSUInteger d;
    if ([@[@"qwerty", @"dvorak"] containsObject:match.graph]) {
        s = matcher.keyboardStartingPositions;
        d = matcher.keyboardAverageDegree;
    } else {
        s = matcher.keypadStartingPositions;
        d = matcher.keypadAverageDegree;
    }
    int possibilities = 0;
    NSUInteger L = [match.token length];
    int t = match.turns;
    // estimate the number of possible patterns w/ length L or less with t turns or less.
    for (int i = 2; i <= L; i++) {
        int possibleTurns = MIN(t, i - 1);
        for (int j = 1; j <= possibleTurns; j++) {
            possibilities += binom(i - 1, j - 1) * s * pow(d, j);
        }
    }
    double entropy = log2(possibilities);
    // add extra entropy for shifted keys. (% instead of 5, A instead of a.)
    // math is similar to extra entropy from uppercase letters in dictionary matches.
    if (match.shiftedCount) {
        int S = match.shiftedCount;
        NSUInteger U = [match.token length] - match.shiftedCount; // unshifted count
        NSUInteger possibilities = 0;
        for (int i = 0; i <= MIN(S, U); i++) {
            possibilities += binom(S + U, i);
        }
        entropy += log2(possibilities);
    }
    return entropy;
}

- (double)dictionaryEntropy:(DBMatch *)match
{
    match.baseEntropy = log2(match.rank); // keep these as properties for display purposes
    match.upperCaseEntropy = [self extraUppercaseEntropy:match];
    return match.baseEntropy + match.upperCaseEntropy + match.l33tEntropy;
}

- (double)extraUppercaseEntropy:(DBMatch *)match
{
    NSString *word = match.token;
    if ([word rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location == NSNotFound) {
        return 0; // all lower
    }

    // a capitalized word is the most common capitalization scheme,
    // so it only doubles the search space (uncapitalized + capitalized): 1 extra bit of entropy.
    // allcaps and end-capitalized are common enough too, underestimate as 1 extra bit to be safe.
    NSString *startUpper = @"^[A-Z][^A-Z]+$";
    NSString *endUpper = @"^[^A-Z]+[A-Z]$";
    NSString *allUpper = @"^[A-Z]+$";
    for (NSString *regex in @[startUpper, endUpper, allUpper]) {
        if ([[NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex] evaluateWithObject:word]) {
            return 1;
        }
    }

    // otherwise calculate the number of ways to capitalize U+L uppercase+lowercase letters with U uppercase letters or less.
    // or, if there's more uppercase than lower (for e.g. PASSwORD), the number of ways to lowercase U+L letters with L lowercase letters or less.
    int uppercaseLength = 0;
    int lowercaseLength = 0;
    for (int i = 0; i < [word length]; i++) {
        unichar chr = [word characterAtIndex:i];
        if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:chr]) {
            uppercaseLength++;
        } else if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:chr]) {
            lowercaseLength++;
        }
    }

    double possibilities = 0.0;
    for (int i = 0; i <= MIN(uppercaseLength, lowercaseLength); i++) {
        possibilities += binom(uppercaseLength + lowercaseLength, i);
    }
    return log2(possibilities);
}

#pragma mark - utilities

- (double)calcBruteforceCardinality:(NSString *)password
{
    int digits = 0;
    int upper = 0;
    int lower = 0;
    int symbols = 0;
	
	NSUInteger unicode = 0;
	NSMutableIndexSet *usedUnicodeBlocks = nil;

    for (int i = 0; i < [password length]; i++) {
        unichar chr = [password characterAtIndex:i];

        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:chr]) {
            digits = 10;
        } else if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:chr]) {
            upper = 26;
		} else if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:chr]) {
			lower = 26;
		} else if (chr < 128) {
			symbols = 33;
        } else if (chr >= 128) { // A non ASCII character.
			// Split the 16-bit unichar sapce into 1024 blocks of 64 chars.
			// Every used block increases the entropy by 64.
			if (!usedUnicodeBlocks) {
				usedUnicodeBlocks = [[NSMutableIndexSet alloc] init];
			}
			NSUInteger block = chr / 1024;
			[usedUnicodeBlocks addIndex:block];
        }
	}

	if (usedUnicodeBlocks) {
		unicode = usedUnicodeBlocks.count * 64;
	}
	
	
	return digits + upper + lower + symbols + unicode;
}

- (NSString *)displayTime:(double)seconds
{
    NSUInteger minute = 60;
    NSUInteger hour = minute * 60;
    NSUInteger day = hour * 24;
    NSUInteger month = day * 31;
    NSUInteger year = month * 12;
    NSUInteger millennium = year * 1000;
	
	NSString *result;
	
	if (seconds < 2) {
		result = @"instant";
	} else if (seconds < minute * 2) {
		result = [NSString stringWithFormat:@"%d seconds", (int)seconds];
	} else if (seconds < hour * 2) {
		result = [NSString stringWithFormat:@"%d minutes", (int)(seconds / minute)];
	} else if (seconds < day * 2) {
		result = [NSString stringWithFormat:@"%d hours", (int)(seconds / hour)];
	} else if (seconds < month * 2) {
		result = [NSString stringWithFormat:@"%d days", (int)(seconds / day)];
	} else if (seconds < year * 2) {
		result = [NSString stringWithFormat:@"%d months", (int)(seconds / month)];
	} else if (seconds < millennium * 2) {
		result = [NSString stringWithFormat:@"%d years", (int)(seconds / year)];
	} else {
		result = @"thousands of years";
	}
	
	return result;
}

#pragma mark - functions

double binom(NSUInteger n, NSUInteger k)
{
    // Returns binomial coefficient (n choose k).
    // http://blog.plover.com/math/choose.html
    if (k > n) { return 0; }
    if (k == 0) { return 1; }
    double result = 1;
    for (int denom = 1; denom <= k; denom++) {
        result *= n;
        result /= denom;
        n -= 1;
    }
    return result;
}

NSString* roundToXDigits(double number, int digits)
{
    //return round(number * pow(10, digits)) / pow(10, digits);
    return [NSString stringWithFormat:@"%.*f", digits, number];
}

id get(NSArray *a, int i)
{
    if (i < 0 || i >= [a count]) {
        return 0;
    }
    return [a objectAtIndex:i];
}

@end


@implementation DBResult

@end
