// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 5 - two submitters bid blind to one collector (Intake with commit-reveal disclosure timing).
/// Must show: submission right does not imply the right to read the other's submission; commitments are
/// anchored before the deadline; reveals are new objects that supersede the commitments after it.
contract Case05_SealedBids is CaseBase {
    bytes32 P_INTAKE;
    bytes32 tender;
    bytes32 constant SCOPE_B = keccak256("bid:B");
    bytes32 constant SCOPE_C = keccak256("bid:C");
    uint48 deadline;

    function setUp() public override {
        super.setUp();
        P_INTAKE = registerParadigm(A, "{intake:sealed}", keccak256("tender"), 0, labels1(labelString("intake")), onePred(AIFPRoles.SUBMIT, openPredicate()));
        tender = openChannel(A, P_INTAKE);
        deadline = now48() + 3600;
        // A (collector) reads everything; each bidder reads only its own lane.
        grantRoles(A, tender, A, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, 0);
        grantRoles(A, tender, B, AIFPRoles.OBSERVE, SCOPE_B);
        grantRoles(A, tender, C, AIFPRoles.OBSERVE, SCOPE_C);
        admitAs(B, tender, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        admitAs(C, tender, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
    }

    function test_submit_right_does_not_imply_reading_others() public view {
        assertOutcome(evalNow(tender, B, AIFPRoles.SUBMIT, 0), S, "B may bid");
        assertOutcome(evalNow(tender, C, AIFPRoles.SUBMIT, 0), S, "C may bid");
        assertOutcome(evalNow(tender, B, AIFPRoles.OBSERVE, SCOPE_B), S, "B reads own lane");
        assertOutcome(evalNow(tender, B, AIFPRoles.OBSERVE, SCOPE_C), N, "B cannot read C's lane");
        assertOutcome(evalNow(tender, C, AIFPRoles.OBSERVE, SCOPE_B), N, "C cannot read B's lane");
        assertOutcome(evalNow(tender, A, AIFPRoles.OBSERVE, SCOPE_C), S, "collector reads all");
    }

    function test_commit_then_reveal_after_deadline() public {
        bytes32 bidB = keccak256(abi.encode("B", 1000, "salt-b"));
        bytes32 bidC = keccak256(abi.encode("C", 900, "salt-c"));
        bytes32 commitB = keccak256(abi.encode("commit", bidB));
        bytes32 commitC = keccak256(abi.encode("commit", bidC));
        uint256 iB = anchorAs(B, tender, AIFPEvents.ACTION_SUBMIT, commitB, noRel());
        uint256 iC = anchorAs(C, tender, AIFPEvents.ACTION_SUBMIT, commitC, noRel());
        assertTrue(anchor.record(iB).at < deadline && anchor.record(iC).at < deadline, "commitments inside the window");
        assertEq(anchor.anchoredBy(commitB), subj(B));
        assertEq(anchor.anchoredBy(commitC), subj(C));
        // Reveal: after the deadline each bidder supersedes its own commitment with the plaintext bid object.
        vm.warp(deadline + 1);
        anchorAs(B, tender, AIFPEvents.ACTION_SUPERSEDE, bidB, rel(AIFPEvents.REL_SUPERSEDES, commitB));
        // C cannot reveal on B's behalf (supersede is owner-only).
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_NotAnchoredBySubject.selector, commitB, subj(C)));
        anchor.anchor(tender, AIFPEvents.ACTION_SUPERSEDE, keccak256("fake"), rel(AIFPEvents.REL_SUPERSEDES, commitB));
        anchorAs(C, tender, AIFPEvents.ACTION_SUPERSEDE, bidC, rel(AIFPEvents.REL_SUPERSEDES, commitC));
        // The collector now holds four anchored objects; the commitments remain as history.
        assertEq(anchor.recordCount(), 4);
        assertEq(anchor.anchoredBy(commitB), subj(B), "commitment stays anchored");
        assertEq(anchor.anchoredBy(bidB), subj(B));
        // Collecting is not deciding: nothing about the winner is recorded here.
        assertEq(channels.disclosureCount(tender), 0);
    }
}
