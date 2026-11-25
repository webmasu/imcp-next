#!/bin/sh
# Install the original BusyMac release locally; its license does not grant redistribution.
set -eu
umask 077
version=1.3.0
digest=2672f0794f25e862144b20c8e6aaacc08b0e702f6d4beffd22d9339921585fa6
package="BusyCalMCP-$version"
dir="$HOME/Library/Application Scripts/io.webmasu.iMCP"
mkdir -p "$dir"
stage=$(mktemp -d "$dir/.busycal.XXXXXX")
trap 'rm -rf "$stage"' EXIT
bundle="$stage/vendor.mcpb"
if [ "$#" -eq 0 ]; then
    curl -fLsS --proto '=https' "https://github.com/BeehiveInnovations/busycal-mcpb/releases/download/v$version/busycal.$version.mcpb" -o "$bundle"
elif [ "$#" -eq 1 ]; then
    cp "$1" "$bundle"
else
    echo "Usage: $0 [official.mcpb]" >&2
    exit 2
fi
(cd "$stage" && echo "$digest  vendor.mcpb" | shasum -a 256 -c -)
ditto -x -k "$bundle" "$stage/$package"
bridge="dist/BusyCalMCPBridge"
chmod 700 "$stage/$package/$bridge"
codesign --verify --strict -R '=anchor apple generic and identifier "BusyCalMCPBridge" and certificate leaf[subject.OU] = "N4RA379GBW"' "$stage/$package/$bridge"
install -m 700 "$(dirname "$0")/busycal/imcp-busycal" "$stage/imcp-busycal"
"$stage/imcp-busycal" --catalog > "$stage/$package/catalog.json"
# rename(2) publishes only a complete directory. A concurrent installation
# of the same version wins once; both installers verify that published copy.
/usr/bin/python3 - "$stage/$package" "$dir/$package" <<'PYTHON'
import errno
from pathlib import Path
import sys
try:
    Path(sys.argv[1]).rename(sys.argv[2])
except OSError as error:
    if error.errno not in (errno.ENOTEMPTY, errno.EEXIST):
        raise
PYTHON
if [ -d "$stage/$package" ]; then
    cmp "$stage/$package/$bridge" "$dir/$package/$bridge"
    cmp "$stage/$package/dist/tool-metadata.json" "$dir/$package/dist/tool-metadata.json"
    mv -f "$stage/$package/catalog.json" "$dir/$package/catalog.json"
fi
mv -f "$stage/imcp-busycal" "$dir/imcp-busycal"
echo "BusyCal MCP $version installed. Enable BusyCal in iMCP Next settings."
