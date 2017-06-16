#import <Cocoa/Cocoa.h>

@interface GKTableView : NSTableView {
	BOOL clickedRowWasSelected;
}
@property BOOL clickedRowWasSelected;
@end

@interface GKTableHeaderView : NSTableHeaderView
@end
