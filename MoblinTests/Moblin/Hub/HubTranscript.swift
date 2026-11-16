// A transcript made with the hub's own engine (server/hub/noise.ts of the
// reference hub) with fixed keys: XXpsk0 and IK exactly as the
// hub protocol uses them (prologue "osb-hub/1", the ticket's pre-shared key,
// the protocol's payloads). XXpsk0 has no published vector, so this pins the
// Swift engine to the hub's byte for byte.

let hubTranscriptJson = """
{
 "keys": {
  "device_static": "a8abababababababababababababababababababababababababababababab6b",
  "device_ephemeral": "c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7",
  "hub_static": "101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f",
  "hub_ephemeral": "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f",
  "device_ephemeral2": "6061626364656667686969696969696969696969696969696969696969696969",
  "hub_ephemeral2": "7071727374757677787978787878787878787878787878787878787878787878"
 },
 "xxpsk0": {
  "ticket": "00112233445566778899aabbccddeeff",
  "psk": "44ea12d7e999e594c9afa3c27c5ca50a9e7fa737a36c83f3cd5f9e98ba1ff190",
  "hub_public": "d89e3bad79437dbed9f843418304f460ff05c7fe81fe4a9577a804cb9367ff66",
  "device_public": "e3712d851a0e5d79b831c5e34ab22b41a198171de209b8b8faca23a11c624859",
  "handshake_hash": "78dd5c0bb484b859bd9edb816869f7d088f7ed2f7777453bc5f85b4dad2cc25e",
  "messages": [
   {
    "payload": "7b2276223a317d",
    "ciphertext": "4d5bab89b0733d9d8dcecf04f321c90b761b7765a6bdb2bddbfad3e7abdf1f6680dec11adb13c2793f55e130677c8d69487d708b0b7301"
   },
   {
    "payload": "7b2276223a312c22687562223a22487562227d",
    "ciphertext": "79a631eede1bf9c98f12032cdeadd0e7a079398fc786b88cc846ec89af85a51a5120f929cceae93037060bbb650822e07643bf3d40661a30f406206c766e99de9e8cbae7050f54e5a23a9fbd84bf077472aac8d8cce322ad87e306576365e9c2be0f09ee232d73afdd15905ce42a6e5bebae7c"
   },
   {
    "payload": "7b2276223a312c226e616d65223a226950686f6e65203132222c226b696e64223a2270686f6e65227d",
    "ciphertext": "6ef8e8290b940d23d708b901bef430e12781109f40981e3e668dc80e02155606b4fddebf10248659c3131ca0d294fd95d83c0b1086d74d8a5c34c9836fcc6e1a75787e4fd61c21b7a212096f1831a6ec82d3e52630b6de660b4170227cea611ddd3e41a16357e19aec"
   },
   {
    "from": "hub",
    "payload": "7b2274797065223a2277656c636f6d65227d",
    "ciphertext": "09391142c62caf2b595d66cb504e59519d7073eb13b0d33aa57b74eec9e5ea82ff51"
   },
   {
    "from": "device",
    "payload": "7b226964223a312c2274797065223a2273746174652e676574227d",
    "ciphertext": "367888a09eeab82ec8b73a661d34fcb61646c9eb6673753f506fc1d590bcdabd02c215b587f1bcf715995a"
   }
  ]
 },
 "ik": {
  "handshake_hash": "ef3041c7998ba7ac2bed91e661a308377664a1359f1dc1e143c70901d367666a",
  "messages": [
   {
    "payload": "7b2276223a317d",
    "ciphertext": "86161af1751270d675dbb434bcab2a5c34bb29f373d286270ae96bbc059d5732d948c728bf8e700d9a92f7c08a46fce13cec768b3ad7b018779075c71013ed04fff41bab43b677c00123d37655dcb218ab8650da1e8ecb3bd682555c753c640b9dd08666f06d67"
   },
   {
    "payload": "7b2276223a317d",
    "ciphertext": "44bd8d8351798e1a8f66f4d8ba45b5789ed3283000997b841343c49e9817b75c34a358305efe21d0ae3cceef7f57dba21d0183e0587f35"
   }
  ]
 }
}
"""
