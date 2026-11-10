# Boundary cases

The twelve cases below are the acceptance set for the reference implementation. Each has a Foundry suite under
`test/cases/`; cases 1, 4, 5, 8, 9 and 11 also run on a live chain through `script/Cases.s.sol` (two phases, see
the script header). Three logical participants take part: **A** (channel authority, FOGA cell A), **B** (cell B)
and **C** (a third participant), plus **O**, an outsider. Without C the separation of contributors from
observers and the mutual invisibility of submitters could not be shown.

The right-hand column names which of the six corrections adopted before implementation each case exercises:

| Code | Correction |
| --- | --- |
| K1 | Authorization is addressable: every grant has a `bindingId` and a `scopeRef`; evaluation, suspension and revocation name a binding and a scope; `rolesOf` is a summary, never an authorization basis; `authorizationRef` confers nothing by itself. |
| K2 | Historical validity, present admission and the clock are distinct: an accepted event keeps its validity whatever is recorded later, and a read of its timepoint is final once the clock has passed it (within the timepoint of acceptance the evidence is the record, which names the binding relied on, not a re-evaluation); admission always happens at the registry's ERC-6372 clock and takes no timepoint; one deployment is one clock domain; same-timepoint order is the order in the chain. |
| K3 | Disclosure irreversibility constrains facts, not permanent read rights: a disclosure record cannot be treated as not having happened; future provision can be restricted (also for existing objects) by an appended record; neither record proves that copies were read or deleted. |
| K4 | Division of validation: the canonical validator checks descriptor format and the decidable label conditions off-chain; the contracts check hashes, authority, versions, state and verifier results; `hasLabel` means "registered", not "behaves as". A kind the verifier does not know makes a predicate UNDETERMINABLE before anything else is judged; composite lists are non-empty. |
| K5 | Subject references are one canonical encoding (`keccak256` of `<scheme>:<domain>:<identifier>`); an address is never left-padded; the chain id is part of the identity. |
| K6 | Absence semantics require an authoritative window agreed in advance; a silent window triggers the agreed default only when its integrity is confirmed; the outcome proves the condition, never consent or receipt. |

## Case table

| # | Case | Test file | Assertions that must hold | Corrections |
| --- | --- | --- | --- | --- |
| 1 | Strangers shake hands (Open Link to Bonded Link) | `Case01_Handshake.t.sol` | A's acceptance = scoped grant + roster entry; B's acceptance = self-admission with PREDICATE basis; both bindings live only in the link scope; channel-wide and other scopes stay NOT_SATISFIED; no management or redistribution bits; an outsider cannot self-admit; B cannot adopt rules, grant or disclose; a one-sided grant without B's act stays one-sided. | K1, K5 |
| 2 | Stranger enters a private room with a credential | `Case02_CredentialEntry.t.sol` | Wrong proof reverts NOT_SATISFIED, missing proof reverts UNDETERMINABLE, nothing is recorded either way; a valid proof admits OBSERVE in one room scope only; SUBMIT is granted separately by a manager; the relationship-based roles of B are unaffected by the credential rule; a reverting verifier is VERIFIER_ERROR. | K1, K4 |
| 3 | Announcement channel: Source + Archive, push + pull | `Case03_SourceArchive.t.sol` | Two transport bindings (stream, pull + retained history) under one paradigm carrying both labels; readers self-admit by rule, only A publishes; revoking the push binding changes no label and no adoption. | K4 |
| 4 | Panel becomes Club | `Case04_PanelToClub.t.sol` | Before `effectiveAt` nothing changes and SUBMIT has no predicate; at `effectiveAt` the version in force flips and observers acquire SUBMIT by rule; pre-change bindings are pending (UNDETERMINABLE, not denied) until confirmed or re-proved; history before the change evaluates under the panel rules; the adoption record carries `authorizationRef` and the re-admission flag; no disclosure record is created by opening the floor. | K1, K2, K3 |
| 5 | Sealed bids to one collector | `Case05_SealedBids.t.sol` | Both bidders hold SUBMIT; each reads only its own lane and the collector reads all; commitments are anchored before the deadline; after it each bidder supersedes its own commitment, nobody can reveal for another; commitments stay anchored as history; collecting records no decision. | K1, K2 |
| 6 | Shared blackboard | `Case06_Blackboard.t.sol` | Versions v1->v2->v3 anchored by A, B, C with `supersedes` relations and increasing timestamps under one rule version; each version keeps its author; an observer without MODIFY cannot update; retraction of a version is reserved to its author and marks rather than erases. | K1, K3 |
| 7 | Club with different receive policies | `Case07_ReceivePolicies.t.sol` | Gate 1 (channel allows the publisher), gate 2 (receiver may read) and gate 3 (receiver accepts) are independent; local policies use the predicate grammar and are evaluated off the registry; flipping a local policy changes nothing on-chain; willingness to receive grants no reading right. | K4 |
| 8 | Rule update, revocation, replay | `Case08_RuleUpdateReplay.t.sol` | `paradigmAt` is explicit per timepoint; the old predicate admits before and is rejected by hash after the change; the new rule requires roster membership; an accepted post stays valid at its timepoint after a later revocation; revocation excludes its own timepoint; admission has no timepoint parameter and a grant cannot be back-dated; an expired binding yields no present permission but keeps history; a same-timepoint tie goes to the later-recorded adoption. | K2, K1 |
| 9 | Forward, derive, disclose, restrict | `Case09_ForwardDeriveDisclose.t.sol` | Forwarding needs REDISTRIBUTE and keeps the object reference, author and origin; a derivation is a new object owned by the deriver and pointing back to its sources; disclosure to the public audience is recorded by the disclosure manager; a later RESTRICTED record is appended and the earlier DISCLOSED record is unchanged; a closed room can still record what was once disclosed. | K3, K1 |
| 10 | Staked Agora | `Case10_StakedAgora.t.sol` | The stake predicate carries chain, contract, asset, amount and period; no evidence is UNDETERMINABLE; wrong chain, wrong contract or insufficient amount is NOT_SATISFIED; enough stake admits with PREDICATE basis; `previewAdmission` agrees with `admit`; the kernel holds no funds; two subjects presenting the same stake are both admitted (stake proves cost, not independence). | K4, K1 |
| 11 | Objection window | `Case11_ObjectionWindow.t.sol` | A complete silent window resolves DEFAULT_TRIGGERED only after the deadline; one objection inside the window resolves OBJECTED; a channel frozen and released during the window resolves UNDETERMINABLE without anyone having to report it; resolution changes no binding and records no act for silent parties; a window cannot start in the past. | K6, K2 |
| 12 | Competing-consumer dispatch | `Case12_Dispatch.t.sol` | Candidates (DISCOVER by rule, OBSERVE on the queue) are distinguished from the selected worker (scoped SUBMIT on the task); selection is per task and not channel-wide; re-selection is revoke + grant; the earlier selection stays true at its timepoint. | K1, K2 |

## Unit coverage behind the cases

`test/unit/` fixes the rules the cases rely on: the four-valued truth tables and the empty-list reverts
(`Libraries.t.sol`), the canonical subject encoding (`Libraries.t.sol`), predicate well-formedness and the
composite evaluator's order of evaluation (`CompositeVerifier.t.sol`), family control and label registration
(`ParadigmRegistry.t.sol`), adoption timing, tie-breaking, re-admission epochs, governance executors and
disclosure records (`ChannelRegistry.t.sol`), the full binding life cycle and evaluation semantics
(`ParticipationRegistry.t.sol`), and the event-anchor and objection-window companions
(`EventAnchorAndWindow.t.sol`).

## Running

```
forge test                       # all suites (no submodules; the test base declares its own cheatcodes)
forge test --match-path "test/cases/*"
```

On-chain evidence (anvil shown; on Sepolia use the same commands with `AIFP_DELAY=900` and wait 2 x delay):

```
anvil --port 8545 &
export AIFP_PK_A=<key A> AIFP_PK_B=<key B> AIFP_PK_C=<key C>
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast            # writes deployments/<chainid>.json
AIFP_PHASE=1 AIFP_DELAY=60 forge script script/Cases.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
cast rpc evm_increaseTime 125 --rpc-url http://127.0.0.1:8545 && cast rpc evm_mine --rpc-url http://127.0.0.1:8545
AIFP_PHASE=2 forge script script/Cases.s.sol --rpc-url http://127.0.0.1:8545 --broadcast  # writes deployments/<chainid>.cases.phase2.json
```

Expected read-outs in the phase-2 record: `case4.bPendingBeforeConfirm = 2`, `case4.bHistoryBeforeChange = 0`,
`case8.oldRuleRejectedAfterChange = 1`, `case8.bHistoryUnderV1 = 0`, `case8.bNowAfterRevocation = 1`,
`case9.disclosureRecords = 2`, `windowStatus = 1` (DEFAULT_TRIGGERED).
