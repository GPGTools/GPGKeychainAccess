PRODUCT = GPG\ Keychain
VPATH = build/.dst

all: $(PRODUCT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGKeychain.xcodeproj
	xcodebuild -project GPGKeychain.xcodeproj -target "GPG Keychain" build $(XCCONFIG)
	@ln -fhs "Release/GPG Keychain.app/Contents/MacOS" ./build/.dst

clean:
	rm -rf ./build

