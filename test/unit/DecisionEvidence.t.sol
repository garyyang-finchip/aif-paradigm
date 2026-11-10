// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {AIFPEventAnchor} from "../../assets/erc-aifp/contracts/AIFPEventAnchor.sol";

/// @dev Decisions within one timepoint (asked on the ERC-8489 thread): a contribution is accepted and the
///      contributor's role is revoked later in the same block, so both carry the same timestamp.
///      - `evaluate` for that timepoint is a read of what has been recorded so far: SATISFIED before the
///        revocation, NOT_SATISFIED after it, and final once the clock has moved on;
///      - the acceptance was decided in transaction order against a binding that was valid then. The record
///        names that binding, and the order of the two logs shows that the revocation came second.
contract DecisionEvidenceTest is Fixture {
    AIFPObjectionWindow win;
    bytes32 P1;
    bytes32 ch;
    bytes32 bindingB;

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;

    function setUp() public override {
        super.setUp();
        win = new AIFPObjectionWindow(channels, participation);
        P1 = simpleParadigm(A, "fam", "aifp:paradigm/panel/v1", AIFPRoles.SUBMIT, openPredicate());
        ch = openChannel(A, P1);
        grantRoles(A, ch, A, AIFPRoles.SUBMIT, 0);
        bindingB = grantRoles(A, ch, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0);
    }

    function none() internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](0);
    }

    function withBinding(address who, uint16 role, uint48 t) internal view returns (uint8 outcome, bytes32 bindingId) {
        return participation.evaluateWithBinding(ch, subj(who), role, bytes32(0), t);
    }

    /// @dev Position of the first log with `topic0` emitted by `emitter`; reverts when there is none.
    function indexOf(Vm.Log[] memory logs, address emitter, bytes32 topic0) internal pure returns (uint256) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics[0] == topic0) return i;
        }
        revert("log not found");
    }

    // ------------------------------------------------------------ evaluateWithBinding

    function test_evaluateWithBinding_names_the_binding_relied_on() public view {
        (uint8 outcome, bytes32 id) = withBinding(B, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, S, "B holds SUBMIT");
        assertEq(id, bindingB, "the binding that grants it");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), outcome, "evaluate is the first return value");
        (outcome, id) = withBinding(B, AIFPRoles.MODIFY, now48());
        assertOutcome(outcome, N, "B does not hold MODIFY");
        assertEq(id, bytes32(0), "no binding for an outcome that is not SATISFIED");
        (outcome, id) = withBinding(O, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, N, "an outsider");
        assertEq(id, bytes32(0));
    }

    function test_evaluateWithBinding_prefers_the_earliest_created_satisfied_binding() public {
        bytes32 second = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        (uint8 outcome, bytes32 id) = withBinding(B, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, S, "two bindings satisfy");
        assertEq(id, bindingB, "creation order decides");
        // Once the first is suspended the second is the one relied on.
        vm.prank(A);
        participation.suspend(bindingB, bytes32("hold"));
        (outcome, id) = withBinding(B, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, S, "the second binding still satisfies");
        assertEq(id, second, "the suspended binding is not named");
        // A scoped binding does not satisfy a whole-channel check and is never named for one.
        bytes32 scoped = grantRoles(A, ch, C, AIFPRoles.SUBMIT, bytes32("lane"));
        (outcome, id) = withBinding(C, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, N, "scoped only");
        assertEq(id, bytes32(0));
        (outcome, id) = participation.evaluateWithBinding(ch, subj(C), AIFPRoles.SUBMIT, bytes32("lane"), now48());
        assertOutcome(outcome, S, "in its scope");
        assertEq(id, scoped);
    }

    function test_evaluateWithBinding_pending_and_invalid_role() public {
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/panel/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48() + 10, true, 0);
        warpBy(10);
        (uint8 outcome, bytes32 id) = withBinding(B, AIFPRoles.SUBMIT, now48());
        assertOutcome(outcome, U, "pending re-admission");
        assertEq(id, bytes32(0), "a pending binding authorizes nothing");
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.SUBMIT | AIFPRoles.RESPOND)));
        participation.evaluateWithBinding(ch, subj(B), AIFPRoles.SUBMIT | AIFPRoles.RESPOND, bytes32(0), now48());
        assertTrue(participation.supportsInterface(type(IAIFPParticipationRegistry).interfaceId));
    }

    // ------------------------------------------------------------ the record names the binding

    function test_anchor_records_and_emits_the_authorizing_binding() public {
        warpBy(3);
        vm.recordLogs();
        vm.prank(B);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("obj"), none());
        IAIFPEventAnchor.EventRecord memory r = anchor.record(idx);
        assertEq(r.bindingId, bindingB, "record.bindingId");
        assertEq(r.ruleVersion, P1);
        assertEq(uint256(r.at), uint256(now48()));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory log = logs[indexOf(logs, address(anchor), IAIFPEventAnchor.EventAnchored.selector)];
        (uint8 action, bytes32 ruleVersion, uint48 at, uint256 recordIndex, bytes32 bindingId) =
            abi.decode(log.data, (uint8, bytes32, uint48, uint256, bytes32));
        assertEq(uint256(action), uint256(AIFPEvents.ACTION_SUBMIT));
        assertEq(ruleVersion, P1);
        assertEq(bindingId, bindingB, "EventAnchored.bindingId");
        assertEq(uint256(at), uint256(now48()));
        assertEq(recordIndex, idx);
        // The role the action needs decides which binding is named: a respond relies on the same binding here.
        vm.prank(B);
        idx = anchor.anchor(ch, AIFPEvents.ACTION_RESPOND, bytes32("reply"), none());
        assertEq(anchor.record(idx).bindingId, bindingB);
    }

    // ------------------------------------------------------------ accepted, then revoked in the same timepoint

    function test_contribution_accepted_then_role_revoked_in_the_same_timepoint() public {
        warpBy(5);
        uint48 t = now48();

        vm.recordLogs();
        vm.prank(B);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("contribution"), none());
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "before the revocation the read at t is SATISFIED");
        vm.prank(A);
        participation.revoke(bindingB, bytes32("misconduct"));
        assertEq(uint256(now48()), uint256(t), "same timepoint");

        // Question 1: what `evaluate` returns for that timepoint once the revocation is recorded.
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), N, "a revocation at t excludes t");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t - 1), S, "timepoints before t are untouched");

        // Question 2: what an auditor uses. The record names the binding; the binding's interval covers the
        // record's timepoint up to a revocation recorded at that same timepoint; and the logs give the order.
        IAIFPEventAnchor.EventRecord memory r = anchor.record(idx);
        assertEq(r.bindingId, bindingB, "the record names the binding the acceptance relied on");
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(r.bindingId);
        assertEq(b.channelId, r.channelId);
        assertEq(b.subject, r.subject);
        assertTrue((b.roles & AIFPRoles.SUBMIT) != 0 && b.scopeRef == bytes32(0), "covers the role, whole channel");
        assertTrue(b.validFrom <= r.at && (b.validUntil == 0 || r.at < b.validUntil), "inside the interval");
        assertEq(uint256(b.revokedAt), uint256(r.at), "revoked at the record's own timepoint");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 anchoredAt = indexOf(logs, address(anchor), IAIFPEventAnchor.EventAnchored.selector);
        uint256 revokedAt = indexOf(logs, address(participation), IAIFPParticipationRegistry.RoleRevoked.selector);
        assertTrue(anchoredAt < revokedAt, "the acceptance precedes the revocation in the chain");

        // The revocation applies from its position: a second contribution in the same timepoint is refused.
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.SUBMIT), AIFPOutcomes.NOT_SATISFIED));
        anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("too late"), none());

        // Once the clock has passed t the read at t is final.
        warpBy(1);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), N, "final");
        assertEq(anchor.record(idx).bindingId, bindingB, "and the record still says what was decided");
        (uint8 before, bytes32 named) = withBinding(B, AIFPRoles.SUBMIT, t - 1);
        assertOutcome(before, S, "the timepoint before the revocation still reads SATISFIED");
        assertEq(named, bindingB, "through the same binding");
    }

    /// @dev A binding granted, used and revoked within one timepoint: the record is authorized - the grant
    ///      precedes it and the revocation follows it in the chain - although no timepoint ever reads the
    ///      role as held.
    function test_binding_granted_used_and_revoked_within_one_timepoint() public {
        warpBy(5);
        uint48 t = now48();
        vm.recordLogs();
        bytes32 x = grantRoles(A, ch, C, AIFPRoles.SUBMIT, 0);
        vm.prank(C);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("contribution"), none());
        vm.prank(A);
        participation.revoke(x, bytes32("end"));
        assertEq(anchor.record(idx).bindingId, x, "the record names the binding");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 granted = indexOf(logs, address(participation), IAIFPParticipationRegistry.RoleGranted.selector);
        uint256 anchored = indexOf(logs, address(anchor), IAIFPEventAnchor.EventAnchored.selector);
        uint256 revoked = indexOf(logs, address(participation), IAIFPParticipationRegistry.RoleRevoked.selector);
        assertTrue(granted < anchored && anchored < revoked, "granted, then used, then revoked");
        warpBy(1);
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, t - 1), N, "not yet granted");
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, t), N, "the revocation at t excludes t");
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, t + 1), N, "revoked");
    }

    /// @dev The other direction: a read for a timepoint can say SATISFIED although an action was refused
    ///      within it. The read is the state after the last change recorded at the timepoint, nothing more.
    function test_final_read_can_be_satisfied_although_an_action_was_refused_within_the_timepoint() public {
        warpBy(5);
        uint48 t = now48();
        // Not yet granted when it tried.
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(C), uint16(AIFPRoles.SUBMIT), N));
        anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("early"), none());
        grantRoles(A, ch, C, AIFPRoles.SUBMIT, 0);
        // Suspended and reinstated around B's attempt: an interval of zero length.
        vm.prank(A);
        participation.suspend(bindingB, bytes32("hold"));
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.SUBMIT), N));
        anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("blocked"), none());
        vm.prank(A);
        participation.reinstate(bindingB);
        warpBy(1);
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, t), S, "granted at t, so t reads SATISFIED");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "a suspension imposed and lifted at t leaves no trace in a read");
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(bindingB);
        assertTrue(b.suspendedAt == t && b.reinstatedAt == t, "only the binding's own record and the logs show it");
        assertEq(anchor.recordCount(), 0);
    }

    /// @dev With several satisfying bindings the record names the earliest-created one that satisfies at that
    ///      position. It is a witness that the role was held; a later read at the same timepoint can name
    ///      another binding without any revocation, suspension or rule change in between.
    function test_named_binding_is_a_witness_among_several() public {
        bytes32 second = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        warpBy(5);
        uint48 t = now48();
        vm.prank(A);
        participation.suspend(bindingB, bytes32("hold"));
        vm.prank(B);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("contribution"), none());
        assertEq(anchor.record(idx).bindingId, second, "the first binding is suspended, the second is the witness");
        vm.prank(A);
        participation.reinstate(bindingB);
        (uint8 outcome, bytes32 named) = withBinding(B, AIFPRoles.SUBMIT, t);
        assertOutcome(outcome, S, "still held");
        assertEq(named, bindingB, "a read at t now names the reinstated, earlier-created binding");
        assertEq(anchor.record(idx).bindingId, second, "the record keeps the witness of its own position");
    }

    /// @dev A refusal says what the role check answered: a binding that is pending re-admission is not
    ///      reported as if the subject held no binding at all.
    function test_refusal_carries_the_outcome_of_the_role_check() public {
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/panel/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48() + 10, true, 0);
        warpBy(10);
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.SUBMIT), U));
        anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("pending"), none());
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(O), uint16(AIFPRoles.SUBMIT), N));
        anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("outsider"), none());
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(AIFPObjectionWindow.RoleNotHeld.selector, U));
        win.open(ch, bytes32("proposal"), now48() + 10, now48() + 110, AIFPRoles.RESPOND);
    }

    function test_contribution_accepted_then_binding_suspended_in_the_same_timepoint() public {
        warpBy(5);
        uint48 t = now48();
        vm.recordLogs();
        vm.prank(B);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("contribution"), none());
        vm.prank(A);
        participation.suspend(bindingB, bytes32("review"));
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), N, "a suspension at t covers t");
        IAIFPEventAnchor.EventRecord memory r = anchor.record(idx);
        assertEq(r.bindingId, bindingB);
        assertEq(uint256(participation.bindingOf(r.bindingId).suspendedAt), uint256(r.at), "suspended at the record's own timepoint");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(
            indexOf(logs, address(anchor), IAIFPEventAnchor.EventAnchored.selector)
                < indexOf(logs, address(participation), IAIFPParticipationRegistry.RoleSuspended.selector),
            "the acceptance precedes the suspension in the chain"
        );
    }

    function test_contribution_accepted_then_rules_changed_in_the_same_timepoint() public {
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/panel/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        warpBy(5);
        uint48 t = now48();
        vm.prank(B);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_SUBMIT, bytes32("contribution"), none());
        // An adoption effective immediately that requires re-admission, recorded later in the same timepoint.
        vm.prank(A);
        channels.adoptParadigm(ch, P2, t, true, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), U, "pending re-admission from t");
        IAIFPEventAnchor.EventRecord memory r = anchor.record(idx);
        assertEq(r.bindingId, bindingB, "the binding relied on");
        assertEq(r.ruleVersion, P1, "and the rule version in force when it was accepted");
        assertEq(channels.paradigmAt(ch, t), P2, "which a later read at t no longer shows");
    }

    function test_evaluation_is_final_once_the_clock_has_passed_the_timepoint() public {
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/panel/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        warpBy(5);
        uint48 t = now48();
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "at t");
        warpBy(1);
        // Everything that can be recorded later: suspension, reinstatement, a rule change that requires
        // re-admission, a second grant, and finally the revocation.
        vm.prank(A);
        participation.suspend(bindingB, bytes32("hold"));
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "a later suspension does not reach back");
        vm.prank(A);
        participation.reinstate(bindingB);
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48(), true, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "a later adoption does not reach back");
        grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        vm.prank(A);
        participation.revoke(bindingB, bytes32("end"));
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, t), S, "a later revocation does not reach back");
        (uint8 outcome, bytes32 id) = withBinding(B, AIFPRoles.SUBMIT, t);
        assertOutcome(outcome, S, "the read at t is what it was");
        assertEq(id, bindingB, "and still names the binding that held then");
    }

    // History kept by the fuzz test below.
    bytes32[] private _ids;
    uint48[] private _times;
    uint8[] private _outcomes;
    bytes32[] private _names;
    bytes32 private _nextParadigm;

    /// @dev Random histories of one subject's bindings and of the channel's rules. Whatever is recorded after
    ///      the clock has left a timepoint, the read for that timepoint - the outcome and the binding it
    ///      names - stays what it was when the clock left it.
    function testFuzz_read_for_a_passed_timepoint_never_changes(uint256 seed) public {
        _nextParadigm = successorParadigm(A, "fam", "aifp:paradigm/panel/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        _ids.push(bindingB);
        for (uint256 step = 0; step < 40; step++) {
            seed = uint256(keccak256(abi.encode(seed, step)));
            _historyStep(seed);
            for (uint256 k = 0; k < _times.length; k++) {
                (uint8 outcome, bytes32 named) = withBinding(B, AIFPRoles.SUBMIT, _times[k]);
                assertOutcome(outcome, _outcomes[k], "the read for a passed timepoint changed");
                assertEq(named, _names[k], "the binding named for a passed timepoint changed");
            }
        }
    }

    /// @dev One random step: a further grant, a suspension, reinstatement, revocation or confirmation of one
    ///      of the bindings, an adoption (now or scheduled, with or without re-admission), or the clock moving
    ///      on. Many of the calls are refused; that is part of the history.
    function _historyStep(uint256 seed) internal {
        bytes32 target = _ids[(seed >> 8) % _ids.length];
        uint256 op = seed % 8;
        bool done;
        if (op == 0) {
            if (_ids.length < 10) _ids.push(_grantToB(now48() + uint48((seed >> 16) % 2)));
        } else if (op == 1) {
            vm.prank(A);
            (done,) = address(participation).call(abi.encodeCall(participation.suspend, (target, bytes32("s"))));
        } else if (op == 2) {
            vm.prank(A);
            (done,) = address(participation).call(abi.encodeCall(participation.reinstate, (target)));
        } else if (op == 3) {
            vm.prank(A);
            (done,) = address(participation).call(abi.encodeCall(participation.revoke, (target, bytes32("r"))));
        } else if (op == 4) {
            vm.prank(A);
            (done,) = address(participation).call(abi.encodeCall(participation.confirmReadmission, (target)));
        } else if (op == 5) {
            vm.prank(A);
            channels.adoptParadigm(ch, _nextParadigm, now48() + uint48((seed >> 16) % 3), (seed >> 24) % 2 == 0, bytes32(0));
        } else {
            // The clock moves on: what the timepoint reads now is what it has to read for ever.
            (uint8 outcome, bytes32 named) = withBinding(B, AIFPRoles.SUBMIT, now48());
            _times.push(now48());
            _outcomes.push(outcome);
            _names.push(named);
            warpBy(1 + uint48((seed >> 16) % 3));
        }
    }

    function _grantToB(uint48 validFrom) internal returns (bytes32) {
        vm.prank(A);
        return participation.grant(ch, subj(B), bytes32(0), AIFPRoles.SUBMIT, bytes32(0), AIFPBasis.MANAGER_GRANT, bytes32(0), validFrom, 0);
    }

    // ------------------------------------------------------------ the companion follows the same rule

    function test_objection_registered_then_role_revoked_in_the_same_timepoint_still_counts() public {
        vm.recordLogs();
        vm.prank(A);
        uint256 id = win.open(ch, bytes32("proposal"), now48() + 10, now48() + 110, AIFPRoles.RESPOND);
        warpBy(20);
        vm.prank(B);
        win.object(id, bytes32("no"));
        vm.prank(A);
        participation.revoke(bindingB, bytes32("misconduct"));
        assertOutcome(evalNow(ch, B, AIFPRoles.RESPOND, 0), N, "the objector no longer holds the role at this timepoint");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory opened = logs[indexOf(logs, address(win), AIFPObjectionWindow.WindowOpened.selector)];
        (, bytes32 proposerBinding, uint48 openedAt,,,) = abi.decode(opened.data, (bytes32, bytes32, uint48, uint48, uint48, uint16));
        (, bytes32 expectedProposerBinding) = participation.evaluateWithBinding(ch, subj(A), AIFPRoles.SUBMIT, bytes32(0), T0);
        assertEq(proposerBinding, expectedProposerBinding, "WindowOpened names the proposer's binding");
        assertEq(uint256(openedAt), uint256(T0), "and the timepoint at which it was checked");
        uint256 objectedAt = indexOf(logs, address(win), AIFPObjectionWindow.ObjectionRegistered.selector);
        (, bytes32 objectorBinding,) = abi.decode(logs[objectedAt].data, (bytes32, bytes32, uint48));
        assertEq(objectorBinding, bindingB, "ObjectionRegistered names the objector's binding");
        assertTrue(
            objectedAt < indexOf(logs, address(participation), IAIFPParticipationRegistry.RoleRevoked.selector),
            "the objection precedes the revocation in the chain"
        );

        warpBy(100);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_OBJECTED()), "the objection was valid when it was registered");
    }
}
