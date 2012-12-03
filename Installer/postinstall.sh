#!/bin/bash

# config #######################################################################
if test "$USER" == ""
then
  USER=$(id -un)
fi
tempdir="/private/tmp/GKA_Installation";
appname="GPG Keychain Access.app";
targetdefault="/Applications/";
################################################################################


# determine where to install the app to ########################################
echo "[gka] Finding target..."
_target=`find /Applications -maxdepth 2 -name "$appname"`;
_target=`dirname "$_target"`

if [ "$_target" == "." ]; then
  _target="$targetdefault"
fi
echo "[gka] Target is: $_target"
################################################################################


# Cleanup ######################################################################
echo "[gka] Installer check..."
if [ ! -e "$tempdir/$appname" ]; then
    echo "[gka] Installation failed. GKA was not found at $tempdir/$appname";
    exit 1;
fi

echo "[gka] Removing old versions of the app..."
if [ "`dirname "$_target/$appname"`" != "/" ]; then rm -rf "$_target/$appname"; fi
################################################################################


# Install ######################################################################
echo "[gka] Installing..."
mkdir -p "$_target"
mv "$tempdir/$appname" "$_target"
################################################################################


# Cleanup ######################################################################
echo "[gka] Cleanup..."
if [ `dirname "$tempdir/$appname"` != "/" ]; then rm -fr "$tempdir/$appname"; fi
rm -d "$tempdir"
################################################################################

echo "[gka] Changing permissions..."
chown -Rh "$USER" "$_target/$appname"

exit 0