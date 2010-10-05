all: install

install:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release build

clean:
	rm -rf Dependencies/MacGPGME/build/dist
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release clean
