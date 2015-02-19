PROJECT = GPGKeychain
TARGET = GPG\ Keychain
PRODUCT = GPG\ Keychain.app


all: $(PRODUCT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychain.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

clean:
	rm -rf ./build

