# Sepolia evidence run (v0.1.1 build, 2026-11-08)

This is the record of the first deployment, kept unchanged apart from this heading and the file paths in this
paragraph. The current deployment (v0.1.3 build) is recorded in `docs/sepolia-evidence.md`; the v0.1.1 contracts
below remain on chain.

Deployment of the AIFP reference stack on Sepolia (chain id 11155111) and the two-phase run of boundary cases
1, 4, 5, 8, 9 and 11 with three actors, following `docs/sepolia-runbook.md`. The machine-readable records are
`deployments/archive/v0.1.1/11155111.json`, `deployments/archive/v0.1.1/11155111.cases.json` and
`deployments/archive/v0.1.1/11155111.cases.phase2.json`.

Every transaction below was produced by the unmodified scripts `script/Deploy.s.sol` and `script/Cases.s.sol`,
replayed on Sepolia with the same sender nonces, so the addresses and identifiers are the ones the scripts
computed. All transactions in this document are included with status `0x1` unless stated otherwise.

## Source and build

| Item | Value |
| --- | --- |
| Source | this repository, `assets/erc-aifp/contracts/` as filed with ERC-8489 (draft, v0.1.1; `assets/erc-8489/contracts/` in ethereum/ERCs). The run predates v0.1.2 and v0.1.3 (see `docs/design-memo.md` section 8), which changed `AIFPCompositeVerifier` and `AIFPParticipationRegistry` (leaf calls with a fixed gas bound and raw return-data checks, a tree-shaped predicate, no outcome for an evaluation that did not complete), `AIFPChannelRegistry` (`paradigmAt` when adoptions are recorded out of effective order) and `AIFPEventAnchor` and `AIFPObjectionWindow` (records and events name the authorizing binding). Everything deployed below is the v0.1.1 build: its event records have no `bindingId`, its `paradigmAt` returns the last recorded adoption that is effective rather than the latest effective one (the run records its adoptions in effective order, so its read-outs are not affected), and the cases in this record exercise neither malformed leaf return data nor a tight gas limit |
| Compiler | solc 0.8.28, EVM version `cancun`, optimizer enabled with 200 runs, no IR pipeline (`foundry.toml`) |
| Build check | the CBOR metadata hash at the end of each deployed runtime equals the one in the local `forge build` artifact for the same contract (seven of seven) |
| Deployer / channel authority (A) | `0xfaf78B3D533411Bb921d119a9881C04060869065` |
| Actor B | `0x70C8e57fF73E36761127d28Ed29D8f8cfB9831b6` |
| Actor C | `0x863D46f2c932122bAc1032A4b41b4C29d99229DC` |
| Clock | `mode=timestamp` (ERC-6372), one clock domain for all registries |

The keys used for this run are throwaway keys; channel authority and family control remain on key A.

## Deployed contracts

| Contract | Address | Deploy tx | Block | Gas used | Runtime bytes | Runtime keccak256 |
| --- | --- | --- | --- | --- | --- | --- |
| `AIFPParadigmRegistry` | `0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985` | `0x82119a5c49bd952d51f799385515c524dc906e571c0460298d2d112d94cc2dfe` | 12090710 | 6,177,081 | 3,860 | `0x43e97ba30651be8fda327d2eedee3c3bd275dcb623b63428f12e5ac7b3e876ce` |
| `AIFPCompositeVerifier` | `0x0Eb8923fdc4E3e60E2252B62A139582C824A5226` | `0xc975532e95fd2ecd1dc6b62c47f14d20eeb1075c9d44ebba9b518b640c7c1198` | 12090710 | 5,490,455 | 3,416 | `0x3601a55d3d857c529c9932b2a5505990d205d257e24b594e875ae91972cccd48` |
| `AIFPChannelRegistry` | `0x59c42e471c823a874d7d8E1820DF0A643c340d17` | `0x6d33cb66aba4d903767f159eabc783c7b91394aa1425e7cae40eb8efcf94a24b` | 12090719 | 15,388,437 | 9,816 | `0x4c6e0b073fdcd1acd73b50397e742425c6ceecbe9afe49b8a0ef1db21375b6f7` |
| `AIFPParticipationRegistry` | `0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0` | `0xd27d7b4f5b7a2a14b3f39eaa19c2be0568d8d6ca9c642dab4172a2a0f661542c` | 12090731 | 21,484,141 | 13,759 | `0x6342befc0e64005f3c27152978024c9be437fd87c6e4b4ed1279ffbea5a2dec1` |
| `AIFPChannelRegistry.setParticipationRegistry` | - | `0x2a4d180d4be89c6df4604c6cdd6bdacaea5c7c226a3bbcf4dc61ff548f23909a` | 12090745 | 126,179 | - | - |
| `AIFPEventAnchor` | `0xCcdf6647c90E8C3eC382eF2C46fa2Be3a74bCd08` | `0xb3b4d053a4363f52da2404a7a162c3eb6b7ed197a0e938846ffad87ac22d0534` | 12090745 | 6,542,421 | 4,095 | `0x322fc04c5baf4a1edd69a4e6aee977d7c9be0d7e279e4326f9777fe0ec281f51` |
| `AIFPObjectionWindow` | `0x8ea02f7ca49E26D63689Bd98bc026C13810a8664` | `0xe8b1294f700b13b375322669d3881107bbfe3365b1040906294db97d29b2287a` | 12090745 | 8,544,418 | 5,390 | `0xc6c4bc303ba4d045470ac5494b9c44c8ea95603544b1144e2055a40b26d4ecbf` |
| `AIFPSubjectSet` (roster) | `0x4D72639CB1044091E8136105c7E6381ac973aE3A` | `0xad2bba666bf6bb326319a48f23a53f62eed32455bfc1826984ad3a436709ca8a` | 12090745 | 1,925,486 | 1,038 | `0xeeb2b52a19a48d2a34a72f4bc447ab6cc7a2fb7504d5c2cd07cf3060acd9a2df` |

Deployer nonces 8 to 15. Two earlier transactions of the deployer are not part of the stack and are listed for
completeness: nonce 6 deployed a first `AIFPParadigmRegistry` from the same build at
`0x06e5e749d83063afceaf20a88590badab12e963f` (tx `0x740f5b72c350cfc80a7d380a1d21bdb0fea6d4291225fde277ca92b0742a9fde`,
block 12090588, 6,177,081 gas) as a gas calibration and was superseded by the clean run from nonce 8; nonce 7 was
a 12,000-gas self-transfer sent with a 20,000,000 gas limit (tx `0x8924a5c22bb8dbf46cf6db9056c505b097f2c02387a66dad4b254a1d0a789483`,
block 12090686) to confirm that the network does not enforce a per-transaction gas cap of 2^24.

### Note on Sepolia gas pricing

At the time of this run Sepolia priced contract creation at roughly 5.35 times the cost computed by a local
Anvil node with the same bytecode (for example 6,177,081 gas on Sepolia against 1,154,341 locally for
`AIFPParadigmRegistry`; the creation cost fits `141k + 1,564 gas per runtime byte` within 0.2 percent across all
seven contracts), while a plain value transfer cost 12,000 gas and state-writing calls cost two to three times
their local estimate. Base fee was about 24 wei. None of this affects the contracts; it is recorded so that the
gas figures above can be read correctly. Gas limits were therefore taken from the network's own estimates rather
than from local ones, as the runbook prescribes.

## Phase 1

All 45 phase-1 transactions were included between blocks 12090759 and 12090775 with status `0x1`: actor A
registered eight paradigms, opened seven channels, granted roles, anchored the sealed-bid commitments and the
blackboard versions, scheduled the panel-to-club adoption and the rule update (`effectiveAt` 1794145304,
`AIFP_DELAY` 3000 seconds) and opened the objection window (deadline 1794148304); actor B admitted itself as responder in the
one-to-one link (case 1), as bidder in the tender (case 5) and as submitter under the v1 rules (case 8), anchored
its sealed bid, the rules post and the blackboard versions and recorded the room disclosure (case 9); actor C
admitted itself as observer of the talk (case 4) and as bidder in the tender and anchored its sealed bid. The identifiers that phase 2 reads back are in
`deployments/11155111.cases.json`.

| # | Actor | Nonce | Call | To | Block | Tx |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | A | 16 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0x97ee84eb85d29f35c14add90458e61241be5acbe7f631242ead340b34f377685` |
| 9 | A | 17 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0x84191169ccfd8e2f23917d1fbda6ffc7a205dc34745ad2bdfa21bb78cbaeea27` |
| 10 | A | 18 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0x4aa90933c30e438338fe9f7fd6e2c89ecf83e330ba6c86a38d4768f6a7f525a6` |
| 11 | A | 19 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0x985fb45939d717b9578fe4aae96c447c986d5fa30afc57151684e91c2d3ef341` |
| 12 | A | 20 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0xdc2de011a0445df59af500182c21ef6936eee9b112f32668fd15cd887816b7de` |
| 13 | A | 21 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0xaceb0e68a166c3fab13701ce9cc04e04ea6718608cddbda09138be6daab10335` |
| 14 | A | 22 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0x92cb48ed4f5b478e25bab757bdff714cae6fe3a982cda1159fd8312dc25319cc` |
| 15 | A | 23 | `registerParadigm` | `0xe5cc5dc02d282ca1a980ed586b509ac9144dd985` | 12090759 | `0xd6830b09397859731fc6afc976775fa7e5e8e2485b35c292dc9784b2cd72262d` |
| 16 | A | 24 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0xb1c16d3e5e026ffbb0f7f82d262432106fb18d3a6b4707abee6c0332010e9b0c` |
| 17 | A | 25 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x81dd500dd07dccaf8e632add3066b971e0037343b49713ee6f94a53ed7afee8b` |
| 18 | A | 26 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x7481f4867fa7d2ecba5babddec228f9dfba103bc617fc02f96e9bd3c61deefd0` |
| 19 | A | 27 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x413a608ac579e8a75d0aff0f9f8ccfc61006e834625b3eb2828180cc9aa7b5a1` |
| 20 | A | 28 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x5c0a75d720f003707390b433ecfb001100afa02b52e3dec9808514ee9bfdd110` |
| 21 | A | 29 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x9ce11603adefc5e7e81adfae4ad69930e43080f88dd36036c4e3bdc4155337df` |
| 22 | A | 30 | `openChannel` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090759 | `0x30f6147230be8c9db9b61912a95418ca6e7f1ff3c570836849c3ce948dd4b07c` |
| 23 | A | 31 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090759 | `0x73002b17428eeef01557b650cf904a335ed69ff0d82256e7a973e98aaefb8347` |
| 24 | A | 32 | `add` | `0x4d72639cb1044091e8136105c7e6381ac973ae3a` | 12090759 | `0x17fece3ec3afabb4cf10951934f4702d954f6c13bab00c34806024c28e0000ae` |
| 25 | A | 33 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0xf01ea04f2793b9eeb53196c6c1b6f70bff7292154e3d2437e850152253103b4c` |
| 26 | A | 34 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x7d95abed6f64d835d577d250c9650dff64f621d9ba3601d920b4039f7ce6f0a2` |
| 27 | A | 35 | `adoptParadigm` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090766 | `0xf68f8afdf1a7a48e5db3e8b0031547bc0e22b5a58869f4461c330c1762ef9d2a` |
| 28 | A | 36 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0xf10d1b87b77867b69f302ee85b8155772ad187f715338789449f5cc1de496055` |
| 29 | A | 37 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x0b36c848aa500e56c7267c356084419cec2fb33f3a58916d9fa177684fe2e363` |
| 30 | A | 38 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0xcbdd2b6d7fd1c5c559f38a4bc0219033a1719583b85a2ce3f2b28f98e0ee7355` |
| 31 | A | 39 | `adoptParadigm` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090766 | `0x77df68aaa7400106a754e57eae75a973837cb85f0822442eaaaeb049ed1d56ec` |
| 32 | A | 40 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x9467ccac5b2b113c99be86df228d0ec535e72e0aaf799ad55e45ac935c2f12c8` |
| 33 | A | 41 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x06ca195738ba80f53088d65f7143e827bf8705dd5b9f82e20e482e5061d92267` |
| 34 | A | 42 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0xb95498ab922e1ff5aeddd844c5cb95f7238c6717f5acd46432af10d990fa3a28` |
| 35 | A | 43 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x6000d5ce394c5b6a7bff648d7fc982a2b2b1f80f0541e0fd740e0461ffb6f9c2` |
| 36 | A | 44 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090766 | `0xd6c3aac7a8cc6e23e185d2283b928ff5a0267baec01dfba8c58099b04b862a7d` |
| 37 | A | 45 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x3a14491048729a1b70ca187420f52a565a4321765e54e9f4e92ac653a0a39f67` |
| 38 | A | 46 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x85ab1fa2de6f9f577c8dc20b508583a62d8601a0c785fb5d0afbca1a73169875` |
| 39 | A | 47 | `grant` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090766 | `0x995d1e67b93ef4386ab741736fa8562ffb22972a8f382454e50b7a9088140a79` |
| 40 | A | 48 | `open` | `0x8ea02f7ca49e26d63689bd98bc026c13810a8664` | 12090766 | `0xe67dad26bd9ac59b7378f8400fddb74ab24d9c3bb1525539e91512b218e781c7` |
| 41 | B | 0 | `admit` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090772 | `0xaca8835e828cc268f782c15ad6705a97dce76796b2df7815d155b5c98fffa8bc` |
| 42 | B | 1 | `admit` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090772 | `0x157fd4403a806cd781d77bb021e6a83d4eeced4f9d0226559439ce9ae42b3d4d` |
| 43 | B | 2 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090772 | `0x78a0fc4deb13b1c01210111f51559084fdc08b8b225e3e2008dfc77139aa0244` |
| 44 | B | 3 | `admit` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090772 | `0xff64552909faa32e925eb137fdd7ce609bf84f77fae508d6bb4355cc5d24f8a3` |
| 45 | B | 4 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090772 | `0x2760473cfdf6ec8120980236a51bfbf9c720c2d66c957e4b5472324b69c5f3f6` |
| 46 | B | 5 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090772 | `0xab753850c4d22bfa663115fc2ae87c1126ab2a35229082c3ba0e66545a458238` |
| 47 | B | 6 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090772 | `0x1ab042326b6c60ef2cf4e3fb61d57b02c36a8a10b4a1b4e2e8431aaa1182f858` |
| 48 | B | 7 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090772 | `0xe8e226f3c7ba2ce95d28d30586f0c873a20c8d59c0c0004830a8477572f424d7` |
| 49 | B | 8 | `recordDisclosure` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12090772 | `0x3edf67807861e58de5b3e32f28b109a2b1505a5605e668be25ae7a7cf19ad5f0` |
| 50 | C | 0 | `admit` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090775 | `0x9aab2b16390c5b1579677f5ded366246459050fba34c2b5abf2b77db5ce83b79` |
| 51 | C | 1 | `admit` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12090775 | `0x8808137af3a1ff781e3bdac37314f5b8667185f667e9181e35ce2c62beeb847a` |
| 52 | C | 2 | `anchor` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12090775 | `0x326dd72095d62b03b0f597fa77a22c22756488fc9295c8dc35e1c346c457af90` |

## Phase 2

### Read-outs taken on Sepolia before phase 2

The following values were read with `eth_call` against the deployed registries (outcome codes: 0 SATISFIED,
1 NOT_SATISFIED, 2 UNDETERMINABLE, 3 VERIFIER_ERROR; subject references are
`keccak256("eip155-address:11155111:<address>")`).

| Read | Before `effectiveAt` (block 12090830, chain time 1794143964) | After `effectiveAt`, before phase 2 (block 12090940, chain time 1794145356) |
| --- | --- | --- |
| `evaluate(talk, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 SATISFIED (history unchanged by the adoption) |
| `evaluate(talk, B, SUBMIT, 0, now)` | 0 SATISFIED | 2 UNDETERMINABLE (re-admission pending under the new epoch) |
| `isPending(bPanelist, now)` | false | true |
| `evaluate(rules, B, SUBMIT, 0, effectiveAt - 1)` / `(…, now)` | 0 / 0 | 0 / 0 (the rules adoption does not require re-admission; B is revoked in phase 2) |
| `previewAdmission(rules, C, SUBMIT, 0, openPredicate, [])` | 0 SATISFIED (v1 still in force) | reverts `AIFP_PredicateMismatch(0x9978da14…, 0xd9748b88…)`: the v1 predicate is rejected by hash, not recorded as NOT_SATISFIED |
| `disclosureCount(room)` | 1 (DISCLOSED) | 1 |
| `window(0)` | status 0 OPEN, objectionRole 8, start 1794145304, deadline 1794148304, 0 objections | unchanged |

### Phase 2 transactions

Phase 2 was broadcast in two parts once chain time had passed `effectiveAt`: the nine transactions that do not depend on the objection-window deadline first (A confirms B's panelist re-admission, adds C to the roster, revokes B's rules binding and records the RESTRICTED disclosure; B reveals its bid; C takes the floor by rule, re-proves its observer binding, enters the tightened rules through the roster allowlist and reveals its bid), then `resolve` after the deadline. All of them were included with status `0x1`.

| Actor | Nonce | Call | To | Block | Gas used | Tx |
| --- | --- | --- | --- | --- | --- | --- |
| A | 49 | `confirmReadmission(bPanelist)` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12091032 | 314,613 | `0x2c90ee75144a8233cb289b2331a79488aab74fa44dbbf75b953e8bdc895c486d` |
| A | 50 | `roster.add(C)` | `0x4d72639cb1044091e8136105c7e6381ac973ae3a` | 12091032 | 141,817 | `0x14d1b290546dc6141cb6a47448336ed3c78b21708da2681aada6ae412a009d3e` |
| A | 51 | `revoke(bRules)` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12091032 | 165,926 | `0x5b97bb0bd110fcb7aa7855cf8182769dde3869ccd88e46cea01fe3fc7cb9f256` |
| A | 52 | `recordDisclosure(room, RESTRICTED, summary)` | `0x59c42e471c823a874d7d8e1820df0a643c340d17` | 12091032 | 588,284 | `0x6acbb08b675f64e085e6edf09100f0ecac2685eb0143e140b788bacbb758797d` |
| B | 9 | `anchor(tender, SUPERSEDE: reveal of B's bid)` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12091036 | 980,273 | `0xbaf602dd8e3248129e8ab4f040378b426db5383c7bf05096517fd948943f6105` |
| C | 3 | `admit(talk, SUBMIT, openPredicate)` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12091046 | 1,449,815 | `0x98c7d10714e3f29279a3c55542201a14fb08f4d28754e4396346efa103eb0fac` |
| C | 4 | `readmit(cObserver, openPredicate)` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12091046 | 346,105 | `0xc4112af7903f2d0d72909a4acf7fe7392bd49de232a29ccc7f8966577c34c52d` |
| C | 5 | `admit(rules, SUBMIT, allowlistPredicate(roster))` | `0x6d0d5a589cdbd07c432c1874f11df3804b309fd0` | 12091046 | 1,445,875 | `0x169e64db3f041adf34900906cb41612a944537a82867db235550ea66bdf3ad15` |
| C | 6 | `anchor(tender, SUPERSEDE: reveal of C's bid)` | `0xccdf6647c90e8c3ec382ef2c46fa2be3a74bcd08` | 12091046 | 980,261 | `0x0b91ade9b5b06aafd8a74100728e5398679f014cfe385f121ca0a95514ccc997` |
| A | 53 | `resolve(windowId 0)` | `0x8ea02f7ca49e26d63689bd98bc026c13810a8664` | 12091173 | 51,894 | `0x1269c2c572aedf9aa8b754fca03114f8f0dee5d4bd5a08eb5f45395963ec29f5` |

### Read-outs after phase 2

Read with `eth_call` at block 12091176 (chain time 1794148428), after all ten phase-2 transactions. The
right-hand column repeats the value the Foundry rehearsal predicted for the same read.

| Read | On Sepolia | Expected (`Cases.s.sol` phase 2) |
| --- | --- | --- |
| `evaluate(talk, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 (`case4.bHistoryBeforeChange`) |
| `evaluate(talk, B, SUBMIT, 0, now)` | 0 SATISFIED (2 UNDETERMINABLE before `confirmReadmission`, see above) | 2 before confirmation (`case4.bPendingBeforeConfirm`), 0 after |
| `evaluate(rules, B, SUBMIT, 0, effectiveAt - 1)` | 0 SATISFIED | 0 (`case8.bHistoryUnderV1`) |
| `evaluate(rules, B, SUBMIT, 0, now)` | 1 NOT_SATISFIED (revoked; history above untouched) | 1 (`case8.bNowAfterRevocation`) |
| `previewAdmission(rules, C, SUBMIT, 0, openPredicate, [])` | reverts `AIFP_PredicateMismatch(0x9978da14…c0acd3, 0xd9748b88…a91e)` | rejected (`case8.oldRuleRejectedAfterChange` = 1) |
| `evaluate(talk, C, SUBMIT, 0, now)` / `(…, effectiveAt - 1)` | 0 / 1 (admitted by rule in phase 2; no role before) | admitted (`cSubmit`) |
| `evaluate(rules, C, SUBMIT, 0, now)` / `(…, effectiveAt - 1)` | 0 / 1 (admitted under v2 through the roster allowlist) | admitted (`cRules`) |
| `isPending(bPanelist, now)`, `isPending(cObserver, now)` | false, false | confirmed / re-admitted |
| `disclosureCount(room)` | 2 (DISCLOSED, then RESTRICTED) | 2 (`case9.disclosureRecords`) |
| `window(0).status` | 1 DEFAULT_TRIGGERED, 0 objections, integrity intact | 1 (`windowStatus`) |

The sealed bids of B and C were revealed as anchors superseding the phase-1 commitments (B
`0xbaf602dd…6105`, C `0x0b91ade9…c997`). Final nonces after the run: A 54, B 10, C 7; the three keys retain
0.0277, 0.0040 and 0.0042 ETH respectively.

## Reproducing

1. `forge build` with the repository's `foundry.toml`; compare the metadata hash at the tail of
   `out/<Contract>.sol/<Contract>.json` `deployedBytecode` with `eth_getCode` of the addresses above.
2. Verify sources with Sourcify from a machine with network access to it, one command per contract:

```
forge verify-contract --chain sepolia --verifier sourcify 0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985 assets/erc-aifp/contracts/AIFPParadigmRegistry.sol:AIFPParadigmRegistry
forge verify-contract --chain sepolia --verifier sourcify 0x0Eb8923fdc4E3e60E2252B62A139582C824A5226 assets/erc-aifp/contracts/AIFPCompositeVerifier.sol:AIFPCompositeVerifier
forge verify-contract --chain sepolia --verifier sourcify 0x59c42e471c823a874d7d8E1820DF0A643c340d17 assets/erc-aifp/contracts/AIFPChannelRegistry.sol:AIFPChannelRegistry --constructor-args $(cast abi-encode "constructor(address)" 0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985)
forge verify-contract --chain sepolia --verifier sourcify 0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0 assets/erc-aifp/contracts/AIFPParticipationRegistry.sol:AIFPParticipationRegistry --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x59c42e471c823a874d7d8E1820DF0A643c340d17 0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985 0x0Eb8923fdc4E3e60E2252B62A139582C824A5226)
forge verify-contract --chain sepolia --verifier sourcify 0xCcdf6647c90E8C3eC382eF2C46fa2Be3a74bCd08 assets/erc-aifp/contracts/AIFPEventAnchor.sol:AIFPEventAnchor --constructor-args $(cast abi-encode "constructor(address,address)" 0x59c42e471c823a874d7d8E1820DF0A643c340d17 0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0)
forge verify-contract --chain sepolia --verifier sourcify 0x8ea02f7ca49E26D63689Bd98bc026C13810a8664 assets/erc-aifp/contracts/companions/AIFPObjectionWindow.sol:AIFPObjectionWindow --constructor-args $(cast abi-encode "constructor(address,address)" 0x59c42e471c823a874d7d8E1820DF0A643c340d17 0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0)
forge verify-contract --chain sepolia --verifier sourcify 0x4D72639CB1044091E8136105c7E6381ac973aE3A assets/erc-aifp/contracts/AIFPSubjectSet.sol:AIFPSubjectSet --constructor-args $(cast abi-encode "constructor(address)" 0xfaf78B3D533411Bb921d119a9881C04060869065)
```

3. Re-derive the read-outs with `cast call` against the addresses above and the identifiers in
   `deployments/11155111.cases.json` (for example `evaluate(bytes32,bytes32,uint16,bytes32,uint48)` on the
   participation registry at timepoints before and after `effectiveAt`).

Sourcify match status: not yet submitted from the run environment (no route to sourcify.dev from it); the
commands above reproduce the submission. The on-chain metadata hashes already match the repository build.
