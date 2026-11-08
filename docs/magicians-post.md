# Ethereum Magicians post (draft)

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
