//
//  GPGToolbarItem.h
//  GPG Keychain
//
//  Created by Mento on 09.10.20.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (GPG_imageWithSystemSymbolName)
+ (instancetype)imageWithSystemSymbolName:(NSString *)symbolName accessibilityDescription:(NSString *)description;
@end
@interface NSToolbarItem (GPG_initWithCoder)
- (instancetype)initWithCoder:(NSCoder *)coder;
@end
@interface GPGToolbarItem : NSToolbarItem
@end

NS_ASSUME_NONNULL_END
