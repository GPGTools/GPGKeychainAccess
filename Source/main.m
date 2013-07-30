
#import <Libmacgpg/Libmacgpg.h>
#import "Globales.h"
#import "NSBundle+Sandbox.h"

int main(int argc, char *argv[]) {
#ifndef DEBUGGING
	/* Perform signature validation, to check if the app bundle has been tampered with. */
	if([[NSBundle mainBundle] ob_codeSignState] != OBCodeSignStateSignatureValid) {
        NSRunAlertPanel(@"Someone tampered with your installation of GPG Keychain Access!", @"To keep you safe, GPG Keychain Access will exit now!\n\nPlease download and install the latest version of GPG Suite from https://gpgtools.org to be sure you have an original version from us!", @"", nil, nil, nil);
        exit(1);
    }
#endif

	if (![GPGController class]) {
		NSRunAlertPanel(localized(@"LIBMACGPG_NOT_FOUND_TITLE"), localized(@"LIBMACGPG_NOT_FOUND_MESSAGE"), nil, nil, nil);
		return 1;
	}

    return NSApplicationMain(argc,  (const char **) argv);
}
