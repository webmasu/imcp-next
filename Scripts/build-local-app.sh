#!/bin/sh
# Build a sandboxed Release app for a local Apple Development team.
set -eu
: "${1:?Usage: Scripts/build-local-app.sh TEAM_ID [derived-data-directory]}"
repo=$(cd "$(dirname "$0")/.." && pwd)
out=${2:-"$repo/.build"}
xcodebuild -quiet -project "$repo/iMCP.xcodeproj" -scheme iMCP -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$out" \
    DEVELOPMENT_TEAM="$1" \
    -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="Apple Development" \
    EMBED_HOME_HELPER=NO build
echo "$out/Build/Products/Release/iMCP.app"
