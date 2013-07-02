PROJECT = GPGKeychainAccess
TARGET = GPG\ Keychain\ Access
PRODUCT = GPG\ Keychain\ Access.app
MAKE_DEFAULT = Dependencies/GPGTools_Core/newBuildSystem/Makefile.default
NEED_LIBMACGPG = 1


-include $(MAKE_DEFAULT)

.PRECIOUS: $(MAKE_DEFAULT)
$(MAKE_DEFAULT):
	@bash -c "$$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-core.sh)"

init: $(MAKE_DEFAULT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychainAccess.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

install: $(PRODUCT)
	@echo "Installing GPG Keychain Access into /Applications"
	@rsync -rltDE "build/$(CONFIG)/GPG Keychain Access.app" /Applications
	@echo Done
	@echo "In order to use GPG Keychain Access, please don't forget to install MacGPG2 and Libmacgpg."

