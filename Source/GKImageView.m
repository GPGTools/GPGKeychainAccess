#import "GKImageView.h"
#import "ActionController.h"
#import "SheetController.h"
#import "KeychainController.h"
#import <Libmacgpg/Libmacgpg.h>
#import "GKAExtensions.h"

@implementation GKImageView

- (void)setObjectValue:(id)objectValue {
	[super setObjectValue:[self scaleToFillImage:objectValue]];
}
- (void)setImage:(NSImage *)image {
	[super setImage:[self scaleToFillImage:image]];
}

- (void)mouseDown:(NSEvent *)event {
	if (event.clickCount == 1) {
		[[ActionController sharedInstance] photoClicked:self];
	}
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
	NSArray *keys = [[ActionController sharedInstance] selectedKeys];
	if (keys.count == 1) {
		GPGKey *key = keys[0];
		if (key.secret && !key.photoID) {
			[[ActionController sharedInstance] photoClicked:self];
			return nil;
		}
	}

	return [super menuForEvent:event];
}

- (NSImage *)scaleToFillImage:(NSImage *)image {
	// This method is based on code from Cédric Foellmi.
	// Original copyright notice:
	//
	//	The MIT License (MIT)
	//
	//	Copyright (c) 2014 Cédric Foellmi
	//
	//	Permission is hereby granted, free of charge, to any person obtaining a copy
	//	of this software and associated documentation files (the "Software"), to deal
	//	in the Software without restriction, including without limitation the rights
	//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	//	copies of the Software, and to permit persons to whom the Software is
	//	furnished to do so, subject to the following conditions:
	//
	//	The above copyright notice and this permission notice shall be included in all
	//	copies or substantial portions of the Software.
	
	
	if (image == nil || self.imageScaling != NSImageScaleAxesIndependently) {
		return image;
	}
	
	NSImage *scaleToFillImage = [NSImage imageWithSize:self.bounds.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		NSSize imageSize = image.size;
		NSSize imageViewSize = self.bounds.size; // Yes, do not use dstRect.
		
		NSSize newImageSize = imageSize;
		
		CGFloat imageAspectRatio = imageSize.height/imageSize.width;
		CGFloat imageViewAspectRatio = imageViewSize.height/imageViewSize.width;
		
		if (imageAspectRatio < imageViewAspectRatio) {
			// Image is more horizontal than the view. Image left and right borders need to be cropped.
			newImageSize.width = imageSize.height / imageViewAspectRatio;
		}
		else {
			// Image is more vertical than the view. Image top and bottom borders need to be cropped.
			newImageSize.height = imageSize.width * imageViewAspectRatio;
		}
		
		NSRect srcRect = NSMakeRect(imageSize.width/2.0-newImageSize.width/2.0,
									imageSize.height/2.0-newImageSize.height/2.0,
									newImageSize.width,
									newImageSize.height);
		
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		
		[image drawInRect:dstRect // Interestingly, here needs to be dstRect and not self.bounds
				 fromRect:srcRect
				operation:NSCompositeCopy
				 fraction:1.0
		   respectFlipped:YES
					hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
		
		return YES;
	}];
	
	[scaleToFillImage setCacheMode:NSImageCacheNever]; // Hence it will automatically redraw with new frame size of the image view.
	
	return scaleToFillImage;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if ([NSApp modalWindow]) {
		return NSDragOperationNone;
	}
	ActionController *actc = [ActionController sharedInstance];
	NSArray *keys = [actc selectedKeys];
	if (keys.count != 1) {
		return NSDragOperationNone;
	}
	GPGKey *key = keys[0];
	if (!key.secret) {
		return NSDragOperationNone;
	}
	if (key.photoID) {
		return NSDragOperationNone;
	}
	
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSTIFFPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (fileNames.count == 1) {
			NSString *fileName = [fileNames objectAtIndex:0];
			NSString *extension = [[fileName pathExtension] lowercaseString];
			NSArray *validExtensions = @[@"jpg", @"jpeg", @"png", @"tif", @"tiff", @"gif"];
			if ([validExtensions containsObject:extension]) {
				return NSDragOperationCopy;
			}

		}
	}
	return NSDragOperationNone;
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	return YES;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	ActionController *actc = [ActionController sharedInstance];
	NSArray *keys = [actc selectedKeys];
	if (keys.count != 1) {
		return NO;
	}
	GPGKey *key = keys[0];
	if (!key.secret) {
		return NO;
	}
	
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSTIFFPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (fileNames.count == 1) {
			NSString *fileName = [fileNames objectAtIndex:0];
			NSString *extension = [[fileName pathExtension] lowercaseString];
			NSArray *validExtensions = @[@"jpg", @"jpeg", @"png", @"tif", @"tiff", @"gif"];
			if ([validExtensions containsObject:extension]) {
				
				// This is required because the NSImageView would take the dragged image as new image.
				[pboard clearContents];

				[actc addPhoto:fileName toKey:key];
				return YES;
			}
		}
	}
	return NO;
}


@end

@implementation GKCircleView

- (instancetype)myInit {
	self.wantsLayer = YES;
	CALayer *layer = self.layer;
	layer.cornerRadius = self.frame.size.width / 2;
	layer.masksToBounds = YES;
	
	return self;
}
- (instancetype)initWithFrame:(NSRect)frameRect {
	return [super initWithFrame:frameRect].myInit;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
	return [super initWithCoder:coder].myInit;
}

@end
