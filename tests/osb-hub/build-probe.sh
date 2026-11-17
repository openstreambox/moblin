#!/bin/sh
# Build the hub probe from the fork's own hub files (macOS, Xcode's swiftc).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${1:-$here/hub-probe}
swiftc -swift-version 6 -O -parse-as-library \
    "$root/Moblin/Hub/HubNoise.swift" \
    "$root/Moblin/Hub/HubJoinLink.swift" \
    "$root/Moblin/Hub/HubProtocol.swift" \
    "$root/Moblin/Hub/HubConnection.swift" \
    "$here/HubProbe.swift" \
    -o "$out"
echo "$out"
