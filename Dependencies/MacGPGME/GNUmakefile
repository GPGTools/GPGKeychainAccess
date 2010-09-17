#
# If GNUSTEP_SYSTEM_ROOT is equal to nothing then include 
# ProjectBuilder makefile named Makefile else use this 
# GNUstep makefile.
# We need to do this, because On MacOS X Server 1.x (Rhapsody),
# GNUmakefile are also used by the make system, and have
# priority over Makefile, whereas Makefile MUST be used.
#
# Thanks to Damian Steer <shellac@shellac.freeserve.co.uk>
#

ifeq ($(GNUSTEP_SYSTEM_ROOT),)
  include Makefile
else

FRAMEWORK_NAME = MacGPGME
MacGPGME_CURRENT_VERSION_NAME = 1.1.4

MacGPGME_OBJC_FILES = GPGContext.m GPGData.m GPGEngine.m GPGExceptions.m \
           GPGKey.m GPGKeySignature.m GPGObject.m GPGPrettyInfo.m \
           GPGSignature.m GPGSubkey.m GPGTrustItem.m GPGUserID.m \
           LocalizableStrings.m GPGAsyncHelper.m GPGKeyGroup.m \
           GPGOptions/GPGOptions.m GPGSignatureNotation.m GPGRemoteKey.m \
           GPGRemoteUserID.m

MacGPGME_HEADER_FILES = GPGContext.h GPGData.h GPGDefines.h GPGEngine.h \
          GPGExceptions.h GPGInternals.h GPGKey.h GPGKeySignature.h \
          MacGPGME.h GPGObject.h GPGPrettyInfo.h GPGSignature.h \
          GPGSubkey.h GPGTrustItem.h GPGUserID.h LocalizableStrings.h \
          GPGAsyncHelper.h GPGKeyGroup.h GPGOptions/GPGOptions.h \
          GPGSignatureNotation.h GPGKeyDefines.h GPGRemoteKey.h \
          GPGRemoteUserID.h

ADDITIONAL_OBJCFLAGS += -I../

include $(GNUSTEP_MAKEFILES)/common.make

-include Makefile.preamble

include $(GNUSTEP_MAKEFILES)/framework.make

-include Makefile.postamble

-include Makefile.dependencies

endif
