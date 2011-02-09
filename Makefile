all: compile

compile:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release build

clean:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release clean

dmg: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh
