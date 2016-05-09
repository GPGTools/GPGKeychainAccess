#import "GKScripting.h"
#import "ActionController.h"

@implementation GKGenerateNewKeyCommand

- (id)performDefaultImplementation {
	NSLog(@"performDefaultImplementation");
	ActionController *actionController = [ActionController sharedInstance];

	[actionController performSelectorOnMainThread:@selector(generateNewKey:) withObject:nil waitUntilDone:NO];
	return nil;
}

@end
