#!/bin/bash

tempLocation="$2/GPG Keychain.app"

if [[ ! -e "$temporarydir/$bundle" ]] ;then
	echo "[gka] Couldn't install '$tempLocation'.  Aborting." >&2
	exit 1
fi

# Remove old named installation.
oldLocation=$(mdfind -onlyin /Applications "kMDItemCFBundleIdentifier = org.gpgtools.gpgkeychainaccess" | head -1)
if [[ -n "$oldLocation" ]] ;then
	rm -rf "$oldLocation"
fi

installLocation=$(mdfind -onlyin /Applications "kMDItemCFBundleIdentifier = org.gpgtools.gpgkeychain" | head -1)
installLocation=${installLocation:-/Applications/GPG Keychain.app}


rm -rf "$installLocation"
mv "$tempLocation" "$installLocation" || exit 1
chmod -R u=rwX,go=rX "$installLocation"



########################################################################################
#####     Code to fix the Dock icon     ################################################
########################################################################################

# Run the Dock fix as normal user.
sudo -u "${USER:-$(id -un)}" /bin/bash <<\EOT

DOCK_ID=com.apple.dock
DOCK_PLIST=$HOME/Library/Preferences/$DOCK_ID.plist
PLIST_BUDDY=/usr/libexec/PlistBuddy
GK_ID_OLD=org.gpgtools.gpgkeychainaccess
GK_ID=org.gpgtools.gpgkeychain

# Fetch the number of dock items.
NR_OF_DOCK_ITEMS=$(defaults read $DOCK_ID persistent-apps | grep -F '_CFURLString"' | wc -l)
#
# Find the position of the old dock GPG Keychain Access item
GK_INDEX=-1
# Loop through the items to find the index for GPG Keychain.
for((i = 0; i < $NR_OF_DOCK_ITEMS; i++)); do
	# Search for the item with the bundle-identifier $GK_ID_OLD.
    if [[ "$($PLIST_BUDDY -c "Print persistent-apps:$[$i]:tile-data:bundle-identifier" $DOCK_PLIST)" == "$GK_ID_OLD" ]] ;then
		# Found it.
		GK_INDEX=$i
		break
	fi
done


echo "$GK_INDEX"

if [[ "$GK_INDEX" == "-1" ]]; then
	echo "No dock item found. Continue..."
	exit 0
fi

# Check the bundle ID to be sure, to have the right application.
GK_PATH=$($PLIST_BUDDY -c "Print persistent-apps:$[$GK_INDEX]:tile-data:file-data:_CFURLString" $DOCK_PLIST)
if [[ "${GK_PATH:0:7}" == 'file://' ]] ;then
	GK_PATH=$(perl -MURI -le 'print URI->new(<>)->file' <<<"$GK_PATH")
fi
if [[ -e "$GK_PATH" ]] ;then
	BUNDLE_ID=$($PLIST_BUDDY -c "Print CFBundleIdentifier" "$GK_PATH/Contents/Info.plist")
	if [[ "$BUNDLE_ID" != "$GK_ID_OLD" ]] ;then
		echo "Bundle ID doesn't match. Continue..."
		exit 0
	fi
fi

installLocation=$(mdfind -onlyin /Applications "kMDItemCFBundleIdentifier = org.gpgtools.gpgkeychain" | head -1)
NEW_PATH=${installLocation:-/Applications/GPG Keychain.app}

# Update the CFURLString to the new location
$PLIST_BUDDY -c "Set persistent-apps:$[$GK_INDEX]:tile-data:file-data:_CFURLString $NEW_PATH" $DOCK_PLIST
# Update the bundle identifier.
$PLIST_BUDDY -c "Set persistent-apps:$[$GK_INDEX]:tile-data:bundle-identifier $GK_ID" $DOCK_PLIST
# Remove parent-mod-date, file-data:_CFURLAliasData, file-mod-date in order to have them recreated.
# Otherwise the dock item will still point to the old path.
$PLIST_BUDDY -c "Delete persistent-apps:$[$GK_INDEX]:tile-data:file-data:_CFURLAliasData" $DOCK_PLIST 2> /dev/null
$PLIST_BUDDY -c "Delete persistent-apps:$[$GK_INDEX]:tile-data:parent-mod-date" $DOCK_PLIST 2> /dev/null
$PLIST_BUDDY -c "Delete persistent-apps:$[$GK_INDEX]:tile-data:file-mod-date" $DOCK_PLIST 2> /dev/null
# Remove the label, otherwise the old name would appear.
$PLIST_BUDDY -c "Delete persistent-apps:$[$GK_INDEX]:tile-data:file-label" $DOCK_PLIST 2> /dev/null

# Read the dock plist to make sure the cache is flushed (otherwise our changes are not reflected)
defaults read $DOCK_ID > /dev/null
# Kill the dock to complete the fix.
killall Dock

EOT
########################################################################################


exit 0
