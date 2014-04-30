#import "GKScripting.h"

#import <Sparkle/Sparkle.h>


@implementation GKCheckForUpdatesCommand

- (id)performDefaultImplementation {
	SUUpdater *updater = [SUUpdater sharedUpdater];
	[updater checkForUpdates:nil];
	return nil;
}

@end
