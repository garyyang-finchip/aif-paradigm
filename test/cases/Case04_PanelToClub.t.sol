// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 4 - a public Panel becomes a Club.
/// Must show: how observers acquire contribution, exactly which conditions change, that the change has an
/// explicit effective timepoint, that existing bindings become pending until re-admitted, and that opening
/// contribution discloses no history by itself.
contract Case04_PanelToClub is CaseBase {
    bytes32 P_PANEL; // observe: open predicate; submit: roster only (no predicate)
    bytes32 P_CLUB; // observe: open; submit: open predicate
    bytes32 ch;
    bytes32 bPanelist;
    bytes32 cObserver;
    uint48 eff;

    function setUp() public override {
        super.setUp();
        P_PANEL = registerParadigm(A, "{panel}", keccak256("talk"), 0, labels1(labelString("panel")), onePred(AIFPRoles.OBSERVE, openPredicate()));
        ch = openChannel(A, P_PANEL);
        bPanelist = grantRoles(A, ch, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0); // roster member
        cObserver = admitAs(C, ch, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence()); // audience
        P_CLUB = successorParadigm(
            A, "talk", labelString("club"), P_PANEL, "2", twoPreds(AIFPRoles.OBSERVE, openPredicate(), AIFPRoles.SUBMIT, openPredicate())
        );
        eff = now48() + 1 days;
        vm.prank(A);
        channels.adoptParadigm(ch, P_CLUB, eff, true, bytes32("decision:open-the-floor"));
    }

    function test_before_effective_nothing_changes() public {
        (bytes32 cur,) = channels.currentParadigm(ch);
        assertEq(cur, P_PANEL);
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), N, "C still audience");
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NoPredicateForRole.selector, P_PANEL, uint16(AIFPRoles.SUBMIT)));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "B still panelist");
        assertFalse(participation.isPending(bPanelist, now48()));
    }

    function test_after_effective_observers_acquire_contribution_by_rule() public {
        vm.warp(eff);
        (bytes32 cur, uint48 since) = channels.currentParadigm(ch);
        assertEq(cur, P_CLUB);
        assertEq(uint256(since), uint256(eff));
        // C acquires SUBMIT through the common rule, not through anyone's individual authorization.
        bytes32 cSubmit = admitAs(C, ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), S, "C contributes");
        assertEq(uint256(participation.bindingOf(cSubmit).basisKind), uint256(AIFPBasis.PREDICATE));
        assertEq(participation.bindingOf(cSubmit).ruleVersion, P_CLUB);
        // A bystander can do the same: the floor is open by rule.
        admitAs(O, ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        assertOutcome(evalNow(ch, O, AIFPRoles.SUBMIT, 0), S, "anyone meeting the rule contributes");
    }

    function test_existing_bindings_pending_until_readmitted() public {
        vm.warp(eff);
        assertTrue(participation.isPending(bPanelist, now48()));
        assertTrue(participation.isPending(cObserver, now48()));
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), U, "panelist pending, not denied");
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, 0), U, "observer pending, not denied");
        // Manager confirms the roster member; the observer re-proves the (new) observe rule itself.
        vm.prank(A);
        participation.confirmReadmission(bPanelist);
        vm.prank(C);
        participation.readmit(cObserver, openPredicate(), noEvidence());
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "panelist carried over");
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, 0), S, "observer carried over");
        assertEq(participation.bindingOf(bPanelist).ruleVersion, P_CLUB);
        // History before the change is evaluated under the panel rules and stays SATISFIED.
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, eff - 1), S, "history under panel rules");
        assertEq(channels.paradigmAt(ch, eff - 1), P_PANEL);
    }

    function test_opening_contribution_discloses_nothing() public {
        vm.warp(eff);
        // Rule change recorded; no disclosure record was created by it.
        assertEq(channels.adoptionCount(ch), 2);
        assertEq(channels.disclosureCount(ch), 0, "no history disclosed by the rule change");
        // The adoption record carries the authorization reference and the re-admission flag.
        IAIFPChannelRegistry.Adoption memory a = channels.adoptionAt(ch, 1);
        assertEq(a.paradigmId, P_CLUB);
        assertTrue(a.requiresReadmission);
        assertEq(a.authorizationRef, bytes32("decision:open-the-floor"));
        assertEq(uint256(a.effectiveAt), uint256(eff));
    }
}
