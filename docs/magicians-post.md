# Ethereum Magicians post

Topic: https://ethereum-magicians.org/t/erc-8489-agent-information-flow-paradigm/30300
(posted 2026-11-08 under the title "Draft ERC: Agent Information Flow Paradigm (AIFP) - versioned, composable rules
for how agents provide, observe and redistribute information"; the first post was revised the same day after the
PR and the Sepolia run; on 2026-11-09 the editors assigned ERC-8489 and retitled the topic "ERC-8489: Agent
Information Flow Paradigm". The topic id 30300 is unchanged; the `discussions-to` link in the ERC now uses the
new slug, and the old URL redirects to it.)

## First post (revised)

Title: ERC-8489: Agent Information Flow Paradigm

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

**Status.** Draft. Filed as ethereum/ERCs PR [#2152](https://github.com/ethereum/ERCs/pull/2152); the editors
assigned the number ERC-8489 on 2026-11-09 (`ERCS/erc-8489.md`, assets under `assets/erc-8489/`). Reference
repository with the Foundry suite, the canonical validator and the vectors:
[garyyang-finchip/aif-paradigm](https://github.com/garyyang-finchip/aif-paradigm). The reference stack is
deployed on Sepolia and the boundary-case evidence run is recorded (section below).

**Links.** ERC text as filed: [ERCS/erc-8489.md](https://github.com/garyyang-finchip/ERCs/blob/add-erc-aif-paradigm/ERCS/erc-8489.md)
(ethereum/ERCs pull request [#2152](https://github.com/ethereum/ERCs/pull/2152)) - reference repository:
[garyyang-finchip/aif-paradigm](https://github.com/garyyang-finchip/aif-paradigm) - Sepolia evidence:
[docs/sepolia-evidence.md](https://github.com/garyyang-finchip/aif-paradigm/blob/main/docs/sepolia-evidence.md).

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

## Reply to the leaf return data report (posted 2026-11-09)

The report (second post in the thread): `AIFPCompositeVerifier` caught a leaf that reverts but not one whose
return data fails to decode; `try IAIFPPredicateVerifier(v).verify(...) returns (uint8)` decodes in the caller,
so a verifier returning nothing or a word above 255 reverted `evaluate` itself, the participation registry's
`try/catch` turned that into `VERIFIER_ERROR` for the whole predicate, and `anyOf(ALLOWLIST, EXTERNAL)` with one
broken external verifier refused subjects on the allowlist. The `ALLOWLIST` call had the same shape with its
`bool`. Suggested: a low-level `staticcall` with a 32-byte / value-at-most-3 check, a gas cap per leaf, and a
sentence in the draft saying that malformed return data is `VERIFIER_ERROR` for that leaf only.

Reply as posted:

---

Thank you - this is right, and it is a real bug in the reference verifier rather than a wording issue. A typed
`try ... returns (uint8)` decodes the return data in the caller, so a leaf that returned nothing or a word above
255 reverted `evaluate` itself; the registry's `try/catch` then reported `VERIFIER_ERROR` for the whole
predicate, and `anyOf(ALLOWLIST, EXTERNAL)` with one broken external verifier refused subjects that the
allowlist admits. I reproduced exactly that scenario in a test before changing anything (`previewAdmission`
answered 3 for a subject on the allowlist, `admit` reverted with `AIFP_VerifierError`).

What changed (v0.1.2 of the reference, in the repository and in PR #2152):

- `AIFPCompositeVerifier` now makes every leaf call - `verify` and `contains` alike - as a low-level
  `staticcall` bounded to `LEAF_GAS_LIMIT = 1_000_000` gas and judges the raw return data: success, exactly 32
  bytes, value at most 3 (0 or 1 for `contains`). Anything else is `VERIFIER_ERROR` for that leaf only and the
  rest of the tree is still composed; a leaf that burns its gas is contained the same way.
- The draft now says so. Section 6.3: a composite verifier judges a leaf call by its raw return data, malformed
  return data is that leaf's `VERIFIER_ERROR`, the gas forwarded to a leaf SHOULD be bounded and the bound
  documented. Section 6.4 step 3 lists the leaf faults and says the remaining leaves are still evaluated.
  Section 2.5: a fault in one leaf MUST NOT abort the evaluation of the other leaves or of the tree. The
  Rationale and the Security Considerations explain why (the composition tables only hold if the fault stays in
  the leaf).
- Tests: evaluation scenario 9 in the ERC, and a new suite (`test/unit/LeafReturnData.t.sol`, eleven tests with
  a `MisbehavingVerifier` that returns nothing, 256, 16 bytes, 64 bytes, or loops until out of gas). The faulty
  leaf is `VERIFIER_ERROR`, `anyOf(E, open)` is `SATISFIED`, `allOf(E, open)` is `VERIFIER_ERROR`, and in your
  scenario the registry admits the subject on the allowlist while answering `VERIFIER_ERROR` - never
  `NOT_SATISFIED` - for a subject outside it. 163 tests pass.

On the gas bound I chose a fixed per-leaf cap in the verifier rather than a per-node field, so the predicate
encoding and the committed predicate hashes are unchanged; the EVM's 63/64 rule still applies underneath. If you
think the bound belongs in the node (or that 1,000,000 is the wrong default), I would like to hear the argument.

The Sepolia record notes that the deployed verifier is the v0.1.1 build and that the recorded cases do not
exercise malformed leaf return data; it will be redeployed with the next evidence run.

## Reply to the follow-up on the leaf call (fourth post; reply of 2026-11-10)

The follow-up (fourth post in the thread) agreed with keeping the bound in the verifier and made three points.
Section 6.3 should say that a leaf needing more than the bound is always `VERIFIER_ERROR`: 1,000,000 gas covers a
Groth16 check and not an on-chain STARK verifier. At 594c7ee a caller with less than about 64/63 of the bound left
gave the leaf less than the bound, so the same leaf could pass in `previewAdmission` over `eth_call` and come back
`VERIFIER_ERROR` in an `admit` sent with a tight gas limit; the suggestion was to revert when
`gasleft() < LEAF_GAS_LIMIT / 63` after the call, as OpenZeppelin's ERC2771Forwarder does. And
`(bool success, bytes memory ret)` copied all of the return data into the verifier's memory, a cost the bound did
not cover (about 700 KB fit in a leaf's million, and copying them cost the verifier about as much again); the
suggestion was to copy at most 32 bytes in assembly.

Reply:

---

@Zealynx agreed on all three; on the second the fix went further than the one you proposed. This is v0.1.3 of
the reference, in the repository and in PR #2152.

**1. A leaf that needs more than the bound.** Section 6.3 now says so: a leaf call that does not complete within
the bound is `VERIFIER_ERROR` for that leaf however much gas the caller supplies, and a paradigm whose leaf
needs more has to be evaluated by a composite verifier with a higher bound. The bound is a fixed amount (MUST;
it was "SHOULD be bounded") and the verifier reports it through `leafGasLimit()`, so it can be read before a
paradigm names a heavy verifier. The text calls 1,000,000 a property of the reference implementation: ample for
a pairing-based proof check, too small for a verifier that needs several million gas.

**2. The starved leaf.** Right: at 594c7ee a leaf could receive less than the bound, and `previewAdmission` and
a tight `admit` could disagree. I first implemented your check (revert when `gasleft() < LEAF_GAS_LIMIT / 63`
after the call). It catches a starved leaf that burns everything it is given. It misses a starved leaf that
still returns, because that leaf leaves gas behind: a probe that branches on `gasleft()`, and one that catches
an out-of-gas in an inner call and answers `UNDETERMINABLE` (what a verifier querying a registry inside
`try/catch` does), both returned outcomes that differ from the fully funded answer.

So the draft now requires that **the gas supplied to an evaluation MUST NOT decide its outcome.** The verifier
checks before each leaf call that the full bound can be forwarded (`gasleft() >= bound + bound / 63 + 1 +
margin`) and otherwise reverts the whole evaluation with `AIFP_InsufficientGas()`; every leaf that is called
receives exactly the bound. The registry no longer turns a reverted evaluation into `VERIFIER_ERROR`: it reports
an outcome only when the verifier returned one outcome word and reverts otherwise. An `admit` with too little
gas fails; it does not answer differently from its preview.

**3. The return data copy.** Adopted as you wrote it: `AIFPCalls.staticcallWord` reads `returndatasize()` and
copies at most 32 bytes, and the registry reads the verifier's answer the same way. A test compares a leaf
returning 600,000 bytes with one returning 64: the difference in the cost of the evaluation is the leaf's own
cost of producing the buffer.

Going through the leaf call again turned up three more things:

- The node array did not have to be a tree: two composites could name the same child, each path was evaluated,
  and 22 nodes could call one leaf 1,024 times. Section 6.1 always said "tree"; it is now enforced, so a
  predicate has at most 63 leaves and each is called at most once.
- A decided composite stops: `anyOf` at its first `SATISFIED` child, `allOf` at its first `NOT_SATISFIED` child
  (index order is a MUST, stopping a SHOULD). Outcomes are unchanged, and in the scenario of your first post the
  subject on the allowlist no longer pays for the broken external verifier. The depth limit moved into the
  well-formedness check for that reason: checked while descending, it would miss a branch that is skipped, and
  the same predicate would be an outcome for one subject and malformed for another.
- What the bound does not fix, in two parts. Under EIP-2929 the gas a leaf needs depends on what the transaction
  has already touched (access list, earlier calls, sibling leaves), so a leaf close to the bound can still be
  `VERIFIER_ERROR` in a preview and answer in the admission. And the gas limit reaches a leaf that reads the
  sender's native balance, because the sender is charged gas limit times gas price before execution. I found no
  way to remove either in the composite verifier; Section 6.3 names both and asks leaf verifiers to fit the
  bound from a cold start and not to read the sender's balance.

The price of checking before the call is headroom: each leaf call needs about 64/63 of the bound available at
that moment, whatever the leaf will use, so an admission that calls even one cheap leaf needs a gas limit above
1,000,000 (the unused part is not spent, and a simulated estimate includes it). A leaf that burns its gas still
costs the whole bound each time it is called; the Security Considerations give the worst case as the number of
leaves that can be called times the bound.

Tests: 226 pass (163 before). `test/unit/LeafGas.t.sol` scans the funding point gas by gas with a raw-bytecode
leaf that shows it is given exactly the bound, for `verify` and for `contains`, and fuzzes the caller's gas.
Twenty-five mutated contracts (a 150 gas margin, 900 gas too many forwarded, the check moved after the call, a 4
KB copy, a registry accepting any answer size, and so on) each fail at least one test. `leafGasLimit()` changes
the interface identifier of `IAIFPCompositeVerifier` to `0xe3fe3554`; predicate encoding and hashes are
unchanged. The same revision carries fixes from a review of my own that are not about the leaf call (admission
previews, re-admission in frozen channels, the objection-window companion); section 8 of `docs/design-memo.md`
lists them, with what was noted and left for the next round. Sepolia still runs the v0.1.1 build and will be
redeployed once this revision has been looked at.

Does the check before the call hold up for you, and do you see a way around either of the two dependences that I
missed?

## Reply on decisions within one block (fifth post; reply of 2026-11-10)

The question (fifth post in the thread): a channel accepts a contribution and the contributor's role is revoked
later in the same block, so both transactions carry the same timestamp. What does `evaluate` return for that
timestamp, and if it reports the role as revoked by the end of the block, what does an auditor use to verify that
the contributor was authorized when the contribution was accepted?

Reply:

---

@SergeevDmitry both questions have a definite answer, and the second exposed a gap: at 594c7ee the anchored
record did not say which binding it had relied on. v0.1.3 of the reference (in the repository and in PR #2152)
closes it.

**What `evaluate` returns.** Once the revocation is recorded, `evaluate(..., t)` is `NOT_SATISFIED`, unless the
contributor holds another binding for the role. A revocation at `t` excludes `t` from the binding's interval,
and changes recorded at one timepoint apply in transaction order (Section 4). A read made between the two
transactions returned `SATISFIED`; once the clock has passed `t` the read for `t` is final.

**What the auditor uses.** The record written when the contribution was accepted, not a later re-evaluation:

- `evaluateWithBinding(...)` on the participation registry returns the outcome and, when it is `SATISFIED`, a
  binding that satisfies the check.
- The event anchor stores and emits that binding: `EventRecord` and `EventAnchored` now end with `bindingId`,
  next to the `ruleVersion` and `at` they already carried. The objection-window companion names the binding in
  its events too.
- Section 10 states the audit rule. A record is authorized if the binding it names belongs to the record's
  subject and channel, covers the role and scope the action needs, and is applicable and `SATISFIED` at the
  record's timepoint when only the changes recorded before the record are counted. Within the record's own
  timepoint, "before" is the order of the logs in the chain: block number, transaction index, log index.

In your scenario the auditor finds `EventAnchored(..., at = t, bindingId = x)` followed by `RoleRevoked(x, at =
t)`: the acceptance was authorized, and a second contribution by the same subject later at `t` is refused. This
is evaluation scenario 12 in the draft and `test/unit/DecisionEvidence.t.sol` in the repository.

**Why the boundary stays.** Letting a revocation at `t` take effect at `t + 1` would make the read agree with
the record, but a revoked binding would stay usable for the rest of the timepoint, also by transactions that
follow the revocation in the same block. I prefer a read that fails closed and evidence that sits in the record.
Moving the boundary would not make the read sufficient anyway, because it errs in the other direction too: a
binding granted, or suspended and reinstated, later within `t` reads as `SATISFIED` although an action attempted
before that was refused, and a binding granted, used and revoked within one block does not read as held at any
timepoint. The Security Considerations list these cases under "Reads within a timepoint".

Limits, stated in the text: `bindingId` is a witness that the role was held (the earliest-created binding that
satisfies the check), not a statement about the capacity in which the subject acted; a contract cannot apply the
audit rule on chain and relies on the recorder, the full verification being a replay of the registries' events
with the clock values of their blocks; and a transport that accepts off chain has no position in the chain, so
it records the block whose state it read together with the binding.

For implementers: `evaluateWithBinding` changes the interface identifier of `IAIFPParticipationRegistry` to
`0x1d84a105`; `EventRecord` and `EventAnchored` gain `bindingId` as their last member, the existing members keep
their order; a refused anchor reports the outcome of the role check, so a binding pending re-admission is not
reported like a missing one. Checking the rule-version half of the same evidence I also found and fixed a bug in
`paradigmAt`: with adoptions recorded out of effective order it kept the last one recorded instead of the one
with the latest effective timepoint (scenario 14).

One thing I left alone and would like your view on. The same question applies to the registries' own management
calls: a manager grants a role, and the manager's `MANAGE_ADMISSION` binding is revoked later in the same block.
`RoleGranted` names neither the caller nor the binding that authorized the caller. Section 10 now says that for
those calls the evidence is the transaction (its sender, or its call trace when the caller is a contract) and
the order of the logs. The alternative is one more event naming caller, basis and binding for every role-gated
management call. Is the transaction enough for the audits you have in mind, or should the log carry it?

## Reply on management events (eighth post; reply of 2026-11-10)

The follow-up (eighth post): scenario 12 covers the case asked about. For management calls the authorization
evidence should go into the existing event: when a smart wallet grants a role the transaction sender alone does
not tell an auditor which account the registry authorized; `RoleGranted` could record the caller, the basis of
the grant and the manager's `bindingId` when a role check was used, so that an indexer can check the grant
against the role history in log order without a call trace.

Reply:

---

@SergeevDmitry done, in the existing events. Every management event of both registries now ends with three
fields: `by` (the caller), `authorityKind` (0 the channel authority, 1 a governance executor with the required
effect, 2 a holder of the management role, 3 the subject of the binding acting for itself) and
`authorizingBinding` (the manager's `bindingId` when the grounds are a role, zero otherwise). That covers
`RoleGranted`, `RoleSuspended`, `RoleRevoked` and `RoleReadmitted` in the participation registry and
`ParadigmAdopted`, `BindingDeclared`, `BindingRevoked` and `DisclosureRecorded` in the channel registry;
`RoleReinstated` is unchanged, since its authority is the `RoleSuspended` log. The grounds are examined in the
order of Sections 8.4 and 9.2, so an authority that also holds the role is reported as the authority.

Section 10 now states the rule for management events in the same terms as for anchored records: the event is
authorized if the binding it names belongs to the caller's subject and channel, covers the role and the scope,
and is `SATISFIED` at the event's timepoint counting only the changes recorded before it in log order; for the
authority and for an executor the grounds are the `AuthorityTransferred`, `ChannelOpened`, `BindingDeclared` and
`BindingRevoked` logs before it. The smart-wallet case is exactly where this matters, and a test covers the
same-block version of it: a manager grants a role and its `MANAGE_ADMISSION` binding is revoked later in the
same block; the grant names that binding, and the `RoleGranted` log precedes the `RoleRevoked` log.

The fields are appended, the existing ones keep their order, and events are not part of the ERC-165 identifiers,
so no interface id changes. 229 tests. In the repository and in PR #2152.

## Reply to the review of the gas check (tenth post; reply of 2026-11-11)

The review (tenth post, of commit 70a696f0): `hasGasFor` keeps the 10,000 margin on top of 64/63 of the bound and
the 2,600 for a cold leaf address comes off before the split, so a leaf gets the full bound on its first call in
the transaction - no gap in the check itself. Both remaining dependences are narrower than the text said: warm
access is never more expensive than cold, so a leaf that fits the bound from a cold start answers the same in the
preview and in the admission, and what still diverges is a leaf that reads `gasleft()` after touching state; on
the balance, no opcode exposes the transaction's gas limit and `eth_call` usually runs at gas price 0, so the
preview overstates the balance every time. And under EIP-7825 (2^24 gas per transaction) 17 leaves that burn
their bound do not fit in one evaluation, so an `anyOf` with that many broken leaves ahead of the satisfying one
can never be admitted - for the worst case in the Security Considerations.

Reply:

---

@Zealynx thanks for checking the check. The 2,600 comes off first because `_eval` reads the leaf's code size
before `_callLeaf`, so the account is warm by the time `hasGasFor` runs; the margin then only has to cover the
call itself and the opcodes in between.

All three narrowings are right, and they are now in the text, nothing else changed:

- **Touched state.** Section 6.3 states the dependence one way: warm access never costs more than cold, so a
  leaf that completes within the bound from a cold start completes in every transaction and answers the same in
  a preview and in the admission; a leaf whose cold cost exceeds the bound is `VERIFIER_ERROR` cold and can
  answer warm. It names the case you describe next to the balance case: a leaf that reads `gasleft()` after
  touching state sees what its reads cost and can answer differently however exactly the bound is forwarded. The
  SHOULD now covers it (a leaf verifier should not make its answer depend on the gas it has left).
- **Balance.** Added that no opcode exposes the transaction's gas limit, so nothing on chain can correct for the
  charge, and that an `eth_call` at gas price zero does not reduce the balance at all, so a preview overstates
  it every time.
- **EIP-7825.** In the Security Considerations, with the figure: under the 2^24 cap a transaction funds at most
  16 leaf calls of 1,000,000 gas, so an `anyOf` with 17 or more faulty leaves ahead of its satisfying child can
  never be admitted under the reference bound, whatever the caller supplies, and the 63-leaf limit of 6.1 is a
  limit on shape, not a guarantee that a predicate can be evaluated. Authors are told to put the conditions most
  likely to decide a composite first and, where many delegated leaves are needed, to evaluate under a composite
  verifier with a lower bound; the bound is a property of the deployment and `leafGasLimit()` reports it, so
  that option exists without a change to the specification.

In the repository and in PR #2152. Sepolia next: I will redeploy the v0.1.3 stack and rerun the evidence cases,
and post the record here.
