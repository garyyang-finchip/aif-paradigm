// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 12 - a competing-consumer task queue (Dispatch: the select operator).
/// Must show: the candidate set and the actually selected receiver are distinguished; selection is a scoped
/// grant on the task; re-selection is revoke + grant; the earlier selection remains in history.
contract Case12_Dispatch is CaseBase {
    bytes32 P_DISPATCH;
    bytes32 queue;
    bytes32 constant TASK_1 = keccak256("task:1");
    bytes32 constant TASK_2 = keccak256("task:2");

    function setUp() public override {
        super.setUp();
        P_DISPATCH = registerParadigm(A, "{dispatch}", keccak256("queue"), 0, labels1(labelString("dispatch")), onePred(AIFPRoles.DISCOVER, openPredicate()));
        queue = openChannel(A, P_DISPATCH);
        grantRoles(A, queue, A, AIFPRoles.SUBMIT, 0);
        // Candidate set: B and C register as workers (DISCOVER by rule) and are listed as OBSERVE on the queue.
        admitAs(B, queue, AIFPRoles.DISCOVER, 0, openPredicate(), noEvidence());
        admitAs(C, queue, AIFPRoles.DISCOVER, 0, openPredicate(), noEvidence());
        grantRoles(A, queue, B, AIFPRoles.OBSERVE, 0);
        grantRoles(A, queue, C, AIFPRoles.OBSERVE, 0);
    }

    function test_candidates_versus_selected() public {
        anchorAs(A, queue, AIFPEvents.ACTION_PUBLISH, TASK_1, noRel());
        // Both are candidates (they may see the task) but neither is selected (neither may work it).
        assertOutcome(evalNow(queue, B, AIFPRoles.OBSERVE, TASK_1), S, "B candidate");
        assertOutcome(evalNow(queue, C, AIFPRoles.OBSERVE, TASK_1), S, "C candidate");
        assertOutcome(evalNow(queue, B, AIFPRoles.SUBMIT, TASK_1), N, "B not selected");
        assertOutcome(evalNow(queue, C, AIFPRoles.SUBMIT, TASK_1), N, "C not selected");
        // Selection: a scoped grant to exactly one candidate.
        bytes32 selB = grantRoles(A, queue, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, TASK_1);
        assertOutcome(evalNow(queue, B, AIFPRoles.SUBMIT, TASK_1), S, "B selected for task 1");
        assertOutcome(evalNow(queue, C, AIFPRoles.SUBMIT, TASK_1), N, "C still a candidate only");
        assertOutcome(evalNow(queue, B, AIFPRoles.SUBMIT, TASK_2), N, "selection is per task");
        assertOutcome(evalNow(queue, B, AIFPRoles.SUBMIT, 0), N, "not channel-wide");
        assertEq(participation.bindingOf(selB).scopeRef, TASK_1);
    }

    function test_reselection_is_revoke_plus_grant_with_history() public {
        bytes32 selB = grantRoles(A, queue, B, AIFPRoles.SUBMIT, TASK_1);
        uint48 tB = now48();
        warpBy(300); // B stalls
        vm.prank(A);
        participation.revoke(selB, bytes32("timeout"));
        bytes32 selC = grantRoles(A, queue, C, AIFPRoles.SUBMIT, TASK_1);
        assertOutcome(evalNow(queue, B, AIFPRoles.SUBMIT, TASK_1), N, "B deselected");
        assertOutcome(evalNow(queue, C, AIFPRoles.SUBMIT, TASK_1), S, "C selected");
        assertOutcome(evalAt(queue, B, AIFPRoles.SUBMIT, TASK_1, tB), S, "B was the selected worker at tB");
        assertOutcome(evalAt(queue, C, AIFPRoles.SUBMIT, TASK_1, tB), N, "C was not");
        assertEq(uint256(participation.bindingOf(selB).state), uint256(IAIFPParticipationRegistry.BindingState.Revoked));
        assertEq(uint256(participation.bindingOf(selC).state), uint256(IAIFPParticipationRegistry.BindingState.Granted));
        // Delivery guarantees and task effects live in the binding/business protocol; the registry records
        // only who was selected when.
        assertEq(participation.bindingIdsOf(queue, subj(B)).length, 3); // discover, observe, revoked selection
        assertEq(participation.bindingIdsOf(queue, subj(C)).length, 3);
    }
}
