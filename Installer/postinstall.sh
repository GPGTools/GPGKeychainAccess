#!/bin/bash

tempLocation="$2/GPG Keychain.app"

if [[ ! -e "$temporarydir/$bundle" ]] ;then
	echo "[gka] Couldn't install '$tempLocation'.  Aborting." >&2
	exit 1
fi

installLocation=$(mdfind -onlyin /Applications "kMDItemCFBundleIdentifier = org.gpgtools.gpgkeychain" | head -1)
installLocation=${installLocation:-/Applications/GPG Keychain.app}

rm -rf "$installLocation"
mv "$tempLocation" "$installLocation" || exit 1
chmod -R u=rwX,go=rX "$installLocation"


exit 0
