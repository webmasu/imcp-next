#!/bin/sh
set -eu
dir="$HOME/Library/Application Scripts/io.webmasu.iMCP"
mkdir -p "$dir"
install -m 700 "$(dirname "$0")/busycontacts/imcp-busycontacts" "$dir/imcp-busycontacts"
install -m 600 "$(dirname "$0")/busycontacts/card_details.py" "$dir/card_details.py"
install -m 700 "$(dirname "$0")/busycontacts/imcp-contact-link" "$dir/imcp-contact-link"
