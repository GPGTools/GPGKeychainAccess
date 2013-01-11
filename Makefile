PROJECT = GPGKeychainAccess
TARGET = GPG\ Keychain\ Access
PRODUCT = GPG\ Keychain\ Access.app

include Dependencies/GPGTools_Core/newBuildSystem/Makefile.default


update: update-libmacgpg

pkg: pkg-libmacgpg

clean-all::
	$(MAKE) -C Dependencies/Libmacgpg clean-all

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychainAccess.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)
