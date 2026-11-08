// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 2 - a stranger enters a private collaboration room by proving a credential (semantic leaf kind 5).
/// Must show: open discovery, qualification proof, restricted reading and contribution rights are four
/// separate things; the credential admits OBSERVE in one room only; SUBMIT is granted separately.
contract Case02_CredentialEntry is CaseBase {
    MockVerifier kya; // stands in for a credential verifier (for example a KYA scheme adapter)
    bytes32 P_MEETING;
    bytes32 room;
    bytes32 constant ROOM = keccak256("room:project-x");
    bytes32 constant OTHER_ROOM = keccak256("room:project-y");
    bytes credPred;

    function setUp() public override {
        super.setUp();
        kya = new MockVerifier();
        kya.setMatchEvidence(abi.encode("proof-of-level-2"));
        credPred = externalPredicate(AIFPPredicates.CREDENTIAL, address(kya), bytes32("scheme:kya-l2"));
        P_MEETING = registerParadigm(
            A, "{meeting-with-credential-entry}", keccak256("meeting"), 0, labels1(labelString("meeting")), onePred(AIFPRoles.OBSERVE, credPred)
        );
        room = openChannel(A, P_MEETING);
        grantRoles(A, room, A, AIFPRoles.SUBMIT | AIFPRoles.OBSERVE, ROOM);
        grantRoles(A, room, B, AIFPRoles.SUBMIT | AIFPRoles.OBSERVE, ROOM);
    }

    function test_credential_admits_reading_in_one_room_only() public {
        // C is unknown to A and B. Discovery of the room id happened off-chain (open discovery).
        assertOutcome(evalNow(room, C, AIFPRoles.OBSERVE, ROOM), N, "stranger");
        // Wrong proof: NOT_SATISFIED, nothing recorded.
        vm.prank(C);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(room, AIFPRoles.OBSERVE, ROOM, credPred, evidence1(abi.encode("forged")), 0);
        // No proof: UNDETERMINABLE, nothing recorded and never recorded as NOT_SATISFIED.
        vm.prank(C);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_Undeterminable.selector);
        participation.admit(room, AIFPRoles.OBSERVE, ROOM, credPred, noEvidence(), 0);
        assertEq(participation.bindingIdsOf(room, subj(C)).length, 0);
        // Valid proof: OBSERVE in the room, basis = the credential predicate.
        bytes32 bid = admitAs(C, room, AIFPRoles.OBSERVE, ROOM, credPred, evidence1(abi.encode("proof-of-level-2")));
        assertOutcome(evalNow(room, C, AIFPRoles.OBSERVE, ROOM), S, "C reads the room");
        assertEq(uint256(participation.bindingOf(bid).basisKind), uint256(AIFPBasis.PREDICATE));
        // Reading is scoped: not the other room, not channel-wide.
        assertOutcome(evalNow(room, C, AIFPRoles.OBSERVE, OTHER_ROOM), N, "other room");
        assertOutcome(evalNow(room, C, AIFPRoles.OBSERVE, 0), N, "channel-wide");
        // Qualification is not contribution: C cannot submit until a manager grants it.
        assertOutcome(evalNow(room, C, AIFPRoles.SUBMIT, ROOM), N, "no contribution yet");
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NoPredicateForRole.selector, P_MEETING, uint16(AIFPRoles.SUBMIT)));
        participation.admit(room, AIFPRoles.SUBMIT, ROOM, credPred, evidence1(abi.encode("proof-of-level-2")), 0);
        grantRoles(A, room, C, AIFPRoles.SUBMIT, ROOM);
        assertOutcome(evalNow(room, C, AIFPRoles.SUBMIT, ROOM), S, "contribution granted separately");
    }

    function test_identity_relationship_and_qualification_are_separate() public {
        // B is a long-standing collaborator of A but holds no credential: B cannot enter the credential-gated
        // scope through the predicate, while B's manager-granted roles in ROOM are unaffected.
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_Undeterminable.selector);
        participation.admit(room, AIFPRoles.OBSERVE, OTHER_ROOM, credPred, noEvidence(), 0);
        assertOutcome(evalNow(room, B, AIFPRoles.OBSERVE, ROOM), S, "relationship-based roles unchanged");
        // The verifier failing (revert) is a VERIFIER_ERROR, not a judgement on C.
        kya.setMode(kya.MODE_REVERT());
        vm.prank(C);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_VerifierError.selector);
        participation.admit(room, AIFPRoles.OBSERVE, ROOM, credPred, evidence1(abi.encode("proof-of-level-2")), 0);
    }
}
