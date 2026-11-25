#!/bin/sh
set -eu
dir="$HOME/Library/Application Scripts/io.webmasu.iMCP"
mkdir -p "$dir"
base=$(dirname "$0")
install -m 600 "$base/../App/Services/imsg-tools.json" "$dir/imsg-tools.json"
install -m 600 "$base/imsg/imsg_operations.py" "$dir/imsg_operations.py"
install -m 600 "$base/imsg/imsg_attachment.py" "$dir/imsg_attachment.py"
install -m 700 "$(dirname "$0")/imsg/imcp-imsg" "$dir/imcp-imsg"
