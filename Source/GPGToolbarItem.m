//
//  GPGToolbarItem.m
//  GPG Keychain
//
//  Created by Mento on 09.10.20.
//

#import "GPGToolbarItem.h"

@implementation GPGToolbarItem

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (!self) {
		return nil;
	}

	// Load system SF Symbols on macOS Big Sur.
	
	if (@available(macOS 10.16, *)) {
		NSString *imageName = self.image.name;
		if (imageName) {
			NSDictionary *imageNameMap = @{@"Add": @"plus",
										   @"Import": @"square.and.arrow.down",
										   @"Export": @"square.and.arrow.up",
										   @"Search": @"magnifyingglass",
										   @"Delete": @"trash",
										   @"Info": @"info",
										   @"Updates": @"square.and.arrow.down.fill",
										   @"Keyserver": @"key.icloud"};
			NSString *newImageName = imageNameMap[imageName];
			if (newImageName) {
				if ([NSImage respondsToSelector:@selector(imageWithSystemSymbolName:accessibilityDescription:)]) {
					NSImage *image = [NSImage imageWithSystemSymbolName:newImageName accessibilityDescription:newImageName];
					if (image) {
						self.image = image;
					}
				}
			}
		}
	}
	
	return self;
}
@end
