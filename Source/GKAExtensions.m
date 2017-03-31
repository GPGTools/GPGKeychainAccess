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
- (GPGUserID *)photoID {
	if (!self.detailsLoaded) {
		return nil;
	}
	id photoID = objc_getAssociatedObject(self, _cmd);
	if (photoID == nil) {
		__block id tempPhotoID = nil;
		[self.userIDs enumerateObjectsUsingBlock:^(GPGUserID *uid, NSUInteger idx, BOOL *stop) {
			if (uid.isUat && uid.validity < GPGValidityInvalid) {
				tempPhotoID = uid;
				*stop = YES;
			}
		}];
		photoID = tempPhotoID;
		
		if (tempPhotoID == nil) {
			tempPhotoID = [NSNull null];
		}
		objc_setAssociatedObject(self, _cmd, tempPhotoID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else if (photoID == [NSNull null]) {
		return nil;
	}
	
	return photoID;
}
- (NSImage *)photo {
	NSImage *photo = self.photoID.image;
	if (photo) {
		return photo;
	}
	
	
	NSImage *image = [NSImage imageWithSize:NSMakeSize(100, 100) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		//// Color Declarations
		NSColor *color1 = [NSColor colorWithCalibratedRed:0.551 green:0.568 blue:0.66 alpha:1];
		NSColor *color2 = [NSColor colorWithCalibratedHue:color1.hueComponent saturation:color1.saturationComponent brightness:0.4 alpha:color1.alphaComponent];
		
		//// Gradient Declarations
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:color1 endingColor:color2];
		
		//// Oval Drawing
		NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, 100, 100)];
		[gradient drawInBezierPath:circlePath angle:-90];
		
		
		if (self.name.length > 0) {
			NSMutableString *tempInitials = [NSMutableString string];
			NSString *name = self.name;
			NSRange range = [name rangeOfString:@" "];
			if (name.length > 0) {
				[tempInitials appendString:[name substringToIndex:1]];
			}
			if (range.length > 0 && name.length > range.location + 1) {
				range.location += 1;
				[tempInitials appendString:[name substringWithRange:range]];
			}
			NSString *initials = [tempInitials uppercaseString];
			
			
			//// Text Drawing
			NSRect textRect = NSMakeRect(0, 26, 100, 48);
			NSMutableParagraphStyle *textStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
			textStyle.alignment = NSCenterTextAlignment;
			
			NSDictionary *textFontAttributes = @{NSFontAttributeName:[NSFont systemFontOfSize:36], NSForegroundColorAttributeName:NSColor.whiteColor, NSParagraphStyleAttributeName:textStyle};
			
			CGFloat textTextHeight = NSHeight([initials boundingRectWithSize:textRect.size options:NSStringDrawingUsesLineFragmentOrigin attributes:textFontAttributes]);
			NSRect textTextRect = NSMakeRect(NSMinX(textRect), NSMinY(textRect) + (NSHeight(textRect) - textTextHeight) / 2, NSWidth(textRect), textTextHeight);
			[NSGraphicsContext saveGraphicsState];
			NSRectClip(textRect);
			[initials drawInRect:NSOffsetRect(textTextRect, 0, 1) withAttributes:textFontAttributes];
			[NSGraphicsContext restoreGraphicsState];
		} else {
			NSBezierPath *personPath = [NSBezierPath bezierPath];
			
			[personPath moveToPoint:NSMakePoint(56.29, 82.19)];
			
#define addCurve(v1,v2,v3,v4,v5,v6) [personPath curveToPoint:NSMakePoint(v1, v2) controlPoint1:NSMakePoint(v3, v4) controlPoint2:NSMakePoint(v5, v6)];
			addCurve(60.69, 80.45, 57.07, 81.46, 58.91, 80.73);
			addCurve(68.98, 74.6, 64.24, 79.89, 67.43, 77.64);
			addCurve(70.01, 66.6, 69.76, 73.07, 70.01, 71.13);
			addCurve(70.6, 60.24, 70.01, 63.24, 70.27, 60.45);
			addCurve(68.2, 49.26, 72.19, 59.26, 70.7, 52.43);
			addCurve(66.47, 46.03, 67.25, 48.07, 66.48, 46.62);
			addCurve(65.29, 42.41, 66.46, 45.44, 65.93, 43.82);
			addCurve(66.93, 32.06, 63.17, 37.73, 63.9, 33.1);
			addCurve(70.01, 29.07, 67.49, 31.87, 68.88, 30.52);
			addCurve(73.53, 26.09, 71.14, 27.61, 72.73, 26.27);
			addCurve(81.59, 23.17, 74.34, 25.91, 77.97, 24.59);
			addCurve(85.08, 21.82, 82.84, 22.68, 84.05, 22.21);
			addCurve(50, 5, 76.84, 11.56, 64.18, 5);
			addCurve(24.77, 12.73, 40.65, 5, 31.96, 7.85);
			addCurve(14.97, 21.76, 21.07, 15.24, 17.77, 18.29);
			addCurve(14, 23, 14.64, 22.16, 14.31, 22.58);
			addCurve(14.8, 23.17, 14.26, 23.05, 14.53, 23.11);
			addCurve(16.13, 23.45, 15.25, 23.26, 15.7, 23.36);
			addCurve(33.67, 30.04, 26.58, 25.69, 31.29, 27.47);
			addCurve(37.64, 32.99, 34.85, 31.31, 36.63, 32.64);
			addCurve(39.46, 35.79, 39.23, 33.54, 39.46, 33.9);
			addCurve(38.65, 39.11, 39.46, 36.98, 39.09, 38.47);
			addCurve(37.41, 42.91, 38.21, 39.74, 37.65, 41.46);
			addCurve(35.87, 46.61, 37.17, 44.36, 36.47, 46.03);
			addCurve(34.76, 48.24, 35.25, 47.18, 34.76, 47.92);
			addCurve(34.12, 49.6, 34.76, 48.46, 34.5, 48.99);
			addCurve(33.43, 50.62, 33.92, 49.93, 33.69, 50.28);
			addCurve(32.04, 57.8, 32.31, 52.15, 32.1, 53.2);
			addCurve(35.16, 74.48, 31.92, 66.67, 32.68, 70.73);
			addCurve(51.76, 83.44, 38.67, 79.76, 45.45, 83.43);
			addCurve(56.29, 82.19, 54.22, 83.45, 55.26, 83.16);
#undef addCurve
			
			[personPath closePath];
			[NSColor.whiteColor setFill];
			[personPath fill];
		}

		
		return YES;
	}];

	return image;
}



- (BOOL)isRefreshing {
	if (_signatures && objc_getAssociatedObject(_signatures, @selector(isRefreshing)) != (id)@YES) {
		return NO;
	}
	return YES;
}
- (void)setIsRefreshing:(BOOL)value {
	if (!_signatures) {
		return;
	}
	if (![_signatures isKindOfClass:[NSMutableArray class]]) {
		_signatures = [_signatures mutableCopy];
	}
	if (value) {
		objc_setAssociatedObject(_signatures, @selector(isRefreshing), @YES, OBJC_ASSOCIATION_ASSIGN);
	} else {
		objc_setAssociatedObject(_signatures, @selector(isRefreshing), @NO, OBJC_ASSOCIATION_ASSIGN);
	}
}
+ (NSSet *)keyPathsForValuesAffectingIsRefreshing {
	return [NSSet setWithObject:@"signatures"];
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
	return _userIDDescription ? @"uid" : @"uat";
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
		if (_name.length > 0 && _email.length > 0) {
			return [NSString stringWithFormat:@"%@ <%@>", _name, _email];
		} else {
			return _name.length > 0 ? _name : _email;
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
	if (_userIDDescription) {
		return _name;
	} else {
		return localized(@"PhotoID");
	}
}
- (BOOL)isUat {
	return !_userIDDescription;
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


