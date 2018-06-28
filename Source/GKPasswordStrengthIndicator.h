//
//  GKPasswordStrengthIndicator.h
//  GPG Keychain
//
//  Created by Mento on 28.06.18.
//

#import <Cocoa/Cocoa.h>

@interface GKPasswordStrengthIndicator : NSProgressIndicator
@end
@interface GKPasswordStrengthIndicator () {
	NSColor *borderColor;
	NSColor *backgroundColor;
	NSGradient *gradient;
	
}
@end

