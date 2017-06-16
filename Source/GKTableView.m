#import "GKTableView.h"

@implementation GKTableView
@synthesize clickedRowWasSelected;

- (void)mouseDown:(NSEvent *)theEvent {
	NSInteger row = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	clickedRowWasSelected = [[self selectedRowIndexes] containsIndex:row];
	[super mouseDown:theEvent];
}

@end

@implementation GKTableHeaderView
#warning This class is required until jenkins is up to date.
- (void)setFrame:(NSRect)frame {
	super.frame = frame;
}
- (NSRect)frame {
	NSRect frame = super.frame;
	if (NSAppKitVersionNumber < 1404 /* < 10.11 */) {
		frame.size.height = 17;
	}
	return frame;
}
@end
