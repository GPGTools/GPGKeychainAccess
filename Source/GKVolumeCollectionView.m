#import "GKVolumeCollectionView.h"

@implementation GKSelectableCollectionViewItem

- (void)setSelected:(BOOL)flag {
    [super setSelected:flag];
    [(GKVolumeCollectionView *)self.view setSelected:flag];
    [self.view setNeedsDisplay:YES];
}

@end



@implementation GKVolumeCollectionView


- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];
	if (self.selected) {
		[[NSColor selectedControlColor] set];
		NSRectFill(self.bounds);
    }
}

@end
