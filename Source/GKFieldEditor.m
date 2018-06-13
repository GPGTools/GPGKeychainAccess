//
//  GKFieldEditor.m
//  GPG Keychain
//
//  Created by Mento on 13.06.18.
//

#import "GKFieldEditor.h"

@implementation GKFieldEditor

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSPasteboardType)type {
	if ([type isEqualToString:NSStringPboardType]) {
		NSMutableString *selectedString = [NSMutableString new];
		NSString *string = self.string;
		NSArray <NSValue *> *ranges = self.selectedRanges;
		
		for (NSValue *rangeValue in ranges) {
			NSRange range = rangeValue.rangeValue;
			[selectedString appendString:[string substringWithRange:range]];
		}
		
		[selectedString replaceOccurrencesOfString:@"\xC2\xA0" withString:@" " options:0 range:NSMakeRange(0, selectedString.length)];
		
		return [pboard setString:selectedString forType:NSStringPboardType];
	}

	return [super writeSelectionToPasteboard:pboard type:type];
}

@end


