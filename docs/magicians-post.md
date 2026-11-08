# Ethereum Magicians post

Topic: https://ethereum-magicians.org/t/draft-erc-agent-information-flow-paradigm-aifp-versioned-composable-rules-for-how-agents-provide-observe-and-redistribute-information/30300
(posted 2026-11-08; the first post was revised the same day after the PR and the Sepolia run - the topic id, and
therefore the `discussions-to` link in the ERC, is unchanged).

## First post (revised)

Title: Draft ERC: Agent Information Flow Paradigm (AIFP) - versioned, composable rules for how agents provide, observe and redistribute information

Category: ERCs

---

**Summary.** AIFP is a framework ERC for the information layer between agents. It defines a flow paradigm
as a content-addressed, versioned description of an interaction context - which carriers (addressed
delivery, shared object) and structural operators (fan-out, fan-in, feedback, n-party, select, forward,
derive, merge) it uses, and how thirteen separately declared rule dimensions are set (discovery,
observation, contribution, management, redistribution, history, time, disclosure timing, contributor
visibility, admission basis, representation, object relations, ordering). A channel adopts exactly one
paradigm version at any timepoint. Participation is recorded as separately addressable role bindings with
a scope, a basis, a validity interval and the rule version they were granted under. Role acquisition is
checked by composable predicates that answer one of four outcomes: satisfied, not satisfied,
undeterminable, verifier error.

**Status.** Draft text and assets filed as ethereum/ERCs PR [#2152](https://github.com/ethereum/ERCs/pull/2152)
(placeholder number 9999 until an editor assigns one). Reference repository with the Foundry suite, the canonical
validator and the vectors: [garyyang-finchip/aif-paradigm](https://github.com/garyyang-finchip/aif-paradigm).
The reference stack is deployed on Sepolia and the boundary-case evidence run is recorded (section below).

**What is new relative to existing systems.** Agent task protocols, tool protocols, matrix-style rooms,
federated activity feeds, signed-event relays, encrypted groups and on-chain events each fix their own
notion of who may read, write and redistribute. AIFP does not replace any of them; transports attach through
declared bindings with capability bits. What it adds is one verifiable answer, across implementations, to
five questions about a context: may this actor observe, may it contribute, may it publish what it read
elsewhere, which rule version decides, and which conditions cannot be verified.

## Structure of the proposal

| Layer | Object | On-chain record |
| --- | --- | --- |
| Paradigm | content-addressed descriptor: carriers, operators, thirteen rule dimensions, labels, per-role predicates | `IAIFPParadigmRegistry`: `paradigmId = keccak256(JCS canonical descriptor)`, family and succession, label ids, predicate commitments |
| Channel | an interaction context adopting one paradigm version at any timepoint | `IAIFPChannelRegistry`: append-only adoptions with `effectiveAt`, transport / governance / economic bindings with capability bits, append-only disclosure records, state |
| Participation | separately addressable role bindings with scope, basis, interval and rule version | `IAIFPParticipationRegistry`: `grant` (manager path) and `admit` (predicate path), suspension / revocation / re-admission history, `evaluate(channel, subject, role, scope, timepoint)` |
| Verification | composable predicate trees, four outcomes | `IAIFPPredicateVerifier` and the composite verifier: `allOf` / `anyOf` with a fixed precedence; unknown kinds and reverting verifiers are never recorded as "not satisfied" |
| Profiles | event anchoring, objection windows | `IAIFPEventAnchor` (optional), objection-window companion (absence semantics only inside a pre-agreed window) |

Encodings fixed by the draft: one subject reference `keccak256("<scheme>:<domain>:<identifier>")` for
`eip155-address`, `erc8004`, `did` and `ext` subjects (lower-case addresses, no left-padding); a predicate tree as
`abi.encode(Node[])` with breadth-first child allocation and nine leaf and composite kinds; an eleven-bit role
mask; ERC-165 interface ids and ERC-6372 clocks. Transport is out of scope by design. `requires: 165, 6372` only;
identity, credential, decision, discovery, swarm, safety, dispute, tender and economic-unit registries attach
through predicate leaves and bindings and are not required.

**Design points worth a look.**

- The familiar human forms (broadcast, panel, assembly, meeting, three kinds of peer-to-peer) are labels on
  configurations, with decidable identification conditions checked by a validator; agent-native forms
  (intake, blackboard, dispatch, forward, derive) sit beside them. Completeness is argued by closure,
  compatibility rules, counterexamples and an open extension namespace - not by a Cartesian product.
- Every grant produces a `bindingId`; `evaluate(channel, subject, role, scope, timepoint)` is a pure function
  of registry history (suspension intervals, re-admission epochs). A suspension is lifted only by the party
  that imposed it.
- Four-valued verification: an unknown required extension, a missing proof or a reverting verifier is never
  recorded as "not satisfied"; the admission path reverts with the outcome it obtained.
- Historical validity vs admission: accepted events keep their validity when delivered late; first-time
  admission uses the registry's ERC-6372 clock and never a sender-asserted timepoint.
- Disclosure monotonicity as a fact about history: disclosure records are append-only; future provision may
  contract (also for existing objects) through a `RESTRICTED` record, which proves neither reading nor
  deletion.
- Absence semantics only inside a pre-agreed objection window with an integrity condition; the default
  consequence proves the agreed condition, never consent.

## An explanatory reading: AIFP terms in agent-communication vocabulary

This section is a reading aid, not a redefinition. AIFP standardizes flow paradigms, channels, participation
and verification as defined above; for readers who come from messaging and agent-communication protocols, the
table maps each AIFP concept to the vocabulary they already use. Communication protocols carry the messages;
AIFP records the rules under which a given context is read, written and redistributed, and a protocol attaches
to a channel as a transport binding.

| AIFP term | Reads, in communication terms, as |
| --- | --- |
| Paradigm | the pattern in force: broadcast, panel, closed group, meeting, peer-to-peer, intake, blackboard, dispatch, forward, derive |
| Channel | one context: a feed, a room, a thread, a topic, a shared document, an event stream |
| Carrier (addressed delivery / shared object) | message passing versus a shared state that participants read and write |
| Structural operators | the shapes an exchange can take: one-to-many, many-to-one, reply, group, routed, relayed, summarized, combined |
| Rule dimensions | who can find the context, read it, contribute to it, manage it, forward from it, see its history, and when |
| Role binding (`OBSERVE`, `SUBMIT`, `RESPOND`, `REDISTRIBUTE`, `MANAGE_*`) | the listener, speaker, replier, forwarder and moderator permissions of one agent in one context |
| Predicate verification, four-valued | the admission check an agent passes before it may observe or contribute, with "cannot verify" kept distinct from "denied" |
| Adoption with `effectiveAt` | a scheduled rule change that every participant can see coming |
| Disclosure record (`DISCLOSED` / `RESTRICTED`) | an append-only log of what the context was opened to or closed off from |
| Transport binding with capability bits | how a concrete protocol (room, feed, relay, group, event log) attaches to the channel |
| Event anchor | a verifiable commitment that a message, forward, derivation or retraction happened in the channel |

Two practical consequences follow: an agent keeps its protocol and declares it as a transport binding, reading
admission, redistribution and rule-version answers from the registries; and two agents on different protocols
can agree on who may read, write and forward in a shared context, because the channel rather than the transport
holds that record.

## Reference material and Sepolia evidence

Three registries (paradigms, channels, participation), a composite verifier, an optional event-anchor profile
and an objection-window companion; a canonical validator (JCS + keccak256, label conditions, predicate
encoding); 17 example descriptors (11 named paradigms, 6 composites) plus 4 deliberately invalid ones; vectors; a
Foundry suite of 152 tests including 12 boundary cases with three participants (strangers' handshake, credential
entry, source + archive, panel-to-club migration, sealed bids, blackboard, receive policies, rule update and
replay, forward/derive/disclose, staked agora, objection window, dispatch).

The reference stack is deployed on Sepolia from the build in the repository (the metadata hashes of the deployed
runtimes match the local build), and boundary cases 1, 4, 5, 8, 9 and 11 were run on it in two phases with three
actors; every transaction, gas figure and read-out is in
[`docs/sepolia-evidence.md`](https://github.com/garyyang-finchip/aif-paradigm/blob/main/docs/sepolia-evidence.md).

| Contract | Sepolia address |
| --- | --- |
| `AIFPParadigmRegistry` | `0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985` |
| `AIFPChannelRegistry` | `0x59c42e471c823a874d7d8E1820DF0A643c340d17` |
| `AIFPParticipationRegistry` | `0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0` |
| `AIFPCompositeVerifier` | `0x0Eb8923fdc4E3e60E2252B62A139582C824A5226` |
| `AIFPEventAnchor` | `0xCcdf6647c90E8C3eC382eF2C46fa2Be3a74bCd08` |
| `AIFPObjectionWindow` | `0x8ea02f7ca49E26D63689Bd98bc026C13810a8664` |

What the run shows: a binding evaluated at a timepoint before a scheduled rule change still answers SATISFIED
after the change, while the same subject answers UNDETERMINABLE (re-admission pending) at the present timepoint
until `confirmReadmission`; the replayed old predicate is rejected with a hash mismatch rather than recorded as
NOT_SATISFIED; the DISCLOSED record is followed by a RESTRICTED record and both remain; the objection window
resolves to DEFAULT_TRIGGERED when no objection is registered and the integrity condition holds; sealed bids
committed in phase 1 are revealed in phase 2 as superseding anchors.

## Questions for the thread

1. Is the four-valued outcome and its composition order (`allOf`: not-satisfied > undeterminable > verifier-error > satisfied; `anyOf`: the reverse) the right default for admission checks?
2. Should the event-anchor profile take a `scopeRef` so that scoped-only contributors can anchor, or is channel-wide role checking the right default?
3. Is a single clock domain per deployment (ERC-6372, timestamp mode in the reference) acceptable, or should cross-registry clock agreement be relaxed?
4. Are the eleven identification conditions the right decidable core, given that they may overlap?
5. Is a transport binding (kind, target, version, capability bits, effect scope, adoption mode) sufficient to describe how a room, feed, relay or group attaches to a channel, or is something missing?

---

## First post as originally published (2026-11-08, before the PR)

Title: Draft ERC: Agent Information Flow Paradigm (AIFP) - versioned, composable rules for how agents provide, observe and redistribute information

Category: ERCs

---

**Summary.** AIFP is a framework ERC for the information layer between agents. It defines a flow paradigm
as a content-addressed, versioned description of an interaction context - which carriers (addressed
delivery, shared object) and structural operators (fan-out, fan-in, feedback, n-party, select, forward,
derive, merge) it uses, and how thirteen separately declared rule dimensions are set (discovery,
observation, contribution, management, redistribution, history, time, disclosure timing, contributor
visibility, admission basis, representation, object relations, ordering). A channel adopts exactly one
paradigm version at any timepoint. Participation is recorded as separately addressable role bindings with
a scope, a basis, a validity interval and the rule version they were granted under. Role acquisition is
checked by composable predicates that answer one of four outcomes: satisfied, not satisfied,
undeterminable, verifier error.

**What is new relative to existing systems.** Agent task protocols, tool protocols, matrix-style rooms,
federated activity feeds, signed-event relays, encrypted groups and on-chain events each fix their own
notion of who may read, write and redistribute. AIFP does not replace any of them; transports attach through
declared bindings with capability bits. What it adds is one verifiable answer, across implementations, to
five questions about a context: may this actor observe, may it contribute, may it publish what it read
elsewhere, which rule version decides, and which conditions cannot be verified.

**Design points worth a look.**

- The familiar human forms (broadcast, panel, assembly, meeting, three kinds of peer-to-peer) are labels on
  configurations, with decidable identification conditions checked by a validator; agent-native forms
  (intake, blackboard, dispatch, forward, derive) sit beside them. Completeness is argued by closure,
  compatibility rules, counterexamples and an open extension namespace - not by a Cartesian product.
- Every grant produces a `bindingId`; `evaluate(channel, subject, role, scope, timepoint)` is a pure function
  of registry history (suspension intervals, re-admission epochs). A suspension is lifted only by the party
  that imposed it.
- Four-valued verification: an unknown required extension, a missing proof or a reverting verifier is never
  recorded as "not satisfied"; the admission path reverts with the outcome it obtained.
- Historical validity vs admission: accepted events keep their validity when delivered late; first-time
  admission uses the registry's ERC-6372 clock and never a sender-asserted timepoint.
- Disclosure monotonicity as a fact about history: disclosure records are append-only; future provision may
  contract (also for existing objects) through a `RESTRICTED` record, which proves neither reading nor
  deletion.
- One subject encoding: `keccak256("<scheme>:<domain>:<identifier>")` for `eip155-address`, `erc8004`, `did`
  and `ext` subjects; no left-padded addresses.
- Absence semantics only inside a pre-agreed objection window with an integrity condition; the default
  consequence proves the agreed condition, never consent.

**Reference material.** Three registries (paradigms, channels, participation), a composite verifier, an
optional event-anchor profile and an objection-window companion; a canonical validator (JCS + keccak256,
label conditions, predicate encoding); 17 example descriptors; vectors; a Foundry suite of 152 tests
including 12 boundary cases with three participants (strangers' handshake, credential entry, source +
archive, panel-to-club migration, sealed bids, blackboard, receive policies, rule update and replay,
forward/derive/disclose, staked agora, objection window, dispatch). Repository: see the PR description.

**Requires.** ERC-165 and ERC-6372 only. Identity, credential, decision, discovery, swarm, safety, dispute,
tender and economic-unit registries are attached through predicate leaves and bindings and are not required.

**Questions for the thread.**

1. Is the four-valued outcome and its composition order (`allOf`: not-satisfied > undeterminable > verifier-error > satisfied; `anyOf`: the reverse) the right default for admission checks?
2. Should the event-anchor profile take a `scopeRef` so that scoped-only contributors can anchor, or is channel-wide role checking the right default?
3. Is a single clock domain per deployment (ERC-6372, timestamp mode in the reference) acceptable, or should cross-registry clock agreement be relaxed?
4. Are the eleven identification conditions the right decidable core, given that they may overlap?

PR to be added after filing.

---

## Reply: Sepolia evidence (phase 2 completed 2026-11-08; to be posted)

**Sepolia evidence run.** The reference stack is deployed on Sepolia from the build in the repository, and the
two-phase run of boundary cases 1, 4, 5, 8, 9 and 11 with three actors is recorded with transaction hashes, gas,
runtime code hashes and read-outs in `docs/sepolia-evidence.md` and `deployments/11155111*.json`:

- `AIFPParadigmRegistry` `0xe5CC5dc02D282Ca1A980Ed586b509Ac9144Dd985`
- `AIFPChannelRegistry` `0x59c42e471c823a874d7d8E1820DF0A643c340d17`
- `AIFPParticipationRegistry` `0x6d0d5A589cdBd07C432C1874f11dF3804b309fd0`
- `AIFPCompositeVerifier` `0x0Eb8923fdc4E3e60E2252B62A139582C824A5226`
- `AIFPEventAnchor` `0xCcdf6647c90E8C3eC382eF2C46fa2Be3a74bCd08`, `AIFPObjectionWindow`
  `0x8ea02f7ca49E26D63689Bd98bc026C13810a8664`

What the run shows on a public network, in the terms of the four thread questions: a binding evaluated at a
timepoint before a rule change still answers SATISFIED after the change (history is a pure function of registry
state), while the same subject answers UNDETERMINABLE (pending re-admission) at the present timepoint until
`confirmReadmission`; the replayed old predicate is rejected with a hash mismatch rather than recorded as
NOT_SATISFIED; the DISCLOSED record is followed by a RESTRICTED record and both remain; and the objection window
resolves to DEFAULT_TRIGGERED when no objection is registered and the integrity condition holds. Sealed bids were
committed in phase 1 and revealed in phase 2 as superseding anchors.

One operational note for anyone reproducing it: Sepolia currently prices contract creation at roughly five times
a local Anvil estimate, so take gas limits from the network's estimates. Repository: see the first post.
