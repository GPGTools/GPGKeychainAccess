#import "GKImageView.h"
#import "ActionController.h"
#import "SheetController.h"
#import "KeychainController.h"
#import <Libmacgpg/Libmacgpg.h>

@implementation GKImageView


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if ([NSApp modalWindow]) {
		return NSDragOperationNone;
	}
	ActionController *actc = [ActionController sharedInstance];
	NSSet *keys = [actc selectedKeys];
	if ([keys count] != 1) {
		return NO;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
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
			if ([extension isEqualToString:@"jpg"]) {
				return NSDragOperationCopy;
			}

		}
	} else if ([pboardType isEqualToString:NSTIFFPboardType]) {
		//TODO
	}
	return NSDragOperationNone;
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	return YES;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	ActionController *actc = [ActionController sharedInstance];
	NSSet *keys = [actc selectedKeys];
	if ([keys count] != 1) {
		return NO;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
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
			if ([extension isEqualToString:@"jpg"]) {
				
				unsigned long long filesize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
				if (filesize > 500 * 1000) { //Bilder über 500 KB sind zu gross. (Meiner Meinung nach.)
					[[SheetController sharedInstance] alertSheetForWindow:mainWindow
								  messageText:localized(@"ChoosePhoto_TooLarge_Message")
									 infoText:localized(@"ChoosePhoto_TooLarge_Info")
								defaultButton:nil
							  alternateButton:nil
								  otherButton:nil
							suppressionButton:nil];
					
					return NO;
				}
				
				[actc addPhoto:fileName toKey:key];
				
				[pboard clearContents];
				return YES;
			}
		}
	} else if ([pboardType isEqualToString:NSTIFFPboardType]) {
		//TODO
	}
	return NO;
}


@end
