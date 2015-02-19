PRODUCT = GPG\ Keychain.app
VPATH = build/Release

all: $(PRODUCT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychain.xcodeproj
	@xcodebuild -project GPGKeychain.xcodeproj -target "GPG Keychain" build

clean:
	rm -rf ./build

