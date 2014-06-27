#import "GKScripting.h"
#import <Sparkle/Sparkle.h>
#import "ActionController.h"

@implementation GKCheckForUpdatesCommand

- (id)performDefaultImplementation {
	SUUpdater *updater = [SUUpdater sharedUpdater];
	[updater performSelectorOnMainThread:@selector(checkForUpdates:) withObject:nil waitUntilDone:NO];
	return nil;
}

@end

@implementation GKGenerateNewKeyCommand

- (id)performDefaultImplementation {
	NSLog(@"performDefaultImplementation");
	ActionController *actionController = [ActionController sharedInstance];

	[actionController performSelectorOnMainThread:@selector(generateNewKey:) withObject:nil waitUntilDone:NO];
	return nil;
}

@end
