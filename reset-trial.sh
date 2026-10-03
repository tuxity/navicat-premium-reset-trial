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
    "18"|"17"|"16")
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

# 1. Delete plist hash entries
if [ -f "$file" ]; then
    regex="([0-9A-Z]{32}) = "
    [[ $(defaults read "$file" 2>/dev/null) =~ $regex ]]
    hash=${BASH_REMATCH[1]}

    if [ -n "$hash" ]; then
        echo "deleting $hash array from plist..."
        defaults delete "$file" "$hash" 2>/dev/null || true
    fi
fi

# 2. Delete Application Support hidden hash folders
app_support_dir="$HOME/Library/Application Support/PremiumSoft CyberTech/Navicat CC/Navicat Premium"
if [ -d "$app_support_dir" ]; then
    regex="\.([0-9A-Z]{32})"
    hidden_files=$(ls -a "$app_support_dir" | grep '^\.')
    if [[ $hidden_files =~ $regex ]]; then
        hash2=${BASH_REMATCH[1]}
        if [ -n "$hash2" ]; then
            echo "deleting hidden folder .$hash2..."
            rm -rf "$app_support_dir/.$hash2"
        fi
    fi
fi

# 3. Delete Keychain entries (Required for v17.3.7+ and v18)
keychain_hashes=$(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -A 5 "$service" | grep acct | grep -oE '[0-9A-F]{32}')

if [ -n "$keychain_hashes" ]; then
    while IFS= read -r keychain_hash; do
        if [ -n "$keychain_hash" ]; then
            echo "deleting keychain entry $keychain_hash..."
            security delete-generic-password -s "$service" -a "$keychain_hash" &>/dev/null || true
        fi
    done <<< "$keychain_hashes"
fi

echo "Done! Trial reset successfully."