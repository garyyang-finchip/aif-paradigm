# AIFP design memo (v0.1.3)

This memo records the design reasoning behind the ERC text in `ERCS/erc-aifp.md`, filed as ERC-8489. The
normative text is the ERC; this document explains why it is shaped as it is and lists what was deliberately left
out of version 1.

## 1. Position

Ten earlier covenants in the same line define who (identity, credentials), what (skills, task tenders,
economic units), how decisions and disputes are settled, how safety specifications are adopted, how swarms
form and how resources are discovered. None of them defines how information moves between those actors.
AIFP is that layer: it says, for one interaction context, who may provide, observe, respond to, share and
redistribute information, under which version of the rules, and how roles and rules change over time.

Working definition: AIFP defines how actors provide, accept, observe, respond to, share and redistribute
information in an explicit interaction context under identifiable, versioned rules, and how participation,
visibility and relations change with those rules and with time. "Information" covers messages, opinions,
evidence, structured data, observations and shared-state changes; an "interaction context" may be a meeting,
a thread, a subscription topic, a query, a shared document or a running event stream.

An explanatory reading in agent-communication terms (a reading aid, not a redefinition): agent communication
protocols - task and tool protocols, room-based chat, federated feeds, signed-event relays, encrypted groups,
on-chain event logs - each decide how messages move and each fix their own notion of who may read, write and
forward. AIFP does not replace them; it states those permissions, and the rule version behind them, in a form
that every participant and every transport can verify. In that reading a paradigm is a communication pattern, a
channel is a communication context, a role binding is a listener, speaker, forwarder or moderator permission,
and a transport binding is the attachment of a concrete protocol to the context: the protocol carries the
conversation, AIFP records its rules.

Two layers: a chain- and transport-agnostic paradigm model (carriers, operators, dimensions, named
paradigms, event model), and an on-chain binding of rule versions, authority state, participation and
disclosure records that gives independent operators a shared verifiable basis. The guarantee boundary has
three segments - declaration (what the registry proves), enforcement (what transports and key management
do) and evidence (what off-chain behaviour requires) - and only the first is normative here.

## 2. Premises for the agent world

| Human-world premise | Agent-world correction | Consequence in the design |
| --- | --- | --- |
| attention is the scarce resource | attention changes shape; context, compute, verification, latency and funds remain finite; subscribing is not processing | open contribution with receive-side policy, selective dispatch and shared state to control processing cost |
| one body, one identity | low marginal cost of identities; stake raises the cost of behaviour, does not prove independence | admission is a composable condition; counts of subjects are never trusted on their own |
| speech cannot be signed | speech can be signed; forwarding keeps integrity evidence, processing creates a new object | `forward` and `derive` are different operators and relations; propagation is not evidence |
| listening is safe | reading may be executing | role bindings authorize information actions only; authority to act comes from elsewhere |
| forgetting is the default | retention is a declared policy | history dimension: late-joiner visibility, retention, mutability |
| a venue has one audience | one venue, role-conditioned boundaries (agents contribute, humans observe) | boundaries are declared per role, not per venue |

## 3. Generative model

Carriers: `delivery` (addressed, permitted and actually-received sets differ) and `shared-object`
(cooperation through object changes). Operators: fan-out, fan-in, feedback, n-party, select, forward,
derive, merge; duality check - every operation has an inverse except disclosure, which is why disclosure
monotonicity is the root of all migration rules. Thirteen rule dimensions, each declared separately, plus two
extension dimensions (economic, modality). Named paradigms (source, intake, direct, panel, club, meeting,
archive, blackboard, dispatch, forward, derive) are labels whose decidable identification conditions a
validator checks; conditions may overlap; no label changes implicitly.

Completeness is argued by (1) closure of the generative model under composition, (2) explicit compatibility
rules, (3) a counterexample list and a coverage table of 25 human and agent scenarios (every one expressible
without a new operator; six needed the dimensions added in this version: disclosure timing, contributor
visibility, supersede/retract relations, absence semantics and clock reference, ordering, representation),
and (4) an open-world rule: `aifp:ext/` namespace, `unspecified` values, and `UNDETERMINABLE` for anything
not understood.

## 4. Six corrections adopted before implementation

1. **Authorization addresses a binding and a scope.** Every grant creates a `bindingId`; `evaluate` takes a
   scope; suspension and revocation name a binding; `rolesOf` is a summary; `authorizationRef` confers
   nothing; call permissions are tabulated per function; the pending state and the re-admission path are
   explicit.
2. **Historical validity, present admission and the clock are separate.** Accepted events keep their
   validity when delivered late; first-time admission uses the registry clock, never a sender-asserted
   timepoint; one deployment is one immutable clock domain exposed through ERC-6372; same-timepoint order is
   deterministic.
3. **Disclosure irreversibility constrains facts, not permanent read rights.** Disclosure records are
   append-only; future provision may contract, including for existing objects, through a `RESTRICTED`
   record; contraction does not prove deletion; `supersedes`/`retracts` keep history and basis without
   requiring the old content to stay readable; a `DISCLOSED` record does not prove the audience read.
4. **Validator and contract divide the work.** The deterministic validator checks format, compatibility
   rules and the finite label conditions; the contracts check hashes, family control, succession, state and
   the verifiers' outcomes; `hasLabel` means registered. Required extensions are checked before composition;
   composite lists are non-empty.
5. **One subject encoding, fixed now.** `keccak256` of `<scheme>:<domain>:<identifier>` with chain and
   registry in the domain; no left-padded addresses; plain references are not privacy commitments.
6. **"No objection" needs an authoritative window.** Default consequences trigger only inside a pre-agreed
   window with an objection role, a registration place, a deadline and an integrity condition; otherwise
   `UNDETERMINABLE`; the result proves the condition, not consent or receipt.

## 5. Kernel

Three registries plus a verifier:

- `AIFPParadigmRegistry`: `paradigmId = keccak256(JCS(descriptor))`, family controller (first registrant),
  succession within the family, labels as declarations, per-role predicate hashes, descriptor bytes emitted
  once.
- `AIFPChannelRegistry`: append-only adoptions with `effectiveAt >= clock()`, `paradigmAt(t)` with
  later-recorded-wins ties, re-admission epochs, transport/governance/economic bindings with capability and
  effect bits, append-only disclosure records of two kinds, Active/Frozen/Closed with Closed terminal.
- `AIFPParticipationRegistry`: manager path (`grant`) and admission path (`admit`, reverting with the
  obtained outcome on anything but `SATISFIED`), suspension intervals with the suspender recorded,
  terminal revocation, re-admission (`readmit` by the subject for predicate bindings, `confirmReadmission`
  by a manager otherwise), `evaluate(channel, subject, role, scope, timepoint)` as a pure function of history.
- `AIFPCompositeVerifier`: decode, reject malformed trees, unsupported kind means `UNDETERMINABLE` before
  composition, leaves evaluated natively or delegated with revert/no-code/out-of-range mapped to
  `VERIFIER_ERROR`, four-valued allOf/anyOf.

Optional profiles: event anchor (actions, relations, author-only supersede/retract, forward keeps the
reference), objection window (companion), committed subjects and receive-policy commitments (interfaces
deferred).

## 6. Deliberately out of scope in version 1

- Message transport and content encoding: attached through transport bindings.
- A negation operator in predicates: `not(UNDETERMINABLE)` is still undeterminable.
- A universal trust score or handling levels with normative force.
- On-chain interfaces for committed subjects and receive-policy commitments.
- Enforcement of transport capabilities: the registry records claims; proof lives with the transport.
- Scoped anchoring in the event-anchor profile (role checks are channel-wide); a `scopeRef` parameter is a
  candidate for a later revision.

## 7. Verification plan

Twelve boundary cases (`docs/boundary-cases.md`) cover handshake, credential entry, source + archive,
panel-to-club migration, sealed bids, blackboard, receive policies, rule update and replay, forward/derive
and disclosure, staked agora, objection window and dispatch, with three logical participants. Cases 1, 4, 5,
8, 9 and 11 also run on a live chain through `script/Cases.s.sol`. The Sepolia run uses three
session-generated keys funded from a faucet; its records are committed under `deployments/`.

## 8. Changes after review

**v0.1.2 - leaf return data and the gas of a leaf call (reported on the Magicians thread, 2026-11-09).** The
reference composite verifier called leaf verifiers with `try ... returns (uint8)` and subject sets with
`try ... returns (bool)`. Solidity decodes a typed return value in the caller, so a verifier that returned no
data, or a word above 255 (above 1 for the set), reverted the whole `evaluate` instead of becoming that leaf's
`VERIFIER_ERROR`; the participation registry's own `try/catch` then reported `VERIFIER_ERROR` for the whole
predicate, and `anyOf(allowlist, external)` with one broken external verifier refused subjects that the
allowlist admits. The fix makes each leaf call a low-level `staticcall` bounded to `LEAF_GAS_LIMIT`
(1,000,000 gas) and judges the raw return data: success, exactly one 32-byte word, value at most 3 (0 or 1 for
`contains`); anything else is `VERIFIER_ERROR` for that leaf only. Sections 2.5, 6.3, 6.4, the Rationale and the
Security Considerations of the ERC now state the rule (malformed return data is a leaf fault; a leaf fault never
aborts the tree; the gas forwarded to a leaf SHOULD be bounded and the bound documented), and evaluation scenario
9 plus the suite `test/unit/LeafReturnData.t.sol` (eleven tests, mock `MisbehavingVerifier`) cover empty, short,
long and out-of-range return data, a gas-exhausting leaf, and the registry admitting a subject in the allowlist
despite a broken external leaf. The Sepolia deployment recorded in `docs/sepolia-evidence.md` predates this
change; its verifier is the v0.1.1 build.

**v0.1.3 - gas-independent outcomes, bounded return-data copy, decisions within a timepoint (second review
round on the Magicians thread, 2026-11-09, followed by two internal adversarial reviews of the result; the
second one, on 2026-11-10, is the source of items 5b, 6b, 7b and 11 to 15).**

*The leaf call.*

1. *A leaf that needs more than the bound* is `VERIFIER_ERROR` under that composite verifier however much gas
   the caller supplies. The bound is now a fixed amount (MUST, it was SHOULD) reported through
   `IAIFPCompositeVerifier.leafGasLimit()`; the reference figure of 1,000,000 gas is a property of the
   implementation: ample for a pairing-based proof check, too small for a verifier that needs several million.
2. *A starved leaf.* A call receives at most 63/64 of the gas left, so with less than about 64/63 of the bound
   remaining a leaf was given less than the bound; the same leaf could pass in `previewAdmission` over
   `eth_call` and come back `VERIFIER_ERROR` in an `admit` sent with a tight gas limit. The rule adopted is
   stronger than the fix suggested (revert when `gasleft() < LEAF_GAS_LIMIT / 63` after the call): **the gas
   supplied to an evaluation must not decide its outcome**. The verifier checks before each leaf call that the
   full bound can be forwarded (`AIFPCalls.hasGasFor`: bound * 64 / 63 plus a 10,000 gas margin for the call
   itself, which covers a cold account and a cold EIP-7702 delegate) and otherwise reverts with
   `AIFP_InsufficientGas()`; every leaf that is called receives exactly the bound, which a raw-bytecode probe
   confirms to the gas. The check after the call was tried and rejected: it recognizes a starved leaf only when
   the leaf used up everything it was given, and two probe leaves that do not - one that reads its own gas, one
   that catches an inner out-of-gas and answers `UNDETERMINABLE` - still produced gas-dependent outcomes.
3. *Return data copy.* `(bool, bytes memory) = staticcall(...)` copied the whole return buffer into the
   verifier's memory, a cost the leaf's bound did not cover (about 700 KB fit in the bound, and copying them cost
   the verifier roughly as much again). `AIFPCalls.staticcallWord` reads `returndatasize()` and copies at most 32
   bytes; the registry reads the composite verifier's answer the same way.
4. *The registry never turns a failed evaluation into an outcome.* The first version of this fix kept
   `VERIFIER_ERROR` for a composite verifier that reverted "for another reason" and told the reasons apart by the
   gas left after the call. That test is exact only when nothing sits between the registry and the evaluating
   code (behind a minimal proxy the inner frame runs out and the outer one keeps 1/64), and it contradicted
   Section 6.4, which calls a malformed predicate a caller error and not an outcome. The registry now reports an
   outcome only for a successful call that returns one word of at most 3; anything else reverts -
   `AIFP_InsufficientGas()` when the verifier said so, `AIFP_EvaluationFailed(bytes4)` with the verifier's own
   selector otherwise - and no arithmetic on leftover gas decides between an outcome and a failure.
5. *What the bound cannot fix.* State access is cheaper for what a transaction has already touched (2,100 gas
   for a cold slot, 100 for a warm one), so the gas a leaf needs depends on earlier calls, on the access list and
   on sibling order; a leaf close to the bound can be `VERIFIER_ERROR` in a preview and answer in the admission.
   The specification says so (Section 6.3) and expects leaf verifiers to fit the bound from a cold start;
   `previewAdmission` and `admit` were not made to touch the same state first, because access lists and batched
   calls would reopen the difference anyway.

   5b. *The gas limit also reaches a leaf through the sender's balance.* The sender of a transaction is charged
   the gas limit times the gas price before execution, so a leaf that reads the native balance of the sending
   account is handed exactly the bound and still answers according to the gas limit. The second internal review
   showed it with real transactions on a local chain (a leaf requiring 1 ETH, a subject holding 1.05 ETH, 20 gwei:
   `SATISFIED` at a gas limit of 2,000,000 and `NOT_SATISFIED` at 5,000,000, and `SATISFIED` in an `eth_call`
   without a gas price). No composite verifier can remove this. The rule is therefore stated as what a verifier
   can guarantee - the gas supplied to an evaluation does not decide its outcome - and Section 6.3 names the two
   properties of a transaction that still reach a leaf and asks leaf verifiers not to depend on either. The case
   is not in the suite: the test runner does not charge a sender for gas.
6. *The predicate array has to be a tree.* `isWellFormed` accepted arrays in which two composites named the
   same child; such a node was evaluated once per path, and 22 nodes could call one leaf 1,024 times. Section 6.1
   always said "tree"; the library now enforces it (no node with two parents, no node unreachable from the root),
   so a predicate has at most 63 leaves and each is called at most once.

   6b. *The depth limit belongs to well-formedness.* The limit of 8 was checked while descending. Once a
   decided composite stops (item 7), a branch that is skipped was never checked: `anyOf(open, <too deep>)`
   answered `SATISFIED`, the same nodes in the other order reverted, and `anyOf(allowlist, <too deep>)` admitted
   a subject on the allowlist while it was malformed for everyone else. `isWellFormed` now computes the depth of
   every node in its single pass (the root is 0; a parent always precedes its children), so a predicate is
   malformed for every subject or for none. Section 6.1 defines depth and says that well-formedness is judged on
   the whole array before anything is evaluated; `AIFP_DepthExceeded` is gone, a tree that is too deep reverts
   with `AIFP_MalformedPredicate` like any other malformed array.
7. *A decided composite stops.* An `anyOf` stops at its first `SATISFIED` child and an `allOf` at its first
   `NOT_SATISFIED` child (SHOULD in Section 6.4; children are evaluated in index order, MUST). The outcome is the
   same as with every child evaluated - checked against the composition tables for every combination of three
   leaves and by a fuzz over nested trees - and the leaves that are skipped are not called: in the scenario that
   opened the thread, a subject on the allowlist no longer pays for the broken external verifier at all.
   What remains is stated in the Security Considerations: a faulty leaf that is called costs the whole bound, and
   a predicate whose leaves can together cost more than one transaction may carry can be made unevaluable.

   7b. *Kinds are checked before the structure.* A node of a kind the verifier does not know was treated as a
   leaf by the well-formedness check, so an unknown kind with children - what a composite kind added later would
   look like - reverted as malformed instead of answering `UNDETERMINABLE`. A verifier that does not know a kind
   cannot tell whether a node of that kind has children, and so cannot judge the structure at all: the kind check
   now comes first (Section 6.4, five steps), and the answer is `UNDETERMINABLE` whatever the child fields say.

*Decisions within a timepoint.*

8. *Accepted, then revoked, at one timepoint.* All transactions of a block share a clock value. A revocation at
   `t` excludes `t`, so after it `evaluate(..., t)` is `NOT_SATISFIED` although a contribution anchored earlier at
   `t` was authorized when it was accepted. The boundary is kept (a read after a revocation fails closed; moving
   it to the next timepoint would leave a revoked binding usable for the rest of the timepoint) and the record
   carries the evidence instead: `IAIFPParticipationRegistry.evaluateWithBinding` names a binding that satisfies
   a check (the earliest-created one: a witness that the role was held, not a statement about capacity),
   `EventRecord` and `EventAnchored` carry it as `bindingId` next to the rule version they already carried for the
   same reason, and the objection-window companion's events do the same. Sections 4, 9.1, 9.5, 10 and 13.1 state
   the rule: `evaluate` for a timepoint is final once the clock has passed it, reflects the changes recorded so
   far while it has not, and is not the audit path for decisions taken within it; a record is evidence for the
   timepoint of the block that carries it, is authorized by the binding it names when only the changes recorded
   before it are counted, and the order of two records at one timepoint is their order in the chain. The read
   can err in both directions, and the Security Considerations say so: a binding granted, suspended-and-
   reinstated or re-admitted later within a timepoint reads as held although an action was refused within it.
9. *`paradigmAt` and adoptions recorded out of effective order.* Found while checking the rule-version half of
   that evidence: the registry kept the last *recorded* adoption that was effective, so an adoption scheduled for
   a later timepoint never came into force once another one, effective earlier, was recorded after it. It now
   keeps the adoption with the latest effective timepoint, ties to the later record, as Section 8.1 intended; the
   section also says that a superseded adoption still opens the re-admission epoch it required.
10. *Refusals carry the outcome.* `AIFP_RoleNotHeld` and the companion's `RoleNotHeld` now report what the role
    check answered, so that a binding pending re-admission is not reported like the absence of a binding.

*Found by the second internal review, outside the two points raised on the thread.*

11. *A preview reports an outcome only when there was an evaluation.* `previewAdmission` answered `NOT_SATISFIED`
    for a role to which the paradigm gives no predicate, without calling the verifier, and answered in a frozen or
    closed channel where `admit` is rejected. It now makes the same checks as `admit`, in the same order, and
    reverts with the same errors, so a preview no longer answers where the admission path would not have
    evaluated anything.
12. *Re-admission requires an active channel.* `readmit` and `confirmReadmission` were accepted in `Frozen` and
    `Closed` channels although Section 8.3 accepts no grant and no admission there. Both now require `Active`;
    Section 8.3 lists what a frozen or closed channel still accepts (evaluation, suspension, reinstatement,
    revocation, disclosure records; `revokeBinding` in `Frozen` only) and says that an adoption scheduled earlier
    still comes into force.
13. *The objection window confirms integrity instead of presuming it.* The companion marked a window as broken
    only when somebody called `reportIntegrityBreak` while the channel was frozen; a channel frozen for most of a
    window and released before the deadline resolved `DEFAULT_TRIGGERED`, against Section 13.2 and the Security
    Considerations. The current state of a channel cannot show a freeze that has ended, so the reference channel
    registry now counts state changes (`stateChanges`, an extra view like `channelExists`, not part of
    `IAIFPChannelRegistry`), a window records the count when it is opened, and `resolve` confirms integrity only
    if the channel is active and the count has not moved. That is stricter than the rule - a change before the
    start or after the deadline also leaves the window unconfirmed - and errs towards `UNDETERMINABLE`. Two more
    corrections in the same contract: an objection now decides the window whatever happened to the channel (the
    companion answered `UNDETERMINABLE` for an objected window whose channel was frozen at resolution, where
    Section 13.2 says `objected`), and `open` rejects an objection role that is not one defined role bit (a
    window on such a role could never be objected to and triggered its default). `reportIntegrityBreak` and its
    event are removed; `integrityHolds` is a view.
14. *A binding granted while an adoption is scheduled.* Section 9.1 said that a binding granted after an adoption
    was recorded is not pending at its effective timepoint. That is true only when the adoption is already in
    effect at the grant: the epoch recorded for a binding counts the adoptions effective at that position, so a
    binding granted between the recording and the effective timepoint becomes pending like every earlier one. The
    code is the safe behaviour (otherwise a subject could be admitted under the old rules just before the change
    and skip the re-admission); the text was wrong and is corrected in Sections 9.1 and 10 and in the Security
    Considerations, with evaluation scenario 15.
15. *Statements corrected without a change of behaviour.* The audit rule of Section 10 is applied to the events
    together with the clock value of their blocks (the events of a grant and of a re-admission carry no
    timepoint). The management capabilities are not independent of each other: an executor with the rules effect
    can declare a binding with any effect scope, and whoever can grant for the whole channel can grant itself any
    role; "Governance capture" and "Re-admission reaches the managers too" said otherwise. A suspension imposed and
    lifted within one timepoint is visible in the binding's own record, not only in the logs. Section 2.4 no
    longer says that each role bit is suspended and revoked separately (suspension and revocation address a
    binding). Sections 8.1, 8.2, 9.3 and 9.4 gain the definitions that were missing (`effectiveSince`, what the
    rules and participation effects cover, the signatures and selectors of the outcome errors, pending before the
    first admission record, `basisRef` after `readmit`). The Security Considerations gain two paragraphs on limits
    of the reference implementation that are not changed in this round: the cap on bindings per subject, and the
    single namespace of anchored object references.

Interface changes: `leafGasLimit()` is added to `IAIFPCompositeVerifier` (interface identifier `0xe3fe3554`, was
`0xa5913d6e`) and `evaluateWithBinding` to `IAIFPParticipationRegistry` (`0x1d84a105`, was `0x14c97260`). The
errors `AIFP_InsufficientGas()` (`0xc9b4ddbd`, composite verifier and participation registry) and
`AIFP_EvaluationFailed(bytes4)` (`0x69812968`, participation registry) are new. `EventRecord` gains `bindingId` as
its last field and `EventAnchored` as its last parameter; the existing fields keep their order, so a client built
for the earlier record still reads them correctly, and the record is stored packed (six storage slots, as before;
a publish costs about 20,000 gas more than in v0.1.1 because its `action` no longer occupies an empty slot of its
own). The ERC-165 identifier of `IAIFPEventAnchor` does not change (`0x62b24396`): return types and events are not
part of it, so the v0.1.1 anchor on Sepolia reports the same identifier while returning the shorter record.
`AIFP_RoleNotHeld` gains the outcome. The companion's `WindowOpened` gains the binding and the opening timepoint,
`ObjectionRegistered` the binding. A library `AIFPCalls` is added. The predicate encoding and every committed hash
are unchanged; an array that was not a tree, or that is deeper than 8, is no longer accepted on any path, and it
is reported as `AIFP_MalformedPredicate` (the error `AIFP_DepthExceeded` no longer exists). `previewAdmission`
reverts where `admit` would be rejected. The reference channel registry gains the view `stateChanges(bytes32)`
(`0xe14bb695`), which is not part of `IAIFPChannelRegistry`. In the companion, `Window.integrityBroken` is
replaced by `stateChangesAtOpen`, `reportIntegrityBreak` and `IntegrityBroken` are removed, and `integrityHolds`
and the error `ChannelNotActive` are added.

Tests: 226 in all. `test/unit/LeafGas.t.sol` (twenty-three: gas sweeps, a scan of the funding boundary gas by gas
for both kinds of leaf call, two fuzz properties, the warm-storage caveat, a misbehaving composite verifier behind
a registry), `test/unit/DecisionEvidence.t.sol` (fourteen, with a fuzz over random histories for the finality of a
passed timepoint), and additions to the composite-verifier, predicate-library (with a fuzz of `isWellFormed`
against an independent statement of Section 6.1), channel-registry, participation-registry and objection-window
suites; evaluation scenarios 10 to 17 in the ERC. The suite was run
against twenty-five mutated contracts, and each mutant fails at least one test: a margin of 150 gas, the bound
forwarded with 900 gas too many, the 64/63 headroom left out, the check made after the call, a 4 KB copy, a
registry that accepts any answer size or reports a failed evaluation as `VERIFIER_ERROR`, a revocation moved by
one timepoint, the old `paradigmAt`, composition with the precedence swapped or without the equivalence of
stopping early, no depth check or a depth limit off by one, no check for a node with two parents, the structure
judged before the kinds, a preview that ignores the channel state, re-admission or confirmation in a frozen
channel, a window that presumes its integrity, that puts integrity before an objection, that accepts any
objection role or opens in a frozen channel, a counter that counts calls instead of changes, an anchor that drops
the binding, and a witness that is the latest binding instead of the earliest.

Noted in this round and left alone, as candidates for the next one:

- *Management events.* The kernel's management events (`RoleGranted`, `RoleReadmitted`, `ParadigmAdopted`,
  `BindingDeclared`, `BindingRevoked`, `DisclosureRecorded`) do not name the caller or the basis on which the
  caller was authorized - only `RoleSuspended`, `RoleReinstated` and `RoleRevoked` name the caller - and Section 10
  says what the evidence is for them (the transaction and the log order); one added event naming caller, basis
  and binding for every role-gated call is the candidate change.
- *Which channel a redistribution role is needed in.* The event anchor checks the role in the channel named in
  the call, the one that receives the record. For a forward or a derivation it does not consult the channel in
  which the source object was first anchored, although `REDISTRIBUTE` is defined as the right to carry content
  out of a channel; a relation such as `retracts` can likewise be recorded through any channel in which its
  author holds the role. Section 13.1 and the Security Considerations now say what the profile checks; checking
  the origin as well would change what a record means and what it has to name.
- *One namespace of object references.* The first anchor of a reference stands, in any channel, so a reference
  that can be predicted can be anchored first by someone else (Security Considerations, "Anchored object
  references"). Scoping references to a channel, or requiring them to commit to the author, changes the profile's
  interface.
- *The cap on bindings.* It counts every binding ever created for a subject in a channel, in any scope, because
  history has to stay evaluable; a subject that reaches it can receive no further binding there, and a manager of
  a single scope can exhaust it. Bounding the history per scope instead is the candidate change.
- *Management capabilities are not separable.* An executor with the rules effect can give itself any effect, and
  whoever can grant for the whole channel can grant itself any role. The text now says so; restricting which
  roles a manager may grant is a design change.
- *Suspension.* A suspension is lifted only by the address that imposed it, also after that address has lost its
  role, and a binding carries one suspension at a time, so whoever suspends first decides who can lift.
- *State history in the kernel interface.* `stateChanges` is an extra of the reference registry. If the
  objection-window profile is to be implementable over any conforming registry, the interface has to expose it
  (which changes the interface identifier of `IAIFPChannelRegistry`).
- The event anchor accepts in `Frozen` and `Closed` channels. `grant` reports an invalid basis kind with
  `AIFP_InvalidRole`. A per-binding status view and a separate, smaller bound for `contains` were considered and
  not added. A leaf call made at call depth 1,024 fails without executing; reaching that depth with a funded leaf
  needs more gas than any chain carries.

The Sepolia deployment is still the v0.1.1 build.
