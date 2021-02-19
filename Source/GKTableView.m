#import "GKTableView.h"

@implementation GKTableView
@synthesize clickedRowWasSelected;

- (void)mouseDown:(NSEvent *)theEvent {
	NSInteger row = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	clickedRowWasSelected = [[self selectedRowIndexes] containsIndex:row];
	[super mouseDown:theEvent];
}

@end

