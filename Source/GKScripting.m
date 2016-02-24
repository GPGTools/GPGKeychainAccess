#import "GKScripting.h"
#import "ActionController.h"

@implementation GKCheckForUpdatesCommand

- (id)performDefaultImplementation {
	NSRunAlertPanel(@"This version does not support automatic updates.",
					@"Please go to https://old.gpgtools.org and look for the current version.", nil, nil, nil);
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
