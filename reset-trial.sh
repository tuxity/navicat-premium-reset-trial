#!/bin/bash

set -e

# Check if Navicat is running
if pgrep -x "Navicat Premium" > /dev/null; then
    echo ""
    echo "   Navicat Premium is currently running!"
    echo "   Please save your work before continuing."
    echo ""
    read -n 1 -s -r -p "Press any key to close Navicat and continue..."
    echo ""
    echo "Closing Navicat Premium..."
    killall "Navicat Premium" 2>/dev/null
    sleep 1
fi

file=$(defaults read /Applications/Navicat\ Premium.app/Contents/Info.plist)

regex="CFBundleShortVersionString = \"([^\"]+)\""
[[ $file =~ $regex ]]

full_version=${BASH_REMATCH[1]}
version=${full_version%%.*}

echo "Detected Navicat Premium version $full_version"

case $version in
    "17"|"16")
        service=com.navicat.NavicatPremium
        file=~/Library/Preferences/$service.plist
        ;;
    "15")
        service=com.prect.NavicatPremium15
        file=~/Library/Preferences/$service.plist
        ;;
    *)
        echo "Version '$version' not handled"
        exit 1
       ;;
esac

echo "Resetting trial time..."

plist_content=$(defaults read $file)
regex="([0-9A-Z]{32}) = "
if [[ $plist_content =~ $regex ]]; then
    hash=${BASH_REMATCH[1]}
    echo "deleting $hash array..."
    defaults delete $file $hash
else
    echo "No trial hash found in plist (already cleared)"
fi

cc_dir=~/Library/Application\ Support/PremiumSoft\ CyberTech/Navicat\ CC/Navicat\ Premium
hidden_files=$(ls -a "$cc_dir" | grep '^\.' || true)
regex="\.([0-9A-Z]{32})"
if [[ $hidden_files =~ $regex ]]; then
    hash2=${BASH_REMATCH[1]}
    echo "deleting $hash2 file..."
    rm -f "$cc_dir/.$hash2"
else
    echo "No trial hash file found in CC directory (already cleared)"
fi

# Keychain cleanup only needed for v17.3.7+
needs_keychain=false
if [[ "$version" == "17" ]]; then
    IFS='.' read -r maj min patch <<< "$full_version"
    if (( min > 3 )) || (( min == 3 && patch >= 7 )); then
        needs_keychain=true
    fi
fi

if [ "$needs_keychain" = true ]; then
    # Get all keychain hashes for this service (may be multiple)
    keychain_hashes=$(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -A 5 "$service" | grep acct | grep -oE '[0-9A-F]{32}')

    if [ ! -z "$keychain_hashes" ]; then
        # Delete each keychain entry
        while IFS= read -r keychain_hash; do
            if [ ! -z "$keychain_hash" ]; then
                echo "deleting keychain entry $keychain_hash..."
                security delete-generic-password -s "$service" -a "$keychain_hash" &>/dev/null
            fi
        done <<< "$keychain_hashes"
    fi
fi

echo "Done"
