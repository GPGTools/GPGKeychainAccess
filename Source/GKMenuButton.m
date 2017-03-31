#import "GKMenuButton.h"

@implementation GKMenuButton
@synthesize delegate;

- (void)awakeFromNib {
	self.target = self;
	self.action = @selector(clicked);
}
- (void)setMenu:(NSMenu *)value {
	menu = value;
	[super setMenu:nil];
}
- (void)clicked {
	if ([self.delegate respondsToSelector:@selector(menuButtonShouldShowMenu:)]) {
		if ([self.delegate menuButtonShouldShowMenu:self] == NO) {
			return;
		}
	}
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


@implementation GKHoverButton

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (!self) {
		return nil;
	}
	
	self.wantsLayer = YES;
	self.alphaValue = 0;

	NSAttributedString *title =  self.attributedTitle;
	NSMutableAttributedString *whiteTitle = [title mutableCopy];
	[whiteTitle addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, whiteTitle.length)];
	
	self.attributedTitle = whiteTitle;
	
	NSRect rect = self.frame;
	rect.origin.y = 18;
	
	CALayer *layer = self.layer;
	layer.shadowColor = [NSColor colorWithWhite:.2 alpha:1].CGColor;
	layer.shadowRadius = 7;
	layer.shadowOpacity = 1;
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddRect(path, nil, NSRectToCGRect(rect));
	layer.shadowPath = path;
	CGPathRelease(path);
	
	return self;
}

- (void)mouseEntered:(NSEvent *)theEvent {
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = .2;
		self.animator.alphaValue = 1;
	} completionHandler:^{}];

}

- (void)mouseExited:(NSEvent *)theEvent {
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = .2;
		self.animator.alphaValue = 0;
	} completionHandler:^{}];
}

- (void)setHidden:(BOOL)hidden {
	[super setHidden:hidden];
	if (hidden) {
		self.alphaValue = 0;
	} else {
		NSRect rect = NSZeroRect;
		rect.origin = [NSEvent mouseLocation];
		rect = [self.window convertRectFromScreen:rect];
		NSPoint point = [self convertPoint:rect.origin fromView:nil];
		
		if (NSPointInRect(point, self.bounds)) {
			self.alphaValue = 1;
		}
	}
}

- (void)updateTrackingAreas {
	if (trackingArea != nil) {
		[self removeTrackingArea:trackingArea];
	}
	
	NSUInteger options = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
	NSRect rect = self.bounds;
	rect.origin.y -= 40;
	rect.size.height += 40;
	
	trackingArea = [[NSTrackingArea alloc] initWithRect:rect options:options owner:self userInfo:nil];

	[self addTrackingArea:trackingArea];
}


@end


