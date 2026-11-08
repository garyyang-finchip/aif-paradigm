# Agent Information Flow Paradigm (AIFP)

Reference implementation, canonical validator, example descriptors, vectors and boundary cases for the
ERC draft **Agent Information Flow Paradigm** - versioned, composable rules for how agents provide, observe
and redistribute information in a channel, with scoped role bindings and four-valued verification.

- ERC text: [`ERCS/erc-aifp.md`](ERCS/erc-aifp.md) (placeholder number 9999 until an editor assigns one)
- Assets as filed with the ERC: [`assets/erc-aifp/`](assets/erc-aifp/README.md)
- Design memo: [`docs/design-memo.md`](docs/design-memo.md)
- Boundary cases: [`docs/boundary-cases.md`](docs/boundary-cases.md)
- Sepolia runbook: [`docs/sepolia-runbook.md`](docs/sepolia-runbook.md)

Status: v0.1.0 - draft text, reference contracts, 152 Foundry tests, validator and vectors complete;
Ethereum Magicians thread and ethereum/ERCs pull request pending; Sepolia evidence run pending.

## What it standardizes

| Layer | Object | On-chain record |
| --- | --- | --- |
| Paradigm | content-addressed descriptor: carriers, operators, thirteen rule dimensions, labels, per-role predicates | `AIFPParadigmRegistry`: hash, family, succession, labels, predicate commitments |
| Channel | an interaction context adopting one paradigm version at any timepoint | `AIFPChannelRegistry`: adoptions with `effectiveAt`, transport/governance/economic bindings, append-only disclosure records, state |
| Participation | separately addressable role bindings with scope, basis, interval, rule version | `AIFPParticipationRegistry`: grant and admission paths, suspension/revocation/re-admission, `evaluate(channel, subject, role, scope, timepoint)` |
| Verification | composable predicate trees, four outcomes | `AIFPCompositeVerifier` + leaf verifiers |
| Profiles | event anchoring, objection windows | `AIFPEventAnchor`, `AIFPObjectionWindow` |

Message transport is out of scope; transports attach through declared bindings with capability bits.

## Repository layout

```
ERCS/erc-aifp.md                      ERC text (source; the filing package renames it)
assets/erc-aifp/contracts/            interfaces, libraries, reference registries, verifier, profiles, companions
assets/erc-aifp/schemas/              descriptor, predicate, binding-capabilities and subject-ref schemas
assets/erc-aifp/examples/             11 named paradigms, 6 composites, 4 deliberately invalid descriptors
assets/erc-aifp/vectors/              subject refs, predicate encodings, outcome tables, interface ids, paradigm ids
test/                                 Foundry suite: unit tests + 12 boundary cases (self-contained, no submodules)
script/                               Deploy.s.sol and Cases.s.sol (on-chain evidence, two phases)
tools/                                descriptor validator, vector generator, filing-package script
docs/                                 design memo, boundary cases, Magicians post, Sepolia runbook, PR description
deployments/                          evidence records written by the scripts
```

## Build and test

Foundry (forge 1.x, solc 0.8.28) and Node 22.

```
forge build
forge test                                   # 152 tests, 24 suites; no `forge install` needed
npm ci && npm run check                      # validates every example, rejects the invalid ones, regenerates vectors
node tools/descriptor-validate.mjs assets/erc-aifp/examples/paradigms/panel.json --brief
python3 tools/make-filing-package.py          # ercs-pr-package/ with placeholder 9999
python3 tools/make-filing-package.py --number N --discussions-to URL
```

The test suite declares its own cheatcode interface (`test/utils/TestBase.sol`), so a fresh clone builds and
tests without submodules or network access beyond the compiler download.

## Registering a paradigm

1. Write a descriptor against `assets/erc-aifp/schemas/paradigm-descriptor.schema.json`.
2. Run the validator; it prints the registration bundle: canonical bytes, `paradigmId`, `familyId`, label ids
   and the per-role predicate encodings with their hashes.
3. Call `registerParadigm(canonicalBytes, familyId, supersedes, labelIds, rolePredicates, descriptorURI)`.
4. Open a channel with `openChannel(paradigmId, authority, parent, metadataURI, bindings)`; grant roles with
   `grant`, or let subjects acquire roles through `admit(channel, role, scope, predicateBytes, evidence, validUntil)`.

## Deployments

None yet. The Sepolia evidence run follows `docs/sepolia-runbook.md`; records land in `deployments/`.

## License

CC0-1.0 for the ERC text and assets (see `LICENSE`).
