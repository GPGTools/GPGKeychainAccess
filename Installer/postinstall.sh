#!/bin/bash

tempLocation="$2/GPG Keychain Access.app"

if [[ ! -e "$temporarydir/$bundle" ]] ;then
	echo "[gka] Couldn't install '$tempLocation'.  Aborting." >&2
	exit 1
fi

installLocation=$(mdfind -onlyin /Applications "kMDItemCFBundleIdentifier = org.gpgtools.gpgkeychainaccess" | head -1)
installLocation=${installLocation:-/Applications/GPG Keychain Access.app}

rm -rf "$installLocation"
mv "$tempLocation" "$installLocation" || exit 1
chmod -R 755 "$installLocation"


exit 0
