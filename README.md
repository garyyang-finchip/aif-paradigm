# Agent Information Flow Paradigm (AIFP) - ERC-8489

Reference implementation, canonical validator, example descriptors, vectors and boundary cases for
**ERC-8489: Agent Information Flow Paradigm** (status Draft) - versioned, composable rules for how agents
provide, observe and redistribute information in a channel, with scoped role bindings and four-valued
verification.

For readers who come from messaging and agent-communication protocols, AIFP can be read in that vocabulary:
for any context in which agents (or agents and humans) exchange information - a broadcast feed, a panel, a
closed group, a meeting, a one-to-one exchange, a shared blackboard, a dispatch queue - it records one
verifiable answer to who may observe, who may contribute, who may forward what they read, which version of the
rules decides, and which conditions cannot be verified. The protocols (task and tool protocols, room-based
chat, federated feeds, signed-event relays, encrypted groups, on-chain events) carry the messages; AIFP records
the rules of the context and attaches to any of those protocols through declared transport bindings. This is a
reading aid, not a redefinition - see [AIFP in agent-communication terms](#aifp-in-agent-communication-terms)
for the term-by-term mapping.

- ERC text: [`ERCS/erc-aifp.md`](ERCS/erc-aifp.md) (source of `ERCS/erc-8489.md` in ethereum/ERCs; the
  filing package applies the number)
- Assets as filed with the ERC: [`assets/erc-aifp/`](assets/erc-aifp/README.md) (filed as `assets/erc-8489/`)
- Design memo: [`docs/design-memo.md`](docs/design-memo.md)
- Boundary cases: [`docs/boundary-cases.md`](docs/boundary-cases.md)
- Sepolia runbook: [`docs/sepolia-runbook.md`](docs/sepolia-runbook.md)

Status: v0.1.3 - number ERC-8489 assigned by the editors on 2026-11-09; draft text, reference contracts,
226 Foundry tests, validator and vectors complete. v0.1.2 and v0.1.3 are review rounds from the Magicians thread
(see `docs/design-memo.md`, section 8): leaf answers are judged by their raw return data and never copied beyond
one word; every leaf that is called is given a fixed gas bound in full, or the evaluation fails without an
outcome; a failed evaluation is never reported as `VERIFIER_ERROR`; the predicate array has to be a tree of
bounded depth and a decided composite stops evaluating; event records name the role binding that authorized
them; an objection window confirms its integrity instead of presuming it. Ethereum
Magicians thread
[ERC-8489: Agent Information Flow Paradigm](https://ethereum-magicians.org/t/erc-8489-agent-information-flow-paradigm/30300)
and ethereum/ERCs pull request [#2152](https://github.com/ethereum/ERCs/pull/2152) open; the v0.1.1 reference
stack is deployed on Sepolia with the boundary-case evidence run recorded in
[`docs/sepolia-evidence.md`](docs/sepolia-evidence.md).

## What it standardizes

| Layer | Object | On-chain record |
| --- | --- | --- |
| Paradigm | content-addressed descriptor: carriers, operators, thirteen rule dimensions, labels, per-role predicates | `AIFPParadigmRegistry`: hash, family, succession, labels, predicate commitments |
| Channel | an interaction context adopting one paradigm version at any timepoint | `AIFPChannelRegistry`: adoptions with `effectiveAt`, transport/governance/economic bindings, append-only disclosure records, state |
| Participation | separately addressable role bindings with scope, basis, interval, rule version | `AIFPParticipationRegistry`: grant and admission paths, suspension/revocation/re-admission, `evaluate(channel, subject, role, scope, timepoint)` |
| Verification | composable predicate trees, four outcomes | `AIFPCompositeVerifier` + leaf verifiers |
| Profiles | event anchoring, objection windows | `AIFPEventAnchor`, `AIFPObjectionWindow` |

Message transport is out of scope; transports attach through declared bindings with capability bits.

## AIFP in agent-communication terms

An explanatory mapping. AIFP standardizes flow paradigms, channels, participation and verification as defined
by the ERC text; the table below says how each of those concepts reads for someone who builds or operates an
agent communication system. A communication protocol decides how bytes move between agents; an AIFP channel
records, for a given context, who may take part, in which way, and under which version of the rules, where
every participant and every transport can verify it.

| AIFP term | Agent-communication reading |
| --- | --- |
| Paradigm | the communication pattern in force: broadcast, panel, closed group, meeting, peer-to-peer, intake, blackboard, dispatch, forward, derive |
| Channel | one communication context: a feed, a room, a thread, a topic, a shared document, an event stream |
| Carrier (addressed delivery / shared object) | message passing versus a shared state that participants read and write |
| Structural operators (fan-out, fan-in, feedback, n-party, select, forward, derive, merge) | the shapes a conversation can take: one-to-many, many-to-one, reply, group, routed, relayed, summarized, combined |
| Rule dimensions (discovery, observation, contribution, management, redistribution, history, time, ...) | who can find the conversation, read it, speak in it, moderate it, forward it, see its history, and when |
| Role binding (`OBSERVE`, `SUBMIT`, `RESPOND`, `REDISTRIBUTE`, `MANAGE_*`) | listener, speaker, replier, forwarder and moderator permissions for one agent in one context |
| Predicate verification (four-valued outcome) | the admission check an agent passes before it may listen or speak - credential, allowlist, stake, identity, decision - with "cannot verify" kept distinct from "denied" |
| Adoption with `effectiveAt` | a scheduled change of the communication rules that every participant can see coming |
| Disclosure record (`DISCLOSED` / `RESTRICTED`) | an append-only log of what the conversation has been opened to or closed off from |
| Transport binding with capability bits | the attachment of a concrete agent communication protocol (room, feed, relay, group, event log) to the channel |
| Event anchor | a verifiable commitment that a message, forward, derivation or retraction happened in the channel |

What follows for implementers of communication systems:

- An agent that speaks a communication protocol does not need to replace it to adopt AIFP; it declares the
  protocol as a transport binding and reads admission, redistribution and rule-version answers from the
  registries.
- Two agents on different communication protocols can still agree on who may read, write and forward in a
  shared context, because the AIFP channel, not the transport, is the source of truth for those questions.
- Human participants fit the same model: the seven familiar human communication forms (source, panel, club,
  meeting and three kinds of one-to-one exchange) are named paradigms with decidable identification
  conditions, alongside the agent-native forms.

## Repository layout

```
ERCS/erc-aifp.md                      ERC text (source; the filing package writes it as ERCS/erc-8489.md)
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
forge test                                   # 226 tests, 27 suites; no `forge install` needed
npm ci && npm run check                      # validates every example, rejects the invalid ones, regenerates vectors
node tools/descriptor-validate.mjs assets/erc-aifp/examples/paradigms/panel.json --brief
python3 tools/make-filing-package.py          # ercs-pr-package/ERCS/erc-8489.md + assets/erc-8489/, linted
python3 tools/make-filing-package.py --number N --discussions-to URL   # only to override the number or thread
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

Sepolia (chain id 11155111), deployed from the build described in `foundry.toml`; full record with transaction
hashes, gas, runtime code hashes and the two-phase boundary-case run in
[`docs/sepolia-evidence.md`](docs/sepolia-evidence.md) and `deployments/11155111*.json`.

These addresses are the v0.1.1 build. v0.1.2 and v0.1.3 changed `AIFPCompositeVerifier`,
`AIFPParticipationRegistry`, `AIFPChannelRegistry`, `AIFPEventAnchor` and `AIFPObjectionWindow` (see
`docs/design-memo.md`, section 8); the stack will be redeployed and the evidence run repeated once the current
review round has settled, and this table replaced then.

| Contract | Address |
| --- | --- |
| `AIFPParadigmRegistry` | `0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985` |
| `AIFPCompositeVerifier` | `0x0Eb8923fdc4E3e60E2252B62A139582C824A5226` |
| `AIFPChannelRegistry` | `0x59c42e471c823a874d7d8E1820DF0A643c340d17` |
| `AIFPParticipationRegistry` | `0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0` |
| `AIFPEventAnchor` | `0xCcdf6647c90E8C3eC382eF2C46fa2Be3a74bCd08` |
| `AIFPObjectionWindow` | `0x8ea02f7ca49E26D63689Bd98bc026C13810a8664` |
| `AIFPSubjectSet` (roster used by the cases) | `0x4D72639CB1044091E8136105c7E6381ac973aE3A` |

## Authors and contributors

- **Gary Yang** ([@garyyang-finchip](https://github.com/garyyang-finchip)) - author of the ERC text, the
  paradigm model and the reference implementation.
- **Chelsey Huang** ([@chenxihuang1028-a11y](https://github.com/chenxihuang1028-a11y)) - contributor;
  conceptual contributions to the paradigm model and its agent-communication framing.

The full list is kept in [`CONTRIBUTORS.md`](CONTRIBUTORS.md).

## License

CC0-1.0 for the ERC text and assets (see `LICENSE`).
