/*
 Copyright © Roman Zechmeister, 2017
 
 Diese Datei ist Teil von GPG Keychain.
 
 GPG Keychain ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "Globales.h"
#import "ActionController.h"
#import "KeychainController.h"
#import "AppDelegate.h"


NSWindow *mainWindow;
GPGKeychainAppDelegate *appDelegate;
BOOL showExpertSettings;



BOOL couldContainPGPKey(NSString *string) {
	return ([string rangeOfString:@"-----BEGIN PGP "].length > 0);
}


NSString *localized(NSString *key) {
	if (!key) {
		return nil;
	}
	static NSBundle *bundle = nil, *englishBundle = nil;
	if (!bundle) {
		bundle = [NSBundle mainBundle];
		englishBundle = [NSBundle bundleWithPath:[bundle pathForResource:@"en" ofType:@"lproj"]];
	}
	
	NSString *notFoundValue = @"~#*?*#~";
	NSString *localized = [bundle localizedStringForKey:key value:notFoundValue table:nil];
	if (localized == notFoundValue) {
		localized = [englishBundle localizedStringForKey:key value:nil table:nil];
	}
	
	return localized;
}
NSString *localizedStringWithFormat(NSString *key, ...) {
	NSString *localizedFormat = localized(key);
	
	va_list args;
	va_start(args, key);
	NSString *string = [[NSString alloc] initWithFormat:localizedFormat arguments:args];
	va_end(args);
	
	return string;
}



NSString *filenameForExportedKeys(NSArray *keys, NSString **secFilename) {
	NSString *filename;
	NSUInteger count = keys.count;
	__block BOOL hasSecKey = NO;
	
	[keys enumerateObjectsUsingBlock:^(GPGKey *key, NSUInteger idx, BOOL *stop) {
		if (key.secret) {
			hasSecKey = YES;
			*stop = YES;
		}
	}];
	
	if (count == 1) {
		GPGKey *key = keys[0];
		
		NSString *description = [NSString stringWithFormat:@"%@ (%@)", key.name, key.shortKeyID];
		filename = localizedStringWithFormat(@"ExportPublicKeyFilename", description);
		
		if (hasSecKey && secFilename) {
			*secFilename = localizedStringWithFormat(@"ExportSecretKeyFilename", description);
		}
	} else {
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = @"Y-MM-dd";
		NSString *date = [dateFormatter stringFromDate:[NSDate date]];
		filename = [NSString stringWithFormat:localized(@"ExportKeysFilename"), date, count];
	}

	return filename;
}




@implementation GKAKeyColorTransformer
+ (Class)transformedValueClass { return [NSColor class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	
	if ([value respondsToSelector:@selector(validity)]) {
		if ([value validity] >= GPGValidityInvalid) {
			return [NSColor disabledControlTextColor];
		}
	}
	
	return [NSColor blackColor];
}

@end

@implementation GKAValidityInidicatorTransformer
+ (Class)transformedValueClass { return [NSColor class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	
	GPGValidity validity = [value intValue];
	if (validity >= GPGValidityInvalid) {
		return @1;
	}
	if (validity == GPGValidityUltimate) {
		return @5;
	}
	if (validity == GPGValidityFull) {
		return @4;
	}
	if (validity == GPGValidityMarginal) {
		return @3;
	}
	
	return @2;
}

@end

@implementation GKIsValidTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return @([value intValue] < GPGValidityInvalid);
}

@end

@implementation GKFingerprintTransformer
- (id)transformedValue:(id)value {
	NSString *fingerprint = [value description];
	if (fingerprint.length <= 16) {
		return @"0000 0000 0000 0000  0000 0000 0000 0000";
	}
	return [super transformedValue:value];
}
@end

@implementation GKFixedFingerprintTransformer
- (id)transformedValue:(id)value {
//	return [super transformedValue:value];
	
	static NSDictionary *fixedAttributes = nil, *normalAttributes = nil, *boldFixedAttributes = nil, *boldNormalAttributes = nil;
	

	
	if (!fixedAttributes) {
		CGFloat fontSize = [NSFont systemFontSize];
		NSFont *systemFont = [NSFont systemFontOfSize:fontSize];
		NSFont *boldSystemFont = [NSFont boldSystemFontOfSize:fontSize];
		NSDictionary *defaultAttributes = @{NSFontAttributeName: systemFont};
		
		CGFloat maxWidth = 0;
		for (NSString *character in @[@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"A", @"B", @"C", @"D", @"E", @"F"]) {
			maxWidth = MAX([character sizeWithAttributes:defaultAttributes].width, maxWidth);
		}
		
		NSFontDescriptor *fontDescriptor = [systemFont.fontDescriptor fontDescriptorByAddingAttributes:@{NSFontFixedAdvanceAttribute: @(maxWidth - 0.8)}];
		NSFontDescriptor *boldFontDescriptor = [boldSystemFont.fontDescriptor fontDescriptorByAddingAttributes:@{NSFontFixedAdvanceAttribute: @(maxWidth - 0.8)}];
		
		
		NSMutableParagraphStyle *paragraphSytle = [NSMutableParagraphStyle new];
		paragraphSytle.lineBreakMode = NSLineBreakByTruncatingHead;
		
		normalAttributes     = @{NSFontAttributeName: systemFont,
								 NSParagraphStyleAttributeName: paragraphSytle};
		
		boldNormalAttributes = @{NSFontAttributeName: boldSystemFont,
								 NSParagraphStyleAttributeName: paragraphSytle};
		
		fixedAttributes      = @{NSFontAttributeName: [NSFont fontWithDescriptor:fontDescriptor size:fontSize],
								 NSParagraphStyleAttributeName: paragraphSytle};
		
		boldFixedAttributes  = @{NSFontAttributeName: [NSFont fontWithDescriptor:boldFontDescriptor size:fontSize],
								 NSParagraphStyleAttributeName: paragraphSytle};

	}
	
	
	NSDictionary *fixed = fixedAttributes, *normal = normalAttributes;
	
	if ([value respondsToSelector:@selector(secret)] && [value secret]) {
		fixed = boldFixedAttributes;
		normal = boldNormalAttributes;
	}
	
	
	
	NSString *fingerprint = [super transformedValue:value];
	
	
	
	
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:fingerprint attributes:fixed];
	
	
	
	
	
	NSUInteger length = fingerprint.length;
	NSRange searchRange = NSMakeRange(0, length);
	NSRange foundRange;
	while (searchRange.location < length) {
		searchRange.length = length - searchRange.location;
		foundRange = [fingerprint rangeOfString:@" " options:0 range:searchRange];
		if (foundRange.location != NSNotFound) {
			searchRange.location = foundRange.location + foundRange.length;
			
			[string setAttributes:normal range:foundRange];
		} else {
			break;
		}
	}
	
	
	
	
	
	
	return string;
}
@end

@implementation GKOnlyOneSelectionIndexTransformer
- (id)transformedValue:(NSIndexSet *)value {
	if (![value isKindOfClass:[NSIndexSet class]]) {
		return @NO;
	}
	return @(value.count == 1);
}
@end

@implementation GKNotOneSelectionIndexTransformer
- (id)transformedValue:(NSIndexSet *)value {
	if (![value isKindOfClass:[NSIndexSet class]]) {
		return @YES;
	}
	return @(value.count != 1);
}
@end


