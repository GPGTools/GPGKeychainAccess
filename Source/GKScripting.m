#import "GKScripting.h"
#import <Sparkle/Sparkle.h>

@implementation GKCheckForUpdatesCommand

- (id)performDefaultImplementation {
	SUUpdater *updater = [SUUpdater sharedUpdater];
	[updater performSelectorOnMainThread:@selector(checkForUpdates:) withObject:nil waitUntilDone:NO];
	return nil;
}

@end
