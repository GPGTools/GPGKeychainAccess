#import "GKVolumeCollectionView.h"

@implementation GKSelectableCollectionViewItem

- (void)setSelected:(BOOL)flag {
    [super setSelected:flag];
    [(GKVolumeCollectionView *)self.view setSelected:flag];
    [self.view setNeedsDisplay:YES];
}

@end



@implementation GKVolumeCollectionView


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	if (self.selected) {
		[NSGraphicsContext saveGraphicsState];
		
		NSRect rect = self.bounds;
		rect.size.width -= 10;
		rect.size.height -= 10;
		rect.origin.x += 5;
		rect.origin.y += 5;
		
		NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect
															 xRadius:10
															 yRadius:10];
		[path addClip];
		
		[[NSColor selectedControlColor] set];
		NSRectFill(rect);
		
		
		[NSGraphicsContext restoreGraphicsState];
    }
}
- (BOOL)isFlipped {
	return NO;
}

@end


@implementation GKVolumeImageView

- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];
}


@end