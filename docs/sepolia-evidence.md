# Sepolia evidence run (v0.1.3 build)

Deployment of the AIFP reference stack on Sepolia (chain id 11155111) from the v0.1.3 build and the two-phase run
of boundary cases 1, 4, 5, 8, 9 and 11 with three actors, following `docs/sepolia-runbook.md`. The
machine-readable records are `deployments/11155111.json`, `deployments/11155111.cases.json` and
`deployments/11155111.cases.phase2.json`. The first deployment (v0.1.1 build, 2026-11-08) is recorded in
`docs/sepolia-evidence-v0.1.1.md` and `deployments/archive/v0.1.1/`; its contracts remain on chain.

Every transaction below was produced by the unmodified scripts `script/Deploy.s.sol` and `script/Cases.s.sol`,
rehearsed on a local Anvil node with the same sender nonces and then relayed to Sepolia as signed raw
transactions, so the addresses, calldata and identifiers are the ones the scripts computed. All transactions in
this document are included with status `0x1` unless stated otherwise.

## Source and build

| Item | Value |
| --- | --- |
| Source | this repository, `assets/erc-aifp/contracts/` as filed with ERC-8489 after the second review round (v0.1.3; `assets/erc-8489/contracts/` in ethereum/ERCs). Relative to the v0.1.1 deployment: leaf calls judged on raw return data with a fixed gas bound (`leafGasLimit()` = 1,000,000) and a pre-call headroom check (`AIFP_InsufficientGas`), no outcome for an evaluation that did not complete (`AIFP_EvaluationFailed`), tree-shaped predicates of bounded depth, `evaluateWithBinding`, `bindingId` in event records, management events naming caller, authority kind and authorizing binding, `previewAdmission` mirroring `admit`, re-admission only in an Active channel, and an objection window that confirms integrity through `stateChanges` |
| Compiler | solc 0.8.28, EVM version `cancun`, optimizer enabled with 200 runs, no IR pipeline (`foundry.toml`) |
| Build check | the CBOR metadata hash at the end of each deployed runtime equals the one in the local `forge build` artifact for the same contract (seven of seven) |
| Deployer / channel authority (A) | `0xfaf78B3D533411Bb921d119a9881C04060869065` |
| Actor B | `0x70C8e57fF73E36761127d28Ed29D8f8cfB9831b6` |
| Actor C | `0x863D46f2c932122bAc1032A4b41b4C29d99229DC` |
| Clock | `mode=timestamp` (ERC-6372), one clock domain for all registries |

The keys are the same throwaway keys as in the v0.1.1 run; channel authority and family control remain on key A.

## Deployed contracts

| Contract | Address | Deploy tx | Block | Gas used | Runtime bytes | Runtime keccak256 |
| --- | --- | --- | --- | --- | --- | --- |
| `AIFPParadigmRegistry` | `0x8bE1cF22C1f1ff6921652d84DF830a90b23C8633` | `0x55c17665fb697184a587908bbf7889e0e1d0bfd27c8444017137cd8e39079328` | 12131066 | 6,177,093 | 3860 | `0x75aa09dd70ff5d6e056eaff42249bde7b7f7e06e4073fc6b43a6f7a1f5bde0d8` |
| `AIFPCompositeVerifier` | `0xc577aC8316d8D6bf8edb77b15b690Ca7cC185a5C` | `0x5cf130e151bf667eefbe7238e05791535dc35b63dc5a362f76ac10a26a4b2a79` | 12131066 | 5,385,238 | 3348 | `0xad6366d7a554d27d1f65fecf4077434fa16ca0558d79e1e8e524e4f5d3280204` |
| `AIFPChannelRegistry` | `0xb10b4c241B9a4feF05aC9d33d8B6c09D7A91aB6e` | `0xa7996d3e553c9074b185e9d775fe48dbc1c34eb15b5594149c39db8accb0b4b3` | 12131296 | 15,767,280 | 10061 | `0x2de1e002e1bccf9890da8ac8d94b370bc01a6bcd0d5b4a7ae7bd7002ba3c21f3` |
| `AIFPParticipationRegistry` | `0xA6242197F6DBD8A8CF8753742B7E0168EE617A83` | `0x26fd8e693375dcc0b38748d50c64cea5fbec486e715cfa5192eb731eb5136324` | 12131296 | 21,668,665 | 13878 | `0x47de70aa556533e357c0cc6ab202ecc8c96182795004fb159725335e7f6a920f` |
| `AIFPChannelRegistry.setParticipationRegistry` | - | `0xb5f3a709e29096204d2c93786f0f45324e49f395037aab8aaa002c8a37869d3f` | 12131317 | 126,157 | - | - |
| `AIFPEventAnchor` | `0x74d5AdD218C3A33825AD3e450173960a1E4FAd5c` | `0x9ab0dfca625bdc8c0d848d6deda21084c9d7ed6e4aaae1c4d0e0270fc33ea1c9` | 12131317 | 6,491,280 | 4062 | `0xd4eb6bc1204fe68003dc170cb6c4d18c2f813b9fafbbccc7afab1020d72eb1f4` |
| `AIFPObjectionWindow` | `0x82382184983ABe091b2Af8f20006553DCeBB0981` | `0x15b25ee269eb945350eea99c98172c7c07fab39c6e559ee9554438d8e7d4efa7` | 12131317 | 8,173,554 | 5150 | `0x9a80ccc0097eaa8325970d37418cbdb7f590f3d70c393b938a542937cd771cb2` |
| `AIFPSubjectSet` (roster) | `0xDE93b6b9245eF5ec352ADdFDbC1b1a2B702b755C` | `0xd61f178143269fa6c394424b20427edacf02ec4a7e62cc1faf6637feee9d74d9` | 12131317 | 1,925,486 | 1038 | `0x8c58e4175a9e3233b6691fd183225e817e03f5785c8a931a692334544cbc5b8c` |

Deployer nonces 95 to 102. Creation cost follows the runtime size as in the v0.1.1 run (about 1,564 gas per
runtime byte on Sepolia): the paradigm registry and the roster are unchanged, the channel and participation
registries grew, the verifier, the anchor and the window shrank. The base fee stayed below 20 wei throughout, so
the figures are gas, not cost.

### Note on gas limits for the v0.1.3 case transactions

Since v0.1.3 the composite verifier checks, before every leaf call, that the leaf bound plus a margin is still
available and reverts with `AIFP_InsufficientGas` otherwise. The gas is checked, not consumed: on the local rehearsal an
admission that runs one leaf uses about 380,000 gas but needs a limit above about 1,110,000 to pass the check.
Foundry's broadcast sets the limit at 130 percent of the consumed gas by default, which is far below that, so the
rehearsal ran `Cases.s.sol` with `--gas-estimate-multiplier 400` and every case transaction was relayed with a
limit of 3,000,000. `eth_estimateGas`, which searches for the limit at which the call succeeds, gives the exact
figure: 1,113,138 for `previewAdmission` of B's allowlist admission in the link, read on Sepolia (block 12131392).
The same `eth_call` under a limit of 500,000, 1,000,000 or 1,100,000 reverts with `AIFP_InsufficientGas`
(`0xc9b4ddbd`) and returns `0` (SATISFIED) under 1,200,000 or 3,000,000; a preview with no external leaf (the
open v1 rules predicate) returns `0` under every limit tried. This is the behaviour Section 6.3 of the
specification asks for: the gas supplied to an evaluation decides whether it happens, never what it says.

### Abandoned first attempt

A first relay of the same plan earlier on 2026-11-14 (deployer nonces 54 to 94, B nonces 10 to 18; nothing of C's
was mined) was abandoned: the relay overran `AIFP_DELAY` (3,000 seconds), so two of B's transactions were mined
after `effectiveAt` and reverted (`AIFP_PredicateMismatch`: an admission under the v1 rules evaluated after the v2
rules had taken effect, and the anchor that depended on it), and two of C's transactions were rejected by the RPC
endpoint as malformed hex - a copy error in the relay, not in the signed transactions; the relay below carried a
length and checksum check on every payload. Its seven contracts are the same build at
`0xa9de6e97e340c06f499c4e6ef33401176d91d93b`, `0x9af38dc53ab8b914acfc59a381988defb47244ed`,
`0x2cdf21c46477227f7a8cfdd7ac61072165a993bf`, `0x1aadfcf54603a90a6b09eb9cd4645a618e020c07`,
`0x44eea0d46cfca875b21d66c50c02456963173ac2`, `0x8a7e308fe9740d8a87f92b420aefe9ebad964afe` and
`0x26313b762f7cb47e44dfce62014c9b7058a249b1`; they hold the partial state of that attempt and are not part of
this record. The run below used `AIFP_DELAY=3600` seconds.

## Phase 1

All 45 phase-1 transactions were included between blocks 12131330 and 12131372 with status `0x1`: actor A
registered eight paradigms, opened seven channels, granted roles, published the first anchor of the room (case 9),
scheduled the panel-to-club adoption and the rule update (`effectiveAt` 1794641402, `AIFP_DELAY` 3600 seconds) and opened the
objection window (deadline 1794645002); actor B admitted itself as responder in the one-to-one link (case 1),
as bidder in the tender (case 5) and as submitter under the v1 rules (case 8), anchored its sealed bid, the rules
post and the blackboard versions and recorded the room disclosure (case 9); actor C admitted itself as observer of
the talk (case 4) and as bidder in the tender and anchored its sealed bid. The identifiers that phase 2 reads back
are in `deployments/11155111.cases.json`. Every admission below used a gas limit of 3,000,000 and consumed between
1.33 and 1.45 million gas as Sepolia prices it (0.36 to 0.39 million on the local rehearsal; Sepolia charges
state-writing calls several times the local figure, as the v0.1.1 record notes); the block timestamps of the
phase-1 blocks run from 1794637776 (12131330) to 1794638280 (12131372).

The logs of these transactions carry what the second review round asked for. The `RoleGranted` of B's admission
in the link (tx `0xb4bef205…81fa`, binding `0x2635173e…ee91`) ends with `by` = `0x70C8e57f…31b6` (B itself),
`authorityKind` = 3 (`AUTHORITY_SUBJECT`) and `authorizingBinding` = 0; the `RoleGranted` of A's grant in the same
channel (tx `0x87f0873f…05d4`, binding `0xa3831b3a…bcca`) ends with `by` = `0xfaf78B3D…9065`, `authorityKind` = 0
(`AUTHORITY_CHANNEL`) and `authorizingBinding` = 0; and the `EventAnchored` of B's sealed bid in the tender (tx
`0xf4b3d90a…49ed`) names `bindingId` `0x355d6eb1…8cea`, the bidder binding under which B published.

| # | Actor | Nonce | Call | To | Block | Gas used | Tx |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | A | 103 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131330 | 804,598 | `0xfa0df38190fec341e9f1e0927977a75c62c55caec53c9449779c3a14250522cb` |
| 9 | A | 104 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131330 | 804,586 | `0x7eb23beb4b4c57ba95088f89279e1cd6d8a479b5ae5e7d4bf922cca693d13f3c` |
| 10 | A | 105 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131330 | 918,495 | `0x35938906609ed60abef50c281149fa6fcc386c46a2997a5c6052935e7307bd44` |
| 11 | A | 106 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131331 | 804,586 | `0x01c72d25901fb1dce6b36ea7645bac416a2f71bbb07559675548cd84578a7b6a` |
| 12 | A | 107 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131331 | 693,212 | `0xcf7d3aa1075da134e9f394a3539faef8bae075a585e76eef3ff59fd04f2c8d9f` |
| 13 | A | 108 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131331 | 804,598 | `0x08178404fa4104acff81335ac5be3ecd6f7d1e8818ce4d15c73e66a043b1582a` |
| 14 | A | 109 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131331 | 804,610 | `0x197afc50418ce0fcac970e097f29fa8d6ce796c0b8e11a56da4734200589d6ee` |
| 15 | A | 110 | `registerParadigm` | `0x8be1cf22c1f1ff6921652d84df830a90b23c8633` | 12131331 | 807,145 | `0x8ea0fc80d05c70995320a61a91de1864f58a81d5a592b9d7e2b5feac83079cf7` |
| 16 | A | 111 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 916,964 | `0x290e9442d627731a0a1fb0357230be8e20f7456328fd21d8fad7085f54c9aee4` |
| 17 | A | 112 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,044 | `0x093878e032d51908b2096945fc5d98890fea195e2330f8a1504c4af2e45b4805` |
| 18 | A | 113 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,068 | `0x824026df17382e3a243cc9518c1fc3dd7c5241671781524b22cab015e73f92e6` |
| 19 | A | 114 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,056 | `0x84836fd9f5fe7d87038d996dd2a8a2c1dbc644f9a21e976268bd2a4311ce81b3` |
| 20 | A | 115 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,044 | `0x5b9a8d7c86773dbf81fc659cbf6fd4116fad6c15fb8669c2b4d6f90b83cde574` |
| 21 | A | 116 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,092 | `0x43518805db706448e308baf071bd5842d6a53b4d235eaeef7ae3e084b81cd639` |
| 22 | A | 117 | `openChannel` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131331 | 819,092 | `0x749ca44ad0a4dd35cf7ad0d2e0b2b548bceac072aa56bd051a10178f3448d685` |
| 23 | A | 118 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131331 | 1,391,338 | `0x87f0873fff08f899ffde8c850fd7ff1af72cf1d806ad2d6cdd3f909c813b05d4` |
| 24 | A | 119 | `add` | `0xde93b6b9245ef5ec352addfdbc1b1a2b702b755c` | 12131331 | 239,737 | `0x2485eb48dd0fa5ad2a5194d6f7f602d10cdb883bc9d8c321b7bf7a3baf21dbcf` |
| 25 | A | 120 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,293,418 | `0x80b2970ed9861446e6e839aa93ee8f5b97e0b6d89e1bcdfdc1487a56f62daa42` |
| 26 | A | 121 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,185,114 | `0x13bbec2fbb9dcdb098fa14b65723fb1b6a307da14f142a1ba516f8228b8ea5f7` |
| 27 | A | 122 | `adoptParadigm` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131344 | 376,659 | `0x6e94e1640770f7c62a167dc5a5e2b540c788b0c3600664ce109db228fd9aaa39` |
| 28 | A | 123 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,185,114 | `0xece2e22b37cea5720f15cc303d9d751ebaa8a0cfa84a543dbb47f1fa22539db2` |
| 29 | A | 124 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,293,394 | `0xfcafca633abf616ea9e047881ebecbc7a1a44c42bbe697765b79909d8a9bc2bc` |
| 30 | A | 125 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,293,418 | `0xd9120ba3411e9908caed2b40932abc175f53600bb521ce551fdd621ac16cdab9` |
| 31 | A | 126 | `adoptParadigm` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131344 | 376,659 | `0xb6a876608b226937c36da9d11a88ceddd2283116f72af9dc55b238189067bc52` |
| 32 | A | 127 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131344 | 1,185,114 | `0xb0af055fc1b1a622669d3ede0a76af001d526e526f8d97fae7d8c43bbf9241e0` |
| 33 | A | 128 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,126 | `0x8f62c5b715bfb568ec695ca0a7e0b7315923c47da6ab1fa3801cd2188ea0e0ec` |
| 34 | A | 129 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,114 | `0xa4cd64e013e0777430782980702d7e327396104472fe0cdcb4a648988d47ac63` |
| 35 | A | 130 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,114 | `0xc61b75925f9008749e94be2aa890ec64441a4acf5ddc78617d7d9bb57897802a` |
| 36 | A | 131 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131345 | 1,068,237 | `0xb8853454f9feccb132368a0056845054108128ca554599610a8a1302e4a395d3` |
| 37 | A | 132 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,102 | `0x0d36ca1e79fbe5711f44892c5cb7514fafec528fcc72ccf6cc44d99cebbcd2bc` |
| 38 | A | 133 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,102 | `0x723d58df21c357c416b15105eda1accbc4d1353b8131c3987ca43fb22fc3cf6b` |
| 39 | A | 134 | `grant` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131345 | 1,185,102 | `0x57944a24e05d0ff3b817fddbf02e30747e0e2713e9d5c280c4af73445b01141e` |
| 40 | A | 135 | `open` | `0x82382184983abe091b2af8f20006553dcebb0981` | 12131345 | 639,222 | `0x99fd8477750d1ec9279ece8a83efb98176045f571370ab6e4bc998bb7e207ca8` |
| 41 | B | 19 | `admit` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131357 | 1,450,979 | `0xb4bef205287f066efac67bb031b4bde4f2724caacba6d9cb9cefc2b5070181fa` |
| 42 | B | 20 | `admit` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131371 | 1,335,734 | `0xce8d8ba0998453f6980668cbbc95ec282fca326b60764a5b2a64b48a30a8ed93` |
| 43 | B | 21 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131371 | 975,116 | `0xf4b3d90a07fa7fe88721b9563c0622e01990e2b653848b34e905da12babb49ed` |
| 44 | B | 22 | `admit` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131371 | 1,437,266 | `0xa954de6d6beb0d037c3b8cda69266a16c62920de2581feefc6fa9983d5aabe69` |
| 45 | B | 23 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131371 | 973,393 | `0xfb3328290557f9a9e103b6febb88e40859d8b88eed526d89d424925c92de316c` |
| 46 | B | 24 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131371 | 973,375 | `0x220bca869ad061c2b0411a5a559f46ffc257f5bfbaf708af03baf25d3e63a94f` |
| 47 | B | 25 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131372 | 755,626 | `0x9d44803547c5bf331d044aaa50225016e5c9ac119676796d0c85d47df5d6dcad` |
| 48 | B | 26 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131372 | 973,821 | `0xf1ab0f9f728b2b3f72f53d7755038d17abbec479d31cae1591c06a1bd6ded226` |
| 49 | B | 27 | `recordDisclosure` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131372 | 629,802 | `0x1a957b8ee6765e1296edcd55bc6b34cebfc14bb49e294fcfc899004e721a469d` |
| 50 | C | 7 | `admit` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131371 | 1,437,597 | `0x8979e71da1a0fd64a22c98b19cb0fae08ef5495e79625c79cef57394c16cedcd` |
| 51 | C | 8 | `admit` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131371 | 1,335,734 | `0xa1f27ccbb4d76ccaea5865c49058d241c8a7e81ec3b07cf4429ae4716d2339b7` |
| 52 | C | 9 | `anchor` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131372 | 975,116 | `0xc2da3795b7aeb7b989c74b692acdd8109b7973832ca85b481761355da97fda01` |

## Phase 2

### Read-outs taken on Sepolia before phase 2

The following values were read with `eth_call` against the deployed registries (outcome codes: 0 SATISFIED,
1 NOT_SATISFIED, 2 UNDETERMINABLE, 3 VERIFIER_ERROR; subject references are
`keccak256("eip155-address:11155111:<address>")`). The right-hand column was read after the scheduled adoptions had
taken effect and before any phase-2 transaction.

| Read | Before `effectiveAt` (block 12131392, chain time 1794638532) | After `effectiveAt`, before phase 2 (block 12131636, chain time 1794641496) |
| --- | --- | --- |
| `evaluate(talk, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 SATISFIED (history unchanged by the adoption) |
| `evaluate(talk, B, SUBMIT, 0, now)` | 0 SATISFIED | 2 UNDETERMINABLE (re-admission pending under the new epoch) |
| `evaluateWithBinding(talk, B, SUBMIT, 0, T)` | (0, `0x183a3135…85aa` = `bPanelist`) at both timepoints | (0, `bPanelist`) at `effectiveAt - 1`; (2, `0x0`) now: no binding decides a pending answer |
| `isPending(bPanelist, now)` / `isPending(cObserver, now)` | false / false | true / true |
| `evaluate(rules, B, SUBMIT, 0, effectiveAt - 1)` / `(…, now)` | 0 / 0 | 0 / 0 (the rules adoption does not require re-admission; B is revoked in phase 2) |
| `evaluate(talk, C, SUBMIT, 0, T)` / `evaluate(rules, C, SUBMIT, 0, T)` | 1 / 1 at both timepoints (C holds OBSERVE in the talk, nothing in the rules) | 1 / 1 |
| `previewAdmission(rules, C, SUBMIT, 0, openPredicate, [])` | 0 SATISFIED (v1 still in force) | reverts `AIFP_PredicateMismatch(0x15665969…13d8, 0xd9748b88…a91e)`: the v1 predicate is rejected by hash, not recorded as NOT_SATISFIED |
| `previewAdmission(link, B, RESPOND, 0, allowlistPredicate(roster), [])` with `gas` 500,000 / 1,000,000 / 1,100,000 | reverts `AIFP_InsufficientGas` (`0xc9b4ddbd`) | - |
| same call with `gas` 1,200,000 / 3,000,000; `eth_estimateGas` | 0 SATISFIED / 0 SATISFIED; 1,113,138 | - |
| `paradigmAt(talk, effectiveAt - 1)` / `paradigmAt(talk, now)`; `currentParadigm(talk)` | `pPanel` / `pPanel`; (`pPanel`, 1794637788) | `pPanel` / `pClub`; (`pClub`, 1794641402) |
| `disclosureCount(room)` | 1 (DISCLOSED) | 1 |
| `stateChanges(council)`; `integrityHolds(0)` | 0; true | 0; true |
| `window(0)` | status 0 OPEN, objectionRole 8, start 1794641402, deadline 1794645002, openedAt 1794637956, 0 objections, `stateChangesAtOpen` 0 | unchanged |
| `leafGasLimit()` | 1,000,000 | - |

### Phase 2 transactions

Phase 2 was broadcast in two parts once chain time had passed `effectiveAt`: the nine transactions that do not
depend on the objection-window deadline first (A confirms B's panelist re-admission, adds C to the roster, revokes
B's rules binding and records the RESTRICTED disclosure; B reveals its bid; C takes the floor by rule, re-proves
its observer binding, enters the tightened rules through the roster allowlist and reveals its bid), then `resolve`
after the deadline. All of them were included with status `0x1`. Between the two parts A sent 0.005 ETH to C at
nonce 140 (tx `0x6f0886fc10e3757f5e11a9c970e882766a2cac503ffd621340706cac6abdb0ff`, block 12131655): C's
balance covered the gas its two remaining transactions could consume but not the full `gas limit x max fee` the
transaction pool reserves for queued transactions, so `resolve` moved to nonce 141. Case transactions used a gas
limit of 3,000,000 as in phase 1.

| Actor | Nonce | Call | To | Block | Gas used | Tx |
| --- | --- | --- | --- | --- | --- | --- |
| A | 136 | `confirmReadmission(bPanelist)` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131645 | 319,121 | `0xcbbc9771b483b97ad133bc9c882d3068086087f73aa3c53207bd90aa1a8e56cd` |
| A | 137 | `roster.add(C)` | `0xde93b6b9245ef5ec352addfdbc1b1a2b702b755c` | 12131645 | 141,817 | `0x38022fc6a582772babe7a6c8b0c52bddccb7ff6625be0db910d222df44bf9f1b` |
| A | 138 | `revoke(bRules)` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131645 | 166,563 | `0xcf32034c48abb0873a14340609fbf19c0d803a1e7c04477585f269bf82774d5f` |
| A | 139 | `recordDisclosure(room, RESTRICTED, summary)` | `0xb10b4c241b9a4fef05ac9d33d8b6c09d7a91ab6e` | 12131645 | 589,166 | `0x00eaab0bba9b410801225d1b2f002ca5815b971e36286e3b8c85b34075e6ce61` |
| B | 28 | `anchor(tender, SUPERSEDE: reveal of B's bid)` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131645 | 980,929 | `0x4aa27986998dbec783115c94af50be096ee3afa75964efa6682defebf04c3e04` |
| C | 10 | `admit(talk, SUBMIT, openPredicate)` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131645 | 1,450,356 | `0x705893f6ecec2ec1ac521989334bb167db150434e1ef96f027ca7da9e4dcdbea` |
| C | 11 | `readmit(cObserver, openPredicate)` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131645 | 358,227 | `0x284880f6c23443f8da71bcf585c888c0c64701dc07f17dbc8223a5ab602916e6` |
| C | 12 | `admit(rules, SUBMIT, allowlistPredicate(roster))` | `0xa6242197f6dbd8a8cf8753742b7e0168ee617a83` | 12131656 | 1,446,879 | `0xbda45c637f6984f9179bcb3d02dd0a9a26d37d40b26ddb491f3a0aab3deac15c` |
| C | 13 | `anchor(tender, SUPERSEDE: reveal of C's bid)` | `0x74d5add218c3a33825ad3e450173960a1e4fad5c` | 12131657 | 980,917 | `0x2fb23cfa2141b1152f9835371993f773a01add0835e694506f7e356fc311daf1` |
| A | 141 | `resolve(windowId 0)` | `0x82382184983abe091b2af8f20006553dcebb0981` | 12131936 | 55,468 | `0xa51d24764ea572e85b0011c5258dd78239685069f9425c7308799ab88ba86f7d` |

### Read-outs after phase 2

Read with `eth_call` at block 12131939 (chain time 1794645156), after all ten phase-2 transactions. The
right-hand column repeats the value the Foundry rehearsal predicted for the same read
(`deployments/11155111.cases.phase2.json`).

| Read | On Sepolia | Expected (`Cases.s.sol` phase 2) |
| --- | --- | --- |
| `evaluate(talk, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 (`case4.bHistoryBeforeChange`) |
| `evaluate(talk, B, SUBMIT, 0, now)` | 0 SATISFIED (2 UNDETERMINABLE before `confirmReadmission`, see above) | 2 before confirmation (`case4.bPendingBeforeConfirm`), 0 after |
| `evaluateWithBinding(talk, B, SUBMIT, 0, now)` | (0, `bPanelist` `0x183a3135…85aa`): the confirmed binding decides again | the re-admitted binding keeps its identifier |
| `evaluate(rules, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 (`case8.bHistoryUnderV1`) |
| `evaluate(rules, B, SUBMIT, 0, now)` | 1 NOT_SATISFIED (revoked; history above untouched) | 1 (`case8.bNowAfterRevocation`) |
| `previewAdmission(rules, C, SUBMIT, 0, openPredicate, [])` | reverts `AIFP_PredicateMismatch(0x15665969…13d8, 0xd9748b88…a91e)` | rejected (`case8.oldRuleRejectedAfterChange` = 1) |
| `evaluate(talk, C, SUBMIT, 0, now)` / `(…, effectiveAt - 1)` | 0 / 1 (admitted by rule in phase 2; no SUBMIT role before) | admitted (`cSubmit`) |
| `evaluate(rules, C, SUBMIT, 0, now)` / `(…, effectiveAt - 1)` | 0 / 1 (admitted under v2 through the roster allowlist) | admitted (`cRules`) |
| `isPending(bPanelist, now)`, `isPending(cObserver, now)` | false, false | confirmed / re-admitted |
| `disclosureCount(room)` | 2 (DISCLOSED, then RESTRICTED) | 2 (`case9.disclosureRecords`) |
| `stateChanges(council)`; `integrityHolds(0)` | 0 (unchanged since the window opened); true | integrity confirmed, not presumed |
| `window(0).status` | 1 DEFAULT_TRIGGERED, 0 objections (`WindowResolved(0, 1, 0)` in the `resolve` receipt) | 1 (`windowStatus`) |

The sealed bids of B and C were revealed as anchors superseding the phase-1 commitments (B
`0x4aa27986…3e04`, C `0x2fb23cfa…daf1`). Final nonces after the run: A 142, B 29, C 14; the three keys retain
0.0033, 0.0022 and 0.0068 ETH respectively.

## Reproducing

1. `forge build` with the repository's `foundry.toml`; compare the metadata hash at the tail of
   `out/<Contract>.sol/<Contract>.json` `deployedBytecode` with `eth_getCode` of the addresses above.
2. Verify sources with Sourcify from a machine with network access to it, one command per contract:

```
forge verify-contract --chain sepolia --verifier sourcify 0x8bE1cF22C1f1ff6921652d84DF830a90b23C8633 assets/erc-aifp/contracts/AIFPParadigmRegistry.sol:AIFPParadigmRegistry
forge verify-contract --chain sepolia --verifier sourcify 0xc577aC8316d8D6bf8edb77b15b690Ca7cC185a5C assets/erc-aifp/contracts/AIFPCompositeVerifier.sol:AIFPCompositeVerifier
forge verify-contract --chain sepolia --verifier sourcify 0xb10b4c241B9a4feF05aC9d33d8B6c09D7A91aB6e assets/erc-aifp/contracts/AIFPChannelRegistry.sol:AIFPChannelRegistry --constructor-args $(cast abi-encode "constructor(address)" 0x8bE1cF22C1f1ff6921652d84DF830a90b23C8633)
forge verify-contract --chain sepolia --verifier sourcify 0xA6242197F6DBD8A8CF8753742B7E0168EE617A83 assets/erc-aifp/contracts/AIFPParticipationRegistry.sol:AIFPParticipationRegistry --constructor-args $(cast abi-encode "constructor(address,address,address)" 0xb10b4c241B9a4feF05aC9d33d8B6c09D7A91aB6e 0x8bE1cF22C1f1ff6921652d84DF830a90b23C8633 0xc577aC8316d8D6bf8edb77b15b690Ca7cC185a5C)
forge verify-contract --chain sepolia --verifier sourcify 0x74d5AdD218C3A33825AD3e450173960a1E4FAd5c assets/erc-aifp/contracts/AIFPEventAnchor.sol:AIFPEventAnchor --constructor-args $(cast abi-encode "constructor(address,address)" 0xb10b4c241B9a4feF05aC9d33d8B6c09D7A91aB6e 0xA6242197F6DBD8A8CF8753742B7E0168EE617A83)
forge verify-contract --chain sepolia --verifier sourcify 0x82382184983ABe091b2Af8f20006553DCeBB0981 assets/erc-aifp/contracts/companions/AIFPObjectionWindow.sol:AIFPObjectionWindow --constructor-args $(cast abi-encode "constructor(address,address)" 0xb10b4c241B9a4feF05aC9d33d8B6c09D7A91aB6e 0xA6242197F6DBD8A8CF8753742B7E0168EE617A83)
forge verify-contract --chain sepolia --verifier sourcify 0xDE93b6b9245eF5ec352ADdFDbC1b1a2B702b755C assets/erc-aifp/contracts/AIFPSubjectSet.sol:AIFPSubjectSet --constructor-args $(cast abi-encode "constructor(address)" 0xfaf78B3D533411Bb921d119a9881C04060869065)
```

3. Re-derive the read-outs with `cast call` against the addresses above and the identifiers in
   `deployments/11155111.cases.json` (for example `evaluate(bytes32,bytes32,uint16,bytes32,uint48)` on the
   participation registry at timepoints before and after `effectiveAt`).

Sourcify match status: not yet submitted from the run environment (no route to sourcify.dev from it); the
commands above reproduce the submission. The on-chain metadata hashes already match the repository build.
