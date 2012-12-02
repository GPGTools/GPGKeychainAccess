PROJECT = GPGKeychainAccess
TARGET = "GPG Keychain Access"
CONFIG = Release

XCCONFIG = ""
ifeq ("$(CODE_SIGN)","1")
    XCCONFIG=-xcconfig Dependencies/GPGTools_Core/make/code-signing.xcconfig
endif


include Dependencies/GPGTools_Core/make/default

all: compile

deploy: clean compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh auto no-force-tag
	@./Dependencies/GPGTools_Core/scripts/upload.sh

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-libmac:
	@cd Dependencies/Libmacgpg; git pull origin master; cd -
update-me:
	@git pull

update: update-core update-libmac update-me

compile:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

clean:
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) clean > /dev/null

test: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh auto
	@./Dependencies/GPGTools_Core/scripts/upload.sh

pkg-core: compile
	@./pkg-core.sh
