update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-me:
	@git pull

update: update-core update-me

all: compile

compile:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release build

clean:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release clean

dmg: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh
