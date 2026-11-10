// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 6 - a shared blackboard updated in turn by A, B and C.
/// Must show: agents cooperate indirectly through object versions; the version chain (who changed what
/// after what) is reconstructable from anchor records and relations; nobody sends a direct message.
contract Case06_Blackboard is CaseBase {
    bytes32 P_BB;
    bytes32 board;
    bytes32 constant PLAN = keccak256("plan");

    function setUp() public override {
        super.setUp();
        P_BB = registerParadigm(A, "{blackboard}", keccak256("board"), 0, labels1(labelString("blackboard")), onePred(AIFPRoles.MODIFY, openPredicate()));
        board = openChannel(A, P_BB);
        grantRoles(A, board, A, AIFPRoles.SUBMIT | AIFPRoles.MODIFY | AIFPRoles.OBSERVE, 0);
        grantRoles(A, board, B, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, 0);
        grantRoles(A, board, C, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, 0);
        admitAs(B, board, AIFPRoles.MODIFY, 0, openPredicate(), noEvidence());
        admitAs(C, board, AIFPRoles.MODIFY, 0, openPredicate(), noEvidence());
    }

    function test_version_chain_is_reconstructable() public {
        bytes32 v1 = keccak256(abi.encode(PLAN, 1));
        bytes32 v2 = keccak256(abi.encode(PLAN, 2));
        bytes32 v3 = keccak256(abi.encode(PLAN, 3));
        vm.recordLogs();
        uint256 i1 = anchorAs(A, board, AIFPEvents.ACTION_PUBLISH, v1, noRel());
        warpBy(60);
        uint256 i2 = anchorAs(B, board, AIFPEvents.ACTION_MODIFY, v2, rel(AIFPEvents.REL_SUPERSEDES, v1));
        warpBy(60);
        uint256 i3 = anchorAs(C, board, AIFPEvents.ACTION_MODIFY, v3, rel(AIFPEvents.REL_SUPERSEDES, v2));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // Records: who, what, when, under which rule.
        assertEq(anchor.record(i1).subject, subj(A));
        assertEq(anchor.record(i2).subject, subj(B));
        assertEq(anchor.record(i3).subject, subj(C));
        assertTrue(anchor.record(i1).at < anchor.record(i2).at && anchor.record(i2).at < anchor.record(i3).at);
        assertEq(anchor.record(i3).ruleVersion, P_BB);
        // Relations: v2 supersedes v1, v3 supersedes v2.
        assertEq(countRelation(logs, v2, AIFPEvents.REL_SUPERSEDES, v1), 1);
        assertEq(countRelation(logs, v3, AIFPEvents.REL_SUPERSEDES, v2), 1);
        assertEq(countRelation(logs, v3, AIFPEvents.REL_SUPERSEDES, v1), 0);
        // Each version keeps its author; a later modification does not transfer ownership of earlier versions.
        assertEq(anchor.anchoredBy(v1), subj(A));
        assertEq(anchor.anchoredBy(v2), subj(B));
        assertEq(anchor.anchoredBy(v3), subj(C));
    }

    function test_observers_without_modify_cannot_update_the_board() public {
        grantRoles(A, board, O, AIFPRoles.OBSERVE, 0);
        bytes32 v1 = keccak256(abi.encode(PLAN, 1));
        anchorAs(A, board, AIFPEvents.ACTION_PUBLISH, v1, noRel());
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, board, subj(O), uint16(AIFPRoles.MODIFY), AIFPOutcomes.NOT_SATISFIED));
        anchor.anchor(board, AIFPEvents.ACTION_MODIFY, keccak256("rogue"), rel(AIFPEvents.REL_SUPERSEDES, v1));
        // Retraction of the current head is reserved to its author.
        bytes32 v2 = keccak256(abi.encode(PLAN, 2));
        anchorAs(B, board, AIFPEvents.ACTION_MODIFY, v2, rel(AIFPEvents.REL_SUPERSEDES, v1));
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_NotAnchoredBySubject.selector, v2, subj(A)));
        anchor.anchor(board, AIFPEvents.ACTION_RETRACT, keccak256("retract-v2"), rel(AIFPEvents.REL_RETRACTS, v2));
        anchorAs(B, board, AIFPEvents.ACTION_RETRACT, keccak256("retract-v2"), rel(AIFPEvents.REL_RETRACTS, v2));
        assertEq(anchor.anchoredBy(v2), subj(B), "retraction marks, it does not erase");
    }
}
