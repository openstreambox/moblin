#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=$(mktemp -d)
trap 'test -z "${server:-}" || kill "$server"; rm -rf "$out"' EXIT
if [ "$#" -gt 0 ]; then
    modules=$1
else
    npm install --prefix "$out" --ignore-scripts --no-audit --no-fund ws@8.22.1 > "$out/npm.log" 2>&1
    modules=$out
fi
swiftc -swift-version 6 -parse-as-library \
    "$root/Moblin/Hub/HubNoise.swift" "$root/Moblin/Hub/HubJoinLink.swift" \
    "$here/HubNoiseResponder.swift" -o "$out/responder"
node "$here/reconnect-server.mts" "$out/fixture.json" "$modules" "$out/responder" > "$out/server.log" &
server=$!
swiftc -swift-version 6 -parse-as-library \
    "$root/Moblin/Hub/HubNoise.swift" "$root/Moblin/Hub/HubJoinLink.swift" \
    "$root/Moblin/Hub/HubProtocol.swift" "$root/Moblin/Hub/HubWords.swift" \
    "$root/Moblin/Hub/HubAccess.swift" "$root/Moblin/Hub/HubCrew.swift" \
    "$root/Moblin/Hub/HubSeen.swift" "$root/Moblin/Hub/HubConnection.swift" "$root/Moblin/Hub/HubOwnership.swift" \
    "$root/Moblin/Hub/HubEvidence.swift" "$root/Moblin/Various/Settings/SettingsHub.swift" \
    "$here/RegressionSupport.swift" "$here/HubReconnectRegression.swift" -o "$out/reconnect"
"$out/reconnect" "$out/fixture.json" "$out/seen.json"
cat "$out/server.log"
