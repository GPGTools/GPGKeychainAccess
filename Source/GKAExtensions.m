#import "GKAExtensions.h"
#import "Globales.h"
#import <sys/time.h>
#import <objc/runtime.h>

@implementation NSDate (GKA_Extension)
- (NSInteger)daysSinceNow {
	return ([self timeIntervalSinceNow] + 86399) / 86400;
}
@end

@implementation NSString (GKA_Extension)
- (NSSet *)keyIDs {
	NSArray *substrings = [self componentsSeparatedByString:@" "];
	NSMutableSet *keyIDs = [NSMutableSet setWithCapacity:[substrings count]];
	BOOL found = NO;
	
	NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
	NSInteger stringLength;
	NSString *stringToCheck;
	
	for (NSString *substring in substrings) {
		stringLength = [substring length];
		stringToCheck = nil;
		switch (stringLength) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = substring;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([substring hasPrefix:@"0"]) {
					stringToCheck = [substring substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([substring hasPrefix:@"0x"]) {
					stringToCheck = [substring substringFromIndex:2];
				}
				break;
		}
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:noHexCharSet].length == 0) {
			[keyIDs addObject:stringToCheck];
			found = YES;
		}
	}
	
	return found ? keyIDs : nil;
}
- (NSString *)shortKeyID {
	return [self substringFromIndex:[self length] - 8];
}
- (NSUInteger)lines {
	NSUInteger numberOfLines, index, length = self.length;
	if (length == 0) {
		return 0;
	}
	for (index = 0, numberOfLines = 0; index < length; numberOfLines++) {
		index = NSMaxRange([self lineRangeForRange:NSMakeRange(index, 0)]);
	}
	if ([self characterAtIndex:length - 1] == '\n') {
		numberOfLines++;
	}
	return numberOfLines;
}

@end

@implementation NSNumber (GKA_Extension)
- (NSComparisonResult)compareValidity:(NSNumber *)otherNumber {
	NSInteger valueA = self.integerValue;
	NSInteger valueB = otherNumber.integerValue;
	
	if (valueA >= GPGValidityInvalid) {
		valueA = 0 - valueA;
	}
	if (valueB >= GPGValidityInvalid) {
		valueB = 0 - valueB;
	}
	
	if (valueA > valueB) {
		return NSOrderedDescending;
	} else if (valueB > valueA) {
		return NSOrderedAscending;
	} else {
		return NSOrderedSame;
	}
}
@end



@implementation GPGKey (GKAExtension)
- (NSString *)type {
	if (self.primaryKey == self) {
		return self.secret ? @"sec/pub" : @"pub";
	} else {
		return self.secret ? @"ssb" : @"sub";
	}
}
- (NSString *)longType {
	if (self.primaryKey == self) {
		return self.secret ? localized(@"Secret and public key") : localized(@"Public key");
	} else {
		return nil;
	}
}
- (NSString *)capabilities {
	
	NSString *e = @"", *s = @"", *c = @"", *a = @"";
	if (self.canEncrypt) {
		e = @"e";
	} else if (self.canAnyEncrypt) {
		e = @"E";
	}
	if (self.canSign) {
		s = @"s";
	} else if (self.canAnySign) {
		s = @"S";
	}
	if (self.canCertify) {
		c = @"c";
	} else if (self.canAnyCertify) {
		c = @"C";
	}
	if (self.canAuthenticate) {
		a = @"a";
	} else if (self.canAnyAuthenticate) {
		a = @"A";
	}
	
	return [NSString stringWithFormat:@"%@%@%@%@", e, s, c, a];
}
- (id)children {
	return nil;
}
- (NSArray *)photos {
	NSArray *photoIDs = [self.userIDs objectsAtIndexes:[self.userIDs indexesOfObjectsPassingTest:^BOOL(GPGUserID *uid, NSUInteger idx, BOOL *stop) {
		return uid.isUat;
	}]];
	
	
	return photoIDs;
}
- (void)setDisabled:(BOOL)value {
}

- (NSString *)userIDAndKeyID {
	return [NSString stringWithFormat:@"%@ (%@)", self.userIDDescription, self.keyID.shortKeyID];
}

- (BOOL)detailsLoaded {
	return !!self.primaryUserID.signatures;
}

- (NSString *)simpleValidity {
	NSInteger intValue = self.validity;
	NSString *validity = nil;
	
	
	if (intValue >= GPGValidityInvalid) {
		if (intValue & GPGValidityInvalid) {
			validity = localized(@"Invalid");
		}
		else if (intValue & GPGValidityRevoked) {
			validity = localized(@"Revoked");
		}
		else if (intValue & GPGValidityExpired) {
			validity = localized(@"Expired");
		}
		else if (intValue & GPGValidityDisabled) {
			validity = localized(@"Disabled");
		}
	} else {
		switch (intValue) {
			case 2:
				validity = localized(@"?"); //Was bedeutet 2?
				break;
			case 3:
				validity = localized(@"Marginal");
				break;
			case 4:
				validity = localized(@"Full");
				break;
			case 5:
				validity = localized(@"Ultimate");
				break;
			default:
				validity = localized(@"Unknown");
				break;
		}
	}
	
	if (!validity) {
		validity = localized(@"Unknown");
	}
	
	return validity;
}

- (BOOL)hasPassphrase {
	//This method isn't perfect yet!
	if (!_secret) {
		return NO;
	}
	
	NSNumber *storedValue = objc_getAssociatedObject(self, @"hasPassphrase");
	if (storedValue) {
		return storedValue.boolValue;
	}
	
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(queue, ^{
		GPGTask *gpgTask = [GPGTask gpgTask];
		gpgTask.batchMode = YES;
		[gpgTask addArguments:@[@"--passphrase", @"", @"--passwd", self.fingerprint]];
		
		[gpgTask start];
		
		BOOL value = !![gpgTask.statusDict objectForKey:@"BAD_PASSPHRASE"];
		
		objc_setAssociatedObject(self, @"hasPassphrase", @(value), 0);
		if (value) {
			[self willChangeValueForKey:@"hasPassphrase"];
			[self didChangeValueForKey:@"hasPassphrase"];
		}
	});
	
	return NO;
}

- (void)setIvar:(id)key value:(id)value {
    objc_setAssociatedObject(self, (__bridge const void *)(key), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)getIvar:(id)key {
    return objc_getAssociatedObject(self, (__bridge const void *)(key));
}
- (NSString *)textForFilter {
	dispatch_semaphore_wait(_textForFilterOnce, DISPATCH_TIME_FOREVER);
	if(!_textForFilter) {
		NSMutableString *textForFilter = [[NSMutableString alloc] init];
		for(GPGKey *key in [self.subkeys arrayByAddingObject:self]) {
			[textForFilter appendFormat:@"0x%@\n0x%@\n0x%@\n", key.fingerprint, key.keyID, [key.keyID shortKeyID]];
		}
		for(GPGUserID *userID in self.userIDs)
			[textForFilter appendFormat:@"%@\n", userID.fullUserIDDescription];
		_textForFilter = [textForFilter copy];
	}
	dispatch_semaphore_signal(_textForFilterOnce);
	
	return _textForFilter;
}



@end

@implementation GPGUserID (GKAExtension)
- (NSInteger)status {
	return 0;
}
- (NSString *)type {
	return _name ? @"uid" : @"uat";
}
- (id)shortKeyID {
	return nil;
}
- (id)length {
	return nil;
}
- (id)algorithm {
	return nil;
}
- (id)children {
	return nil;
}
- (NSString *)userIDDescription {
	if (_userIDDescription) {
		if (_email.length > 0) {
			return [NSString stringWithFormat:@"%@ <%@>", _name, _email];
		} else {
			return _name;
		}
	} else {
		return localized(@"PhotoID");
	}
}
- (NSString *)fullUserIDDescription {
	if (_userIDDescription) {
		return _userIDDescription;
	} else {
		return localized(@"PhotoID");
	}
}
- (NSString *)name {
	if (_name) {
		return _name;
	} else {
		return localized(@"PhotoID");
	}
}
- (BOOL)isUat {
	return !_name;
}

@end

@implementation GPGUserIDSignature (GKAExtension)
- (NSString *)type {
	NSString *classString = (self.signatureClass & 3) ? [NSString stringWithFormat:@" %i", (self.signatureClass & 3)] : @"";
	NSString *typeString = self.revocation ? @"rev" : @"sig";
	NSString *localString = self.local ? @" L" : @"";
	
	return [NSString stringWithFormat:@"%@%@%@", typeString, classString, localString];
}
@end


