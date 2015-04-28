

#import "GKDateCell.h"



@implementation GKDateCell


- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	static CGFloat minWidths[3];
	static NSDateFormatter *formatter;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSFont *font = self.font;
		NSDictionary *attributes = @{NSFontAttributeName: font};
		
		NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:472694400];
		formatter = [[NSDateFormatter alloc] init];
		[formatter setTimeStyle:NSDateFormatterNoStyle];
		
		for (int i = 2; i <= 4; i++) {
			[formatter setDateStyle:i];
			NSString *string = [formatter stringFromDate:date];
			CGFloat width = [string sizeWithAttributes:attributes].width;
			minWidths[i - 2] = width + width / 6;
		}
	});
	
	if ([self.objectValue isKindOfClass:[NSDate class]]) {
		CGFloat width = cellFrame.size.width;
		if (width > minWidths[2]) {
			[formatter setDateStyle:4];
		} else if (width > minWidths[1]) {
			[formatter setDateStyle:3];
		} else if (width > minWidths[0]) {
			[formatter setDateStyle:2];
		} else {
			[formatter setDateStyle:1];
		}
		
		NSString *formattedString = [formatter stringFromDate:self.objectValue];
		self.stringValue = formattedString;
	} else {
		self.stringValue = @"";
	}
	
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}


@end
