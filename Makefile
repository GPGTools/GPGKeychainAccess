all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-libmac:
	@cd Dependencies/Libmacgpg; git pull origin lion; cd -
update-me:
	@git pull

update: update-core update-libmac update-me

compile:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release build

clean:
	xcodebuild -project GPGKeychainAccess.xcodeproj -target "GPG Keychain Access" -configuration Release clean

dmg: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh

test: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh auto
