# AIFP design memo (v0.1.1)

This memo records the design reasoning behind the ERC text in `ERCS/erc-aifp.md`. The normative text is the
ERC; this document explains why it is shaped as it is and lists what was deliberately left out of version 1.

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
