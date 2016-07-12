#import "GKMenuButton.h"

@implementation GKMenuButton

- (void)awakeFromNib {
	self.target = self;
	self.action = @selector(clicked);
}
- (void)setMenu:(NSMenu *)value {
	menu = value;
	[super setMenu:nil];
}
- (void)clicked {
	if (!menu) {
		return;
	}
	NSRect frame = self.frame;
    NSPoint menuOrigin = [[self superview] convertPoint:NSMakePoint(frame.origin.x, frame.origin.y - 3) toView:nil];
	
    NSEvent *event =  [NSEvent mouseEventWithType:NSLeftMouseDown
                                         location:menuOrigin
                                    modifierFlags:(NSEventModifierFlags)NSLeftMouseDownMask
                                        timestamp:0
                                     windowNumber:[self.window windowNumber]
                                          context:[self.window graphicsContext]
                                      eventNumber:0
                                       clickCount:1
                                         pressure:1];
	
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

@end

