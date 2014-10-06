PROJECT = GPGKeychain
TARGET = GPG\ Keychain
PRODUCT = GPG\ Keychain.app
MAKE_DEFAULT = Dependencies/GPGTools_Core/newBuildSystem/Makefile.default
NEED_LIBMACGPG = 1


-include $(MAKE_DEFAULT)

.PRECIOUS: $(MAKE_DEFAULT)
$(MAKE_DEFAULT):
	@bash -c "$$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-core.sh)"

init: $(MAKE_DEFAULT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychain.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

install: $(PRODUCT)
	@echo "Installing GPG Keychain into /Applications"
	@rsync -rltDE "build/$(CONFIG)/GPG Keychain.app" /Applications
	@echo Done
	@echo "In order to use GPG Keychain, please don't forget to install MacGPG2 and Libmacgpg."


