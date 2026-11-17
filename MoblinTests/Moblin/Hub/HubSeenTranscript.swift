import Foundation


let hubSeenTimes: [Int64] = [1000000, 1001000, 1002000]
let hubSeenNow: Int64 = 1005500

let hubSeenStates = #"""
[
 {
  "continuity": {
   "phase": "steady",
   "route": "hub",
   "standby": {
    "acknowledged_at": "2026-11-17T16:23:58.989Z",
    "behind_ms": 0,
    "clock_offset_ms": 2,
    "state": "current"
   },
   "viewer_effect": "unknown"
  },
  "devices": [
   {
    "allowed": true,
    "feed": true,
    "id": "dev-43209cb57af5",
    "joined_at": "2026-11-17T16:23:58.947Z",
    "kind": "pc",
    "mobile_relay": null,
    "name": "Owner's PC",
    "online": true,
    "role": "admin",
    "runs_stream": false
   },
   {
    "allowed": true,
    "feed": true,
    "id": "dev-679e438d7720",
    "joined_at": "2026-11-17T16:23:58.996Z",
    "kind": "phone",
    "mobile_relay": null,
    "name": "iPhone",
    "online": true,
    "role": "admin",
    "runs_stream": false
   }
  ],
  "feeds": [
   {
    "black": null,
    "device": "dev-43209cb57af5",
    "picture": null,
    "since": 1794932638948,
    "sound": null,
    "state": "listening"
   },
   {
    "black": null,
    "device": "dev-679e438d7720",
    "picture": null,
    "since": 1794932638996,
    "sound": null,
    "state": "listening"
   }
  ],
  "hub": {
   "access": {
    "seq": 6
   },
   "capabilities": [
    "hub-handover/2"
   ],
   "epoch": 1,
   "fingerprint": "MNYU737JbHtg4IOT3QJdKEVoocu6lVBinOHBHQq9UwE",
   "host": {
    "id": "relay",
    "name": "relay"
   },
   "instance": 0,
   "name": "Hub",
   "ownership": {
    "chain": [],
    "epoch": 1,
    "owner_key": "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E",
    "owner_keys": [
     "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E"
    ],
    "root": "MCowBQYDK2VwAyEA3syYt1U70zpxGNfBeSgPM9zlWV5pj7gSZpGf3OOFRJI"
   },
   "protocol": "osb-hub/1",
   "revision": 2,
   "standby_urls": [
    "ws://127.0.0.1:36851/hub/v1"
   ],
   "standbys": [
    {
     "access_seq": 5,
     "acknowledged_at": "2026-11-17T16:23:58.989Z",
     "answering": true,
     "behind_ms": 0,
     "clock_offset_ms": 2,
     "id": "desk",
     "name": "desk",
     "since": null,
     "state": "current",
     "urls": [
      "ws://127.0.0.1:36851/hub/v1"
     ]
    }
   ],
   "urls": [
    "ws://127.0.0.1:37185/hub/v1"
   ]
  },
  "invites": [],
  "mods": [],
  "session": {
   "id": "cc0b90029b681c41ee6098e14fd9f481",
   "live": "ready",
   "mixer": "fake",
   "output": {
    "frames": null,
    "since": 1794932638761,
    "state": "off",
    "target": "test-sink"
   },
   "privacy": {
    "generation": 0,
    "hidden": false,
    "hidden_by": null
   },
   "program": null,
   "program_since": null,
   "run_by": null,
   "since": "2026-11-17T16:23:58.764Z"
  }
 },
 {
  "continuity": {
   "phase": "steady",
   "route": "hub",
   "standby": {
    "acknowledged_at": "2026-11-17T16:23:59.019Z",
    "behind_ms": 0,
    "clock_offset_ms": 3,
    "state": "current"
   },
   "viewer_effect": "unknown"
  },
  "devices": [
   {
    "allowed": true,
    "feed": true,
    "id": "dev-43209cb57af5",
    "joined_at": "2026-11-17T16:23:58.947Z",
    "kind": "pc",
    "mobile_relay": null,
    "name": "Owner's PC",
    "online": true,
    "role": "admin",
    "runs_stream": false
   },
   {
    "allowed": true,
    "feed": true,
    "id": "dev-679e438d7720",
    "joined_at": "2026-11-17T16:23:58.996Z",
    "kind": "phone",
    "mobile_relay": null,
    "name": "iPhone",
    "online": true,
    "role": "admin",
    "runs_stream": false
   },
   {
    "allowed": true,
    "feed": false,
    "id": "dev-931ef7650723",
    "joined_at": "2026-11-17T16:23:59.025Z",
    "kind": "helper",
    "mobile_relay": null,
    "name": "Kim's laptop",
    "online": true,
    "role": "helper",
    "runs_stream": false
   }
  ],
  "feeds": [
   {
    "black": null,
    "device": "dev-43209cb57af5",
    "picture": null,
    "since": 1794932638948,
    "sound": null,
    "state": "listening"
   },
   {
    "black": null,
    "device": "dev-679e438d7720",
    "picture": null,
    "since": 1794932638996,
    "sound": null,
    "state": "listening"
   }
  ],
  "hub": {
   "access": {
    "seq": 8
   },
   "capabilities": [
    "hub-handover/2"
   ],
   "epoch": 1,
   "fingerprint": "MNYU737JbHtg4IOT3QJdKEVoocu6lVBinOHBHQq9UwE",
   "host": {
    "id": "relay",
    "name": "relay"
   },
   "instance": 0,
   "name": "Hub",
   "ownership": {
    "chain": [],
    "epoch": 1,
    "owner_key": "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E",
    "owner_keys": [
     "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E"
    ],
    "root": "MCowBQYDK2VwAyEA3syYt1U70zpxGNfBeSgPM9zlWV5pj7gSZpGf3OOFRJI"
   },
   "protocol": "osb-hub/1",
   "revision": 2,
   "standby_urls": [
    "ws://127.0.0.1:36851/hub/v1"
   ],
   "standbys": [
    {
     "access_seq": 7,
     "acknowledged_at": "2026-11-17T16:23:59.019Z",
     "answering": true,
     "behind_ms": 0,
     "clock_offset_ms": 3,
     "id": "desk",
     "name": "desk",
     "since": null,
     "state": "current",
     "urls": [
      "ws://127.0.0.1:36851/hub/v1"
     ]
    }
   ],
   "urls": [
    "ws://127.0.0.1:37185/hub/v1"
   ]
  },
  "invites": [],
  "mods": [],
  "session": {
   "id": "cc0b90029b681c41ee6098e14fd9f481",
   "live": "ready",
   "mixer": "fake",
   "output": {
    "frames": null,
    "since": 1794932638761,
    "state": "off",
    "target": "test-sink"
   },
   "privacy": {
    "generation": 0,
    "hidden": false,
    "hidden_by": null
   },
   "program": null,
   "program_since": null,
   "run_by": null,
   "since": "2026-11-17T16:23:58.764Z"
  }
 },
 {
  "continuity": {
   "phase": "steady",
   "route": "hub",
   "standby": {
    "acknowledged_at": "2026-11-17T16:23:59.328Z",
    "behind_ms": 25,
    "clock_offset_ms": 2,
    "state": "behind"
   },
   "viewer_effect": "unknown"
  },
  "devices": [
   {
    "allowed": true,
    "feed": true,
    "id": "dev-43209cb57af5",
    "joined_at": "2026-11-17T16:23:58.947Z",
    "kind": "pc",
    "mobile_relay": null,
    "name": "Owner's PC",
    "online": true,
    "role": "admin",
    "runs_stream": false
   },
   {
    "allowed": true,
    "feed": true,
    "id": "dev-679e438d7720",
    "joined_at": "2026-11-17T16:23:58.996Z",
    "kind": "phone",
    "mobile_relay": null,
    "name": "iPhone",
    "online": true,
    "role": "admin",
    "runs_stream": false
   }
  ],
  "feeds": [
   {
    "black": null,
    "device": "dev-43209cb57af5",
    "picture": null,
    "since": 1794932638948,
    "sound": null,
    "state": "listening"
   },
   {
    "black": null,
    "device": "dev-679e438d7720",
    "picture": null,
    "since": 1794932638996,
    "sound": null,
    "state": "listening"
   }
  ],
  "hub": {
   "access": {
    "seq": 9
   },
   "capabilities": [
    "hub-handover/2"
   ],
   "epoch": 1,
   "fingerprint": "MNYU737JbHtg4IOT3QJdKEVoocu6lVBinOHBHQq9UwE",
   "host": {
    "id": "relay",
    "name": "relay"
   },
   "instance": 0,
   "name": "Hub",
   "ownership": {
    "chain": [],
    "epoch": 1,
    "owner_key": "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E",
    "owner_keys": [
     "MCowBQYDK2VwAyEA7UkoxijRwsbq6QM4kFmVYSlZJzpcY_k2NsFGFKyHN9E"
    ],
    "root": "MCowBQYDK2VwAyEA3syYt1U70zpxGNfBeSgPM9zlWV5pj7gSZpGf3OOFRJI"
   },
   "protocol": "osb-hub/1",
   "revision": 2,
   "standby_urls": [
    "ws://127.0.0.1:36851/hub/v1"
   ],
   "standbys": [
    {
     "access_seq": 8,
     "acknowledged_at": "2026-11-17T16:23:59.328Z",
     "answering": false,
     "behind_ms": 24,
     "clock_offset_ms": 2,
     "id": "desk",
     "name": "desk",
     "since": "2026-11-17T16:23:59.359Z",
     "state": "behind",
     "urls": [
      "ws://127.0.0.1:36851/hub/v1"
     ]
    }
   ],
   "urls": [
    "ws://127.0.0.1:37185/hub/v1"
   ]
  },
  "invites": [],
  "mods": [],
  "session": {
   "id": "cc0b90029b681c41ee6098e14fd9f481",
   "live": "ready",
   "mixer": "fake",
   "output": {
    "frames": null,
    "since": 1794932638761,
    "state": "off",
    "target": "test-sink"
   },
   "privacy": {
    "generation": 0,
    "hidden": false,
    "hidden_by": null
   },
   "program": null,
   "program_since": null,
   "run_by": null,
   "since": "2026-11-17T16:23:58.764Z"
  }
 }
]
"""#

let hubSeenHello = #"""
{
 "removed": [
  {
   "access_seq": 9,
   "ago_ms": 3500,
   "device": "dev-931ef7650723",
   "name": "Kim's laptop"
  }
 ],
 "seen": {
  "access_seq": 9
 },
 "v": 1
}
"""#
