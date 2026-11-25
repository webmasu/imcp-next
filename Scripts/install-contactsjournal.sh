#!/bin/sh
set -eu
dir="$HOME/Library/Application Scripts/io.webmasu.iMCP"
mkdir -p "$dir"
install -m 700 "$(dirname "$0")/contactsjournal/imcp-contactsjournal" "$dir/imcp-contactsjournal"
