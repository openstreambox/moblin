// The published cacophony test vectors for Noise with 25519, ChaChaPoly and
// SHA-256, the same subset the hub checks its engine against
// (server/hub/fixtures/noise-vectors.json of the reference hub).
// Source: cacophony vectors (https://github.com/haskell-cryptography/cacophony, vectors/cacophony.txt), subset for 25519_ChaChaPoly_SHA256

let hubNoiseVectorsJson = """
{
 "source": "cacophony vectors (https://github.com/haskell-cryptography/cacophony, vectors/cacophony.txt), subset for 25519_ChaChaPoly_SHA256",
 "vectors": [
  {
   "protocol_name": "Noise_NN_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "9223fec1b892ec9d0dc2fb3bbeb261f170d1ea679f9c44ccf34aa131b4f5d97e",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79444c756477696720766f6e204d69736573"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f144808843a0ff96bdf86b579ef7dbf94e812a7470b903c20a85a87e3a1fe863264ae547"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "eb1a3e3d80c1792b1bb9cb0e1382f8d8322bfb1ca7c4c8517bb686"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "c781b198d2a974eb1da2c7d518c000cf6396de87ca540963c03713"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "c77048eb6919fdfe8fe45842bfc5b8d1ff50d1e20c717453ccdfe6176d805b996d"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "61834d7069dcfb7a1adf8d5ac910f83fa04c73a67789895c6f5f995c5db2ce88e49b124178"
    }
   ]
  },
  {
   "protocol_name": "Noise_NK_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "2efa38a9c7c93ac98f3a097af25c2f58b9e7673787717bc27e98827118c2c1a5",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79448134d00711fdb390a0d178fa008f6d47d2891e5ea18ae136c3b4c23ac384efb0"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f1448088438ea16e3701bc0d77744f117bee22451c9afa7f4cdbbcff00c04a8ee0913c88"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "a62de29ce27cb80245d440d986ed816c156e9d757d7008df2198b0"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "174a35f11c689f4530d7208618e0564ae12f2f50ba8eb4df5382ff"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "337e475ebb8eae60f91974c4e455a5af38d1d8628d1803b160d60442874b0a1777"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "047e80e060b7bb08b53c5a23dfe9920cae135b9d1dc6302fc475003062723700366346ac9d"
    }
   ]
  },
  {
   "protocol_name": "Noise_KK_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "resp_remote_static": "6bc3822a2aa7f4e6981d6538692b3cdf3e6df9eea6ed269eb41d93c22757b75a",
   "handshake_hash": "24c6b51ecb76277140ca018b5985bc9f03de321dae2d34dcae433dafef0131d9",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79440177015efc1fe7a37c629af7120a96274e6ab7afcc9261901d0e09ae32a5bb96"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f144808843b274d3429adc47ca093ba63ef90f8da89fda108db471dccfa4894aa7b00003"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "966b05bc69ec01b8454d3160a214e6f24a3d884eb31ec2408af63f"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "0ad887fba4f611bbb4afe44ba3556b8164332ca7d5934634d63d80"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "012b28ae646ae7830e2c5472cb023eab071c1db3d8413ec69b513b83832f974c2d"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "bb3e6a48160d9c5971d37f975727294e0d868342db31832e54d07191ab0ca3c3703b5ed3d9"
    }
   ]
  },
  {
   "protocol_name": "Noise_IK_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "0b0f68fb0c27e03ce9b97565995ed4838cc0581b762ef72b062f6a546419fad7",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944718da798efbcd91528520204f904b9bd6c7413dccdc214d951e15253e39987f18146e8cd0873654207148333479d4d16c289f0294b29960a72f48e0b7bba2e89083169825e59642148d492020664ccf7"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f1448088435361e70b2ed446e6c9ec387d1d6b3b840f194e373979d241b203c4acafccf5"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "050e9f3c8fac16b68dbce8f8c4bfbf6617c897f9ada4aa29aa19c8"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "344233a6cabb7141d80f3da2fedc311d9646bbb0f505afe403a667"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "62cdeeb172ad7ade7aa7d9e069da5790f12331bfa00177787a1d0810c67dc3b2b4"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "029bead1b40992327044d409d9a1f3ad8f36c3c452775d557e18bbeb2e8dfcead32d514024"
    }
   ]
  },
  {
   "protocol_name": "Noise_XX_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "c8e5f64e846193be2a834104c2a009868d6c9f3bd3c186299888b488b2f1f58e",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79444c756477696720766f6e204d69736573"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884381cbad1f276e038c48378ffce2b65285e08d6b68aaa3629a5a8639392490e5b9bd5269c2f1e4f488ed8831161f19b7815528f8982ffe09be9b5c412f8a0db50f8814c7194e83f23dbd8d162c9326ad"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "c7195ffacac1307ff99046f219750fc47693e23c3cb08b89c2af808b444850a80ae475b9df0f169ae80a89be0865b57f58c9fea0d4ec82a286427402f113e4b6ae769a1d95941d49b25030"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "96763ed773f8e47bb3712f0e29b3060ffc956ffc146cee53d5e1df"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "3e40f15f6f3a46ae446b253bf8b1d9ffb6ed9b174d272328ff91a7e2e5c79c07f5"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "eb3f3515110702e047a6c9da4478b6ead94873c11c0f2d710ddb3f09fce024b3a58502ae3f"
    }
   ]
  },
  {
   "protocol_name": "Noise_NNpsk0_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "f4d03dc34495c95729ea6de9e1b59004b59733102488b3e24bc441e0be208eaf",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c794479b962b8aff8485742ac32f905ba45369e2465fb59e138a93d67a0d1266b6a54"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f144808843d6062704d5a9c422a8e834423f8c1feada7e8d0d910a1a2cd030fb584221e3"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "e632c3763d7669067383433197a3baddf146e9e70ad4b4e9e59e0f"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "64c6bee32ea91c8474bb4c21d7a700109ad45af77b29764ba5eb1e"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "e2fa0bed0603b62d3ccac2ecabbf3fe33f3e86514909b323361626266cb2471cc8"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "0c01dc9cec1fe4ddd692e8dd32188aa351088dc91183639a53b57aa4692b5ebdef8b8ca111"
    }
   ]
  },
  {
   "protocol_name": "Noise_NNpsk2_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "bb9704f2303bd8b98b40fdb2ee50c2a9a46d7d20ea4d0949ae3094e376b29b1c",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944d44698de33ea6b7eea8023b48a284404489f9976c5f03417e8e2d6db7ab6bb9f"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884361200acbacd001a0d19a826982488f52573687652551ca5e903db095fedc7a"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "5ac8678baf0ef0cf884ab3271236b7ee57a02519505f4a4be09b95"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "fe899e844ac0d348a3ab679b83c95fd1099f734a0dc085955adce2"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "f8800be62325c8bd6794f7e533bb90316c6ba569a4223e644175f4e5e458e840fd"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "2f60885aedcd5b5c142a3190208b540407ab4477528ea8d15bd795416575e58121098a4a9f"
    }
   ]
  },
  {
   "protocol_name": "Noise_NKpsk0_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "1609ef057bdd62c752b5960546a255a78aebff08c5f07ef2adaa1db8350e7077",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944190fec41487219f2069c3ba7b7f9521437045935231f0ed399dfd4baf6bd825b"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884385010e0c56e886e6da0c69aee7388bcf4000cc357af5ebd11a46a169a3712c"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "4beed26535f1a387c950fab9a162dc613cc5bf84e8a62653130b83"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "ceaffe71ce7f1bf7b080736d62e0579ce5dc1530a36e7df795a4cc"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "da927a272831394122d0f2fef3e16ddf0814c4878401135b44b1e23873b45b2929"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "4fed2b394fb4dbdc9cf863bc99ebb3397651d27bdd32e40d8f7fed109e46445c0fd66fc3f3"
    }
   ]
  },
  {
   "protocol_name": "Noise_NKpsk2_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "5a0c1a79a0b863fe5d000e829b7e4ffc76200e5c08082d4494968e3f47d0ff61",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944acda3057fb216b0fb4c6d571e776b426612636e99cf4ac1de41442fb2128ca29"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884330fcb4ab2b68a6f612414145258aa079533be57174ec7ae7c76845312a3f07"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "129789ee959ffef891a580c6fc073cf91d706e26602cc096c35d84"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "36b35298bc84e0a24644e309563b2d6c3f9a31dc142b122e0266db"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "4b080dfd53e42e3f45d96f75f15fdbcce95a75fb83c51ee366281528204c1bf0b4"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "0bce31a0c1c37626c3e4a0000afa7e4e06636e1bbc44fc1a24e18e373f07c8ad6e3a03b877"
    }
   ]
  },
  {
   "protocol_name": "Noise_XXpsk3_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "a477edf6a131bbdb54707f6ea30eab6cd935d9b560f0e5fd1f053a95a99669fb",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944c9f5ff0e8079630cb7e270c20bbf480821b77a384a645c71a2fd9b3db1c16a5f"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f144808843b123def17f71e6ae8e57e0e1dec5949c5f7415c6f33517398747d821a06dc23ad430aa1fd7381d46195c378a819fd574425462cbb2d4ca339e738a0b7001dc91423fbf55a99af0c6f1df21012ceb2f"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "52187316111b118d4c060364f7b975dc0809b2590779aff2d63113c564f11744493384db7bf32d5ae6686df6ab06d508d2e07caaf1d6afc010b978735fc78900e71ae1d314130d042e729a"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "eaedc672d4c21e0e2955758756fb98f194c4e90d5deb5b6cf30b27"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "522d543c5fe799d09a3d9da7ff54d0dc03c8af1dc7751d2ff708339d2290943e98"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "7d4e2c3873eef6a213b04e72f9df60a91666072d3544c5d96c34a09e2329b5030bee796741"
    }
   ]
  },
  {
   "protocol_name": "Noise_KKpsk0_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "resp_remote_static": "6bc3822a2aa7f4e6981d6538692b3cdf3e6df9eea6ed269eb41d93c22757b75a",
   "handshake_hash": "32afcdbb63cf90f25409090bc11f7546c534dfb03f37c1626a0cf758881e746f",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c794423f19812300a6051f02195db0722909fc920796814cfc886ab3a8083c66a5961"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884320acfe866b4ede922f007d89dbf507216d6aa8646c7fba098da374b1784d4b"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "d213fdd768eeef05ee236c6d2983b2029bb472567a5831f4ff592c"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "facf98016edcfc2566b16866935329b4da833dcd3bbb4173cf638e"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "f46e7b19ebc94d697afc64b7f7d78d9b89276a6fbd438985d68c5d0261f4d4b774"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "84119bc1a1a5f97a338c7affb30242cf3111e95c41a07d5e289b160015156a93cb70e8e73d"
    }
   ]
  },
  {
   "protocol_name": "Noise_KKpsk2_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "resp_remote_static": "6bc3822a2aa7f4e6981d6538692b3cdf3e6df9eea6ed269eb41d93c22757b75a",
   "handshake_hash": "7f3c5fdcdd3767e2835473a2683971490339f5bbeee82c3690bc606e14db70ed",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944babf6443250c604872e33233c3b9a29df5c6d334ae2d53f1bd7f0b265a716b37"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884366a1f5f0d79fe93ae476bd1897a7a8ae92764898aa5d49e07b5849f35865ba"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "2eb2686b8814a7c0178fe18bfeeafe3e07312d69486d45e6572546"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "eea5791a890cd573a5c2e2345a8f98b0d1f0727acd24584fcddde5"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "ab2e1a411abaaa3df9cb497dffe4cfb70af6c71f0815b3c33b35e22329dee72f3e"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "ed22a0392c6afbfd6a6adea92b1faf13c4df24072f7060a20b1500609621c6957ac86d82f9"
    }
   ]
  },
  {
   "protocol_name": "Noise_IKpsk1_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "3ad252ed6f724c52da3450383b7d8b806c183e1ef157bbe0465ad24997ec4717",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c7944ac58a6c31948ce200911c5b27b67f1c4d1bed490532dd94ed17164fcc5784d3730fc302b70cc0f19beedaeb56bd974c0e57d747d11534c746eb2a32ac3fde3e4cdf6c3a4705762a6c6ca664b3bc89490"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f144808843846a944a0652fb390d213d0700d5ae8fef7aad0ecc79a9216d15de5d7f3ee4"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "5d872673f64813a47a00369b15c8da92691605ad71ba019de8e718"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "2045266a750b6af2547f7eb1391058196b742d0aac4b3a1bcc1913"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "9ec47ed0e7628c7d7a4eed631b963740ac2fd754eadaa9232e99054af4f7b29174"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "310e359407350594cfb96eb4596e35677d4a71ceb42aa8cbba097bb9e7150b0d1bd749c4aa"
    }
   ]
  },
  {
   "protocol_name": "Noise_IKpsk2_25519_ChaChaPoly_SHA256",
   "init_prologue": "4a6f686e2047616c74",
   "init_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
   "init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
   "init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
   "resp_prologue": "4a6f686e2047616c74",
   "resp_psks": [
    "54686973206973206d7920417573747269616e20706572737065637469766521"
   ],
   "resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
   "resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
   "handshake_hash": "8310f86394dc0dabb40beb8210031556db4403ab1202db7034c526232147a700",
   "messages": [
    {
     "payload": "4c756477696720766f6e204d69736573",
     "ciphertext": "ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79442ec9b09893d0f510791784c10cbc959f25b1766e0def6e301d14fbca1c7790ac829b8b3674f5f649a5f0e98479662cbfbf2b2c47cd4b09fcd266cd29d7cb675f1808849707847840f6d178ec4d3733aa"
    },
    {
     "payload": "4d757272617920526f746862617264",
     "ciphertext": "95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f1448088439a1b3cebf680b2c74217fcb5eba4ff58a9468cd90c4aca6194f57479b379a7"
    },
    {
     "payload": "462e20412e20486179656b",
     "ciphertext": "a8fde7a0accec190cd306c5950d4fd8e04a205ec288aa747d8b347"
    },
    {
     "payload": "4361726c204d656e676572",
     "ciphertext": "59caddd9984a3bbe24c4fb31a2bd455b7eba3fa0980674b1a3a5f9"
    },
    {
     "payload": "4a65616e2d426170746973746520536179",
     "ciphertext": "3b9bfebd210c22ba0cff9de79b4007d7a552fffbf92616881faa8a883e25b80258"
    },
    {
     "payload": "457567656e2042f6686d20766f6e2042617765726b",
     "ciphertext": "f37512df1043d564d7c46ac85c53d3b6a9a05724bc297e7142808f217561651217fe85b782"
    }
   ]
  }
 ]
}
"""
