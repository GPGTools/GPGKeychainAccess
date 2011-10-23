PROJECT = GPGKeychainAccess
TARGET = "GPG Keychain Access"
CONFIG = Release

include Dependencies/GPGTools_Core/make/default

all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-libmac:
	@cd Dependencies/Libmacgpg; git pull origin lion; cd -
update-me:
	@git pull

update: update-core update-libmac update-me

compile:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build

clean:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) clean > /dev/null

test: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh auto
	@./Dependencies/GPGTools_Core/scripts/upload.sh
