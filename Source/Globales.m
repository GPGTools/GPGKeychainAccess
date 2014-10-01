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


