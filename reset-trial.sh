#!/bin/bash

# =================================================================
# Navicat Premium Maintenance Script
# =================================================================

set -uo pipefail

# 1. Variable Definitions
APP_NAME="Navicat Premium"
PLIST_IDS=("com.navicat.NavicatPremium" "com.prect.NavicatPremium15")
SUPPORT_DIR_BASE="$HOME/Library/Application Support/PremiumSoft CyberTech/Navicat CC/Navicat Premium"

echo "-----------------------------------------------"
echo "🚀 Starting cleanup of $APP_NAME trial residues..."

# 2. Terminate Processes
echo "🛑 Syncing system cache and terminating processes..."
pkill -9 "$APP_NAME" 2>/dev/null || true
killall cfprefsd 2>/dev/null || true

# 3. Handle Plist Configuration Files
for PLIST_ID in "${PLIST_IDS[@]}"; do
    PLIST_FILE="$HOME/Library/Preferences/$PLIST_ID.plist"

    if [[ -f "$PLIST_FILE" ]]; then
        echo "📂 Checking configuration file: $PLIST_ID"

        keys_to_delete=$(/usr/libexec/PlistBuddy -c "Print" "$PLIST_FILE" 2>/dev/null | grep -Eoa "^\s+[0-9A-F]{32}" | tr -d ' ' || true)

        if [[ -n "$keys_to_delete" ]]; then
            while IFS= read -r key; do
                echo "   🧹 Removing key: $key"
                /usr/libexec/PlistBuddy -c "Delete :$key" "$PLIST_FILE" 2>/dev/null || true
            done <<< "$keys_to_delete"

            # Notify the system to refresh defaults after modification
            defaults read "$PLIST_ID" >/dev/null 2>&1
        fi
    fi
done

# 4. Clean up hidden HASH files in the Application Support directory
if [[ -d "$SUPPORT_DIR_BASE" ]]; then
    echo "📂 Scanning support directory: $SUPPORT_DIR_BASE"
    find "$SUPPORT_DIR_BASE" -maxdepth 1 -type f -name '.[0-9A-F]*' -print0 2>/dev/null | while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        if echo "$filename" | grep -Eq '^\.([0-9A-F]{32})$'; then
            echo "   🗑  Deleting hidden file: $filename"
            rm -f "$file"
        fi
    done
fi

# 5. Clean up Keychain entries
echo "🔐 Searching for Keychain tracking entries..."
for SERVICE in "${PLIST_IDS[@]}"; do
    keychain_accounts=$(security dump-keychain "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null | \
        awk '/0x00000007.*'"$SERVICE"'/{found=1} found && /"acct"/{print; found=0}' | \
        sed 's/.*<blob>="\([^"]*\)".*/\1/' || true)

    if [[ -n "$keychain_accounts" ]]; then
        while IFS= read -r account; do
            if [[ "$account" =~ ^[0-9A-F]{32}$ ]]; then
                echo "   🔑 Removing Keychain item: $account"
                security delete-generic-password -s "$SERVICE" -a "$account" >/dev/null 2>&1 || true
            fi
        done <<< "$keychain_accounts"
    fi
done

echo "✨ All cleanup operations completed. Please restart Navicat to check the results."
echo "-----------------------------------------------"