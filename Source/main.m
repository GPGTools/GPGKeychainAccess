
#import <Libmacgpg/Libmacgpg.h>
#import "Globales.h"

void prepareDarkModeImages(void);

@interface NSAppearance(bestMatchFromAppearancesWithNames)
- (NSAppearanceName)bestMatchFromAppearancesWithNames:(NSArray<NSAppearanceName> *)appearances;
@end



int main(int argc, const char *argv[]) {
	if (![GPGController class]) {
		NSRunAlertPanel(localized(@"LIBMACGPG_NOT_FOUND_TITLE"), localized(@"LIBMACGPG_NOT_FOUND_MESSAGE"), nil, nil, nil);
		return 1;
	}
#ifdef CODE_SIGN_CHECK
	/* Check the validity of the code signature. */
    if (![NSBundle mainBundle].isValidSigned) {
		NSRunAlertPanel(localized(@"CODE_SIGN_ERROR_TITLE"), localized(@"CODE_SIGN_ERROR_MESSAGE"), nil, nil, nil);
        return 1;
    }
#endif
	prepareDarkModeImages();
	
    return NSApplicationMain(argc, argv);
}


void prepareDarkModeImages() {
	if (@available(macOS 10.14, *)) {
		NSArray *imageNames = @[@"Search"];
		
		for (NSString *imageName in imageNames) {
			
			NSImage *lightImage = [NSImage imageNamed:imageName];
			lightImage.name = [imageName stringByAppendingString:@"_light"];
			NSImage *darkImage = [NSImage imageNamed:[imageName stringByAppendingString:@"_dark"]];
			
			NSImage *searchImage = [NSImage imageWithSize:lightImage.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
				NSAppearance *appearance = NSAppearance.currentAppearance;
				NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, @"NSAppearanceNameDarkAqua"]];
				
				NSImage *image;
				if ([appearanceName isEqualToString:@"NSAppearanceNameDarkAqua"]) {
					image = darkImage;
				} else {
					image = lightImage;
				}
				[image drawInRect:dstRect];
				return YES;
			}];
			
			[searchImage setName:imageName];
		}
		
	}
}

