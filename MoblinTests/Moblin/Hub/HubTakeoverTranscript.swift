import Foundation

let hubTakeoverTranscript = #"""
{
 "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
 "hubs": {
  "h3": {
   "epoch": 3,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 3,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2",
      "urls": [
       "wss://h2.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "ET9ZCepfq7X7SNnvS3jALQ7EtU_m4eb8GQDGo6FvbSLOYtD4y8MWaazUCtFQSNRMIb3iRpKphNZFpeGyzsEwDQ"
     }
    ]
   }
  },
  "h4": {
   "epoch": 4,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 4,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2",
      "urls": [
       "wss://h2.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "ET9ZCepfq7X7SNnvS3jALQ7EtU_m4eb8GQDGo6FvbSLOYtD4y8MWaazUCtFQSNRMIb3iRpKphNZFpeGyzsEwDQ"
     },
     {
      "v": 2,
      "epoch": 4,
      "from": "h2",
      "to": "h2m",
      "urls": [
       "wss://h2m.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "d04872ded3c92841f7fc989292f519ef5f07fd1256ce2305fe638559606fbaee",
      "checkpoint": "cp-4",
      "kind": "transfer",
      "signature": "ixFpJ0g_UbM6UuP-7GA6ZRiYqtKPZtFoK3mI5NP_pX5y82NN5KS6Mh5x0WSSoQBCU73j9MVP3r_SNiwQNE6wBw"
     }
    ]
   }
  },
  "h1000": {
   "epoch": 1000,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 1000,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2",
      "urls": [
       "wss://h2.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "ET9ZCepfq7X7SNnvS3jALQ7EtU_m4eb8GQDGo6FvbSLOYtD4y8MWaazUCtFQSNRMIb3iRpKphNZFpeGyzsEwDQ"
     },
     {
      "v": 2,
      "epoch": 1000,
      "from": "h2",
      "to": "h3",
      "urls": [
       "wss://h3.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "d04872ded3c92841f7fc989292f519ef5f07fd1256ce2305fe638559606fbaee",
      "checkpoint": "cp-tk",
      "kind": "takeover",
      "fenced": true,
      "signer": "MCowBQYDK2VwAyEAgTl3Dqh9F19Wo1Rmw0x-zMuNipG07jeiXfYPW4_Js5Q",
      "signature": "PsnZ7-l7YoJIc0jmrpZ3UqZ7EvlqHphElNH618D2wgzpn2pXITApwWTYvg-jk7iUTqrlpHN-3alX7e-AQG0cBg"
     }
    ]
   }
  },
  "h1001": {
   "epoch": 1001,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 1001,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2",
      "urls": [
       "wss://h2.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "ET9ZCepfq7X7SNnvS3jALQ7EtU_m4eb8GQDGo6FvbSLOYtD4y8MWaazUCtFQSNRMIb3iRpKphNZFpeGyzsEwDQ"
     },
     {
      "v": 2,
      "epoch": 1000,
      "from": "h2",
      "to": "h3",
      "urls": [
       "wss://h3.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "d04872ded3c92841f7fc989292f519ef5f07fd1256ce2305fe638559606fbaee",
      "checkpoint": "cp-tk",
      "kind": "takeover",
      "fenced": true,
      "signer": "MCowBQYDK2VwAyEAgTl3Dqh9F19Wo1Rmw0x-zMuNipG07jeiXfYPW4_Js5Q",
      "signature": "PsnZ7-l7YoJIc0jmrpZ3UqZ7EvlqHphElNH618D2wgzpn2pXITApwWTYvg-jk7iUTqrlpHN-3alX7e-AQG0cBg"
     },
     {
      "v": 2,
      "epoch": 1001,
      "from": "h3",
      "to": "h4",
      "urls": [
       "wss://h4.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "4e678ed001fa6934d3281d31500874cc6475916865021f4e72d1c5dafe0e9709",
      "checkpoint": "cp-1001",
      "kind": "transfer",
      "signature": "wreDMQ5G5MK_-q6AV5458BIRjpO8XXG8SyP0CfUDdKWwSObnDK0bettmQvde_f49VZo2LKMDwvfJiI5m-cpjCQ"
     }
    ]
   }
  },
  "h1001base": {
   "epoch": 1001,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 1001,
    "chain": [
     {
      "v": 2,
      "epoch": 1001,
      "from": "h3",
      "to": "h4",
      "urls": [
       "wss://h4.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "4e678ed001fa6934d3281d31500874cc6475916865021f4e72d1c5dafe0e9709",
      "checkpoint": "cp-1001",
      "kind": "transfer",
      "signature": "wreDMQ5G5MK_-q6AV5458BIRjpO8XXG8SyP0CfUDdKWwSObnDK0bettmQvde_f49VZo2LKMDwvfJiI5m-cpjCQ"
     }
    ],
    "base": {
     "v": 2,
     "kind": "base",
     "epoch": 1000,
     "owner": "h3",
     "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
     "previous": "4e678ed001fa6934d3281d31500874cc6475916865021f4e72d1c5dafe0e9709",
     "signature": "Xe7K5zrdNllzne5zNTt6MO7eYjMr6Mhopm8Wyjog3-78Stv8Ov1mB4Q3l3JJvtvYVA4JE0BsX69dlrxIZdjcDw"
    }
   }
  },
  "forkedTransfer": {
   "epoch": 3,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 3,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2b",
      "urls": [
       "wss://h2b.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "4lPuFpOWwZIY_Gu2kGnMZkg1S0dNCCbx4qIRS9ZFqQ1NzX1SbjD4D208d-gn6ux9WY78koYhjyL_Il9lgbcRBw"
     }
    ]
   }
  },
  "forkedTakeover": {
   "epoch": 1000,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 1000,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2b",
      "urls": [
       "wss://h2b.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "4lPuFpOWwZIY_Gu2kGnMZkg1S0dNCCbx4qIRS9ZFqQ1NzX1SbjD4D208d-gn6ux9WY78koYhjyL_Il9lgbcRBw"
     },
     {
      "v": 2,
      "epoch": 1000,
      "from": "h2b",
      "to": "h3b",
      "urls": [
       "wss://h3b.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "b85c191919eb02bf2195a013347ee7c2a4310defb190e8545178b52f6d709642",
      "checkpoint": "cp-tk",
      "kind": "takeover",
      "fenced": true,
      "signer": "MCowBQYDK2VwAyEAgTl3Dqh9F19Wo1Rmw0x-zMuNipG07jeiXfYPW4_Js5Q",
      "signature": "vXR8su6LA8HES7B5XEMTWajLdE-144gIdyhuEsYJ0v66nqp-n5fFVERJW8kzLMqKCGgJ6GhVITY1hHm3NhKLDg"
     }
    ]
   }
  },
  "tampered": {
   "epoch": 1000,
   "ownership": {
    "root": "MCowBQYDK2VwAyEAiojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w",
    "epoch": 1000,
    "chain": [
     {
      "v": 2,
      "epoch": 2,
      "from": "h0",
      "to": "h1",
      "urls": [
       "wss://h1.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "",
      "checkpoint": "cp-2",
      "kind": "transfer",
      "signature": "oFYHV2J3mbg75LBoY7iB0RYaTZ1NdgFCq5XVsFXAtZItp9xmQMJesupk280SbcIY0Ct6ZXzJ_m_MEW2QwiNkAQ"
     },
     {
      "v": 2,
      "epoch": 3,
      "from": "h1",
      "to": "h2",
      "urls": [
       "wss://h2.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "55ee007acde26d73c30fc9a15507936ea83eaa1c7ec0516de4bc913aeeb2f416",
      "checkpoint": "cp-3",
      "kind": "transfer",
      "signature": "ET9ZCepfq7X7SNnvS3jALQ7EtU_m4eb8GQDGo6FvbSLOYtD4y8MWaazUCtFQSNRMIb3iRpKphNZFpeGyzsEwDQ"
     },
     {
      "v": 2,
      "epoch": 1000,
      "from": "h2",
      "to": "h3",
      "urls": [
       "wss://h3.example/hub/v1"
      ],
      "hubKey": "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20",
      "previous": "d04872ded3c92841f7fc989292f519ef5f07fd1256ce2305fe638559606fbaee",
      "checkpoint": "cp-tk",
      "kind": "takeover",
      "fenced": true,
      "signer": "MCowBQYDK2VwAyEAgTl3Dqh9F19Wo1Rmw0x-zMuNipG07jeiXfYPW4_Js5Q",
      "signature": "PsnZ7-l7YoJIc0jmrpZ3UqZ7EvlqHphElNH618D2wgzpn2pXITApwWTYvg-jk7iUTqrlpHN-3alX7e-AQG0cAA"
     }
    ]
   }
  }
 },
 "agreedSeq": 46,
 "agreedDevices": [
  {
   "id": "dev-owner-a",
   "name": "Owner A"
  },
  {
   "id": "dev-phone-b",
   "name": "Phone B"
  },
  {
   "id": "dev-helper",
   "name": "Helper"
  }
 ],
 "waitingSeq": 46,
 "waitingDevices": [
  {
   "id": "dev-owner-a",
   "name": "Owner A"
  }
 ],
 "before": {
  "seq": 50,
  "devices": [
   {
    "id": "dev-owner-a",
    "name": "Owner A"
   },
   {
    "id": "dev-phone-b",
    "name": "Phone B"
   },
   {
    "id": "dev-helper",
    "name": "Helper"
   }
  ]
 }
}
"""#
