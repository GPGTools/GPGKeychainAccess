#import <Cocoa/Cocoa.h>


@class GKMenuButton;

@protocol GKMenuButtonDelegate
@optional
- (BOOL)menuButtonShouldShowMenu:(GKMenuButton *)menuButton;
@end

@interface GKMenuButton : NSButton {
	NSMenu *menu;
}
@property (nonatomic, weak) IBOutlet NSObject <GKMenuButtonDelegate> *delegate;
@end

@interface GKHoverButton : GKMenuButton {
	NSTrackingArea *trackingArea;
	BOOL isColored;
}
@end
