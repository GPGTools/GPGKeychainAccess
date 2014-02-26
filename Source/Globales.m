/*
 Copyright © Roman Zechmeister, 2014
 
 Diese Datei ist Teil von GPG Keychain Access.
 
 GPG Keychain Access ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain Access erfolgt in der Hoffnung, daß es Ihnen 
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
GPGKeychainAccessAppDelegate *appDelegate;




BOOL containsPGPKeyBlock(NSString *string) {
	return ([string rangeOfString:@"-----BEGIN PGP PUBLIC KEY BLOCK-----"].length > 0 && 
			[string rangeOfString:@"-----END PGP PUBLIC KEY BLOCK-----"].length > 0) || 
		([string rangeOfString:@"-----BEGIN PGP PRIVATE KEY BLOCK-----"].length > 0 && 
		 [string rangeOfString:@"-----END PGP PRIVATE KEY BLOCK-----"].length > 0);
}


NSString *localized(NSString *key) {
	if (!key) {
		return nil;
	}
	static NSBundle *bundle = nil, *englishBundle = nil;
	if (!bundle) {
		bundle = [[NSBundle mainBundle] retain];
		englishBundle = [[NSBundle bundleWithPath:[bundle pathForResource:@"en" ofType:@"lproj"]] retain];
	}
	
	NSString *notFoundValue = @"~#*?*#~";
	NSString *localized = [bundle localizedStringForKey:key value:notFoundValue table:nil];
	if (localized == notFoundValue) {
		localized = [englishBundle localizedStringForKey:key value:nil table:nil];
	}
	
	return localized;
}



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


