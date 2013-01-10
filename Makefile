PROJECT = GPGKeychainAccess
TARGET = "GPG Keychain Access"
CONFIG = Release


include Dependencies/GPGTools_Core/newBuildSystem/Makefile.default


update: update-libmacgpg

pkg: pkg-libmacgpg

clean-all::
	$(MAKE) -C Dependencies/Libmacgpg clean-all

