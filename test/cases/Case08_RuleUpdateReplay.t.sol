// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 8 - rule update, revocation and replay of old authorizations.
/// Must show: the version in force at a timepoint is explicit; an event evaluated at a timepoint before the
/// change still passes under the old version; after the change the old predicate is rejected; a revoked
/// binding fails at and after its revocation but keeps its history; admission always happens at the clock,
/// so a back-dated timepoint cannot buy present permissions.
contract Case08_RuleUpdateReplay is CaseBase {
    bytes32 P_V1; // SUBMIT: open
    bytes32 P_V2; // SUBMIT: allowlist kept by A
    bytes32 ch;
    AIFPSubjectSet roster;
    uint48 eff;

    function setUp() public override {
        super.setUp();
        roster = new AIFPSubjectSet(A);
        P_V1 = registerParadigm(A, "{rules-v1}", keccak256("rules"), 0, labels1(labelString("club")), onePred(AIFPRoles.SUBMIT, openPredicate()));
        ch = openChannel(A, P_V1);
        P_V2 = successorParadigm(A, "rules", labelString("club"), P_V1, "2", onePred(AIFPRoles.SUBMIT, allowlistPredicate(address(roster))));
        eff = now48() + 100;
        vm.prank(A);
        channels.adoptParadigm(ch, P_V2, eff, false, bytes32("rules-tightened"));
    }

    function test_version_in_force_is_explicit_per_timepoint() public view {
        assertEq(channels.paradigmAt(ch, eff - 1), P_V1);
        assertEq(channels.paradigmAt(ch, eff), P_V2);
        assertEq(channels.paradigmAt(ch, T0 - 1), bytes32(0), "nothing in force before the channel opened");
    }

    function test_old_predicate_admits_before_and_is_rejected_after_the_change() public {
        bytes32 early = admitAs(B, ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        assertEq(participation.bindingOf(early).ruleVersion, P_V1);
        vm.warp(eff);
        // Replaying the old rule after the change: rejected by hash, not by evaluation.
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_PredicateMismatch.selector, keccak256(allowlistPredicate(address(roster))), keccak256(openPredicate())));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        // Under the new rule C needs to be on the roster.
        vm.prank(C);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(ch, AIFPRoles.SUBMIT, 0, allowlistPredicate(address(roster)), noEvidence(), 0);
        vm.prank(A);
        roster.add(subj(C));
        bytes32 late = admitAs(C, ch, AIFPRoles.SUBMIT, 0, allowlistPredicate(address(roster)), noEvidence());
        assertEq(participation.bindingOf(late).ruleVersion, P_V2);
        // B's earlier admission (no re-admission required) carries over and its history is intact.
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "B still valid");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, eff - 1), S, "B valid under v1 timepoints");
    }

    function test_revocation_keeps_history_and_blocks_the_present() public {
        bytes32 bBinding = admitAs(B, ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        uint48 tPost = now48() + 10;
        vm.warp(tPost);
        anchorAs(B, ch, AIFPEvents.ACTION_PUBLISH, bytes32("post-at-tPost"), noRel());
        uint48 tRevoke = now48() + 10;
        vm.warp(tRevoke);
        vm.prank(A);
        participation.revoke(bBinding, bytes32("misconduct"));
        // The post already accepted at tPost stays valid when re-evaluated later.
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, tPost), S, "history is not rewritten");
        // From the revocation on, nothing new is accepted.
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, tRevoke), N, "at revocation");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), N, "now");
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.SUBMIT)));
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("post-after-revocation"), noRel());
    }

    function test_backdated_timepoints_cannot_buy_present_permissions() public {
        // Under v1 (now) C could have been admitted by the open rule, but C waits until v2 is in force.
        vm.warp(eff + 1);
        // Evaluating the past says nothing about C (C never held a binding)...
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, eff - 1), N, "no past binding either");
        // ...and admission has no timepoint parameter: it is evaluated at the registry clock, under the
        // version in force now. The v1 rule cannot be replayed.
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_PredicateMismatch.selector, keccak256(allowlistPredicate(address(roster))), keccak256(openPredicate())));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        // Likewise a manager cannot back-date a grant.
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ValidFromInPast.selector, uint48(eff - 1), uint48(eff + 1)));
        participation.grant(ch, subj(C), 0, AIFPRoles.SUBMIT, 0, AIFPBasis.MANAGER_GRANT, 0, eff - 1, 0);
        // A binding valid only in the past yields no present permission.
        vm.prank(A);
        participation.grant(ch, subj(C), 0, AIFPRoles.SUBMIT, 0, AIFPBasis.MANAGER_GRANT, 0, 0, eff + 2);
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), S, "valid now");
        vm.warp(eff + 2);
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), N, "expired");
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, eff + 1), S, "but historically valid");
    }

    function test_same_timepoint_ordering_is_deterministic() public {
        // Two adoptions effective at the same timepoint: the later-recorded one is in force.
        bytes32 P_V3 = successorParadigm(A, "rules", labelString("club"), P_V2, "3", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P_V3, eff, false, 0);
        assertEq(channels.paradigmAt(ch, eff), P_V3, "later record wins the tie");
        assertEq(channels.adoptionCount(ch), 3);
    }
}
