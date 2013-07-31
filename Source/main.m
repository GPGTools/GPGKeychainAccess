
#import <Libmacgpg/Libmacgpg.h>
#import "Globales.h"

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

    return NSApplicationMain(argc, argv);
}
