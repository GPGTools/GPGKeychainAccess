
#import <Libmacgpg/Libmacgpg.h>
#import "Globales.h"

int main(int argc, char *argv[]) {
	if (![GPGController class]) {
		NSRunAlertPanel(localized(@"LIBMACGPG_NOT_FOUND_TITLE"), localized(@"LIBMACGPG_NOT_FOUND_MESSAGE"), nil, nil, nil);
		return 1;
	}

    return NSApplicationMain(argc,  (const char **) argv);
}
