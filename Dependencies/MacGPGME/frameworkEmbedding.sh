#!/bin/sh

# Copied from MOKit instructions
# http://mokit.sf.net/
#
# rewrite install_name in the framework
# note we do not bother to change the debug or profile variants since those are never directly linked against at static link time.

FRAMEWORK_NAME=MacGPGME
FRAMEWORK_VERSION=1.1.4

cd "${TARGET_BUILD_DIR}/${PRODUCT_NAME}.${WRAPPER_EXTENSION}/Contents/Frameworks/${FRAMEWORK_NAME}.framework/Versions/${FRAMEWORK_VERSION}/"
chmod u+w "${FRAMEWORK_NAME}"
install_name_tool -id "@executable_path/../Frameworks/${FRAMEWORK_NAME}.framework/Versions/${FRAMEWORK_VERSION}/${FRAMEWORK_NAME}" "${FRAMEWORK_NAME}"

# rewrite install_name in the app
install_name_tool -change "/Library/Frameworks/${FRAMEWORK_NAME}.framework/Versions/${FRAMEWORK_VERSION}/${FRAMEWORK_NAME}" "@executable_path/../Frameworks/${FRAMEWORK_NAME}.framework/Versions/${FRAMEWORK_VERSION}/${FRAMEWORK_NAME}" "${TARGET_BUILD_DIR}/${PRODUCT_NAME}.${WRAPPER_EXTENSION}/Contents/MacOS/${PRODUCT_NAME}"
