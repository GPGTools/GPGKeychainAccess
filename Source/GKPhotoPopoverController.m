//
//  GKPopoverViewController.m
//  GPGKeychain
//
//  Created by Mento on 20.03.17.
//
//

#import "GKPhotoPopoverController.h"
#import "ActionController.h"

@implementation GKPhotoPopoverController

@end


@implementation GKPhotoPopoverView

- (void)mouseDown:(NSEvent *)event {
	[[ActionController sharedInstance] closePhotoPopover];
}

@end
