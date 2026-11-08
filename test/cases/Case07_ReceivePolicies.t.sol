// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 7 - in a Club, different receivers apply different acceptance policies.
/// Must show the three gates: (1) the channel allows the publisher, (2) the receiver may read, (3) the
/// receiver chooses to accept. Gate 3 is local: it uses the same predicate grammar, is evaluated off the
/// registry, and leaves the channel state untouched.
contract Case07_ReceivePolicies is CaseBase {
    bytes32 P_CLUB;
    bytes32 club;
    AIFPSubjectSet trustedByB; // B's local roster: publishers B is willing to process
    MockVerifier credentialC; // C's local requirement: a credential proof

    function setUp() public override {
        super.setUp();
        P_CLUB = registerParadigm(A, "{club}", keccak256("agora"), 0, labels1(labelString("club")), twoPreds(AIFPRoles.SUBMIT, openPredicate(), AIFPRoles.OBSERVE, openPredicate()));
        club = openChannel(A, P_CLUB);
        admitAs(A, club, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        admitAs(B, club, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        admitAs(C, club, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        trustedByB = new AIFPSubjectSet(B);
        credentialC = new MockVerifier();
        credentialC.setMatchEvidence(abi.encode("A-level-3"));
    }

    function test_three_gates_are_independent() public {
        // Gate 1: the channel allows A to publish.
        assertOutcome(evalNow(club, A, AIFPRoles.SUBMIT, 0), S, "gate 1");
        uint256 idx = anchorAs(A, club, AIFPEvents.ACTION_PUBLISH, bytes32("post-1"), noRel());
        assertEq(anchor.record(idx).subject, subj(A));
        // Gate 2: B and C may read.
        assertOutcome(evalNow(club, B, AIFPRoles.OBSERVE, 0), S, "gate 2 B");
        assertOutcome(evalNow(club, C, AIFPRoles.OBSERVE, 0), S, "gate 2 C");
        // Gate 3: local policies, same grammar, evaluated against the publisher's subject.
        bytes memory policyB = allowlistPredicate(address(trustedByB));
        bytes memory policyC = externalPredicate(AIFPPredicates.CREDENTIAL, address(credentialC), bytes32("scheme:l3"));
        // B has not listed A: B reads but does not process.
        assertOutcome(verifier.evaluate(club, subj(A), AIFPRoles.SUBMIT, 0, policyB, noEvidence()), N, "B declines");
        // C accepts only with A's credential proof attached to the message.
        assertOutcome(verifier.evaluate(club, subj(A), AIFPRoles.SUBMIT, 0, policyC, noEvidence()), U, "C: no proof -> undeterminable");
        assertOutcome(verifier.evaluate(club, subj(A), AIFPRoles.SUBMIT, 0, policyC, evidence1(abi.encode("A-level-3"))), S, "C accepts with proof");
        // B later lists A: B's policy flips without any channel change.
        vm.prank(B);
        trustedByB.add(subj(A));
        assertOutcome(verifier.evaluate(club, subj(A), AIFPRoles.SUBMIT, 0, policyB, noEvidence()), S, "B accepts");
        // The channel is untouched by any of this.
        assertEq(channels.adoptionCount(club), 1);
        assertEq(channels.disclosureCount(club), 0);
        assertEq(participation.bindingIdsOf(club, subj(A)).length, 1);
        assertEq(participation.bindingIdsOf(club, subj(B)).length, 1);
    }

    function test_willingness_to_receive_grants_no_reading_right() public view {
        // O wants to process A's posts but holds no OBSERVE: gate 2 fails regardless of O's policy.
        bytes memory policyO = openPredicate();
        assertOutcome(verifier.evaluate(club, subj(A), AIFPRoles.SUBMIT, 0, policyO, noEvidence()), S, "O would accept anything");
        assertOutcome(evalNow(club, O, AIFPRoles.OBSERVE, 0), N, "but O may not read");
    }
}
