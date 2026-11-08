// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 1 - two strangers shake hands and establish a link (Open Link -> Bonded Link).
/// Must show: identity and a scoped, verifiable mutual binding exist; permissions change only inside the
/// agreed scope; the bond expresses no trust, credit or execution power beyond that scope.
contract Case01_Handshake is CaseBase {
    bytes32 P_DIRECT;
    bytes32 link;
    bytes32 constant LINK_SCOPE = keccak256("link:A:B");
    AIFPSubjectSet accepted; // A's acceptance roster for the link: who A is willing to bond with

    function setUp() public override {
        super.setUp();
        accepted = new AIFPSubjectSet(A);
        // Direct paradigm: RESPOND is acquired by predicate (allowlist kept by A); nothing else is open.
        P_DIRECT = registerParadigm(
            A, "{direct}", keccak256("direct"), 0, labels1(labelString("direct")), onePred(AIFPRoles.RESPOND, allowlistPredicate(address(accepted)))
        );
        link = openChannel(A, P_DIRECT);
    }

    function test_handshake_creates_scoped_mutual_bindings_only() public {
        // Before the handshake neither side holds anything.
        assertOutcome(evalNow(link, B, AIFPRoles.RESPOND, LINK_SCOPE), N, "B before");
        assertOutcome(evalNow(link, A, AIFPRoles.SUBMIT, LINK_SCOPE), N, "A before");

        // Step 1 - A's acceptance evidence: A grants itself SUBMIT+RESPOND+OBSERVE in the link scope and
        //          lists B on the acceptance roster.
        bytes32 aBinding = grantRoles(A, link, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE, LINK_SCOPE);
        vm.prank(A);
        accepted.add(subj(B));
        grantRoles(A, link, B, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, LINK_SCOPE);

        // Step 2 - B's acceptance evidence: B admits itself to RESPOND in the link scope (PREDICATE basis).
        bytes32 bBinding = admitAs(B, link, AIFPRoles.RESPOND, LINK_SCOPE, allowlistPredicate(address(accepted)), noEvidence());

        // The bond: both sides hold scoped roles, each with its own basis.
        assertOutcome(evalNow(link, A, AIFPRoles.SUBMIT, LINK_SCOPE), S, "A submits in link");
        assertOutcome(evalNow(link, B, AIFPRoles.RESPOND, LINK_SCOPE), S, "B responds in link");
        assertOutcome(evalNow(link, B, AIFPRoles.SUBMIT, LINK_SCOPE), S, "B submits in link");
        assertEq(uint256(participation.bindingOf(aBinding).basisKind), uint256(AIFPBasis.MANAGER_GRANT));
        assertEq(uint256(participation.bindingOf(bBinding).basisKind), uint256(AIFPBasis.PREDICATE));
        assertEq(participation.bindingOf(bBinding).basisRef, keccak256(allowlistPredicate(address(accepted))));

        // Nothing outside the scope changed: channel-wide and other scopes stay NOT_SATISFIED.
        assertOutcome(evalNow(link, B, AIFPRoles.RESPOND, 0), N, "B channel-wide");
        assertOutcome(evalNow(link, B, AIFPRoles.RESPOND, keccak256("other")), N, "B other scope");
        // No management power was conferred by the handshake.
        assertEq(uint256(participation.rolesOf(link, subj(B), LINK_SCOPE, now48()) & (AIFPRoles.MANAGE_ADMISSION | AIFPRoles.MANAGE_RULES | AIFPRoles.MANAGE_DISCLOSURE | AIFPRoles.REDISTRIBUTE)), 0, "no management or redistribution");
        // The bond is one link; a bystander cannot self-admit.
        vm.prank(O);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(link, AIFPRoles.RESPOND, LINK_SCOPE, allowlistPredicate(address(accepted)), noEvidence(), 0);
    }

    function test_bond_is_not_trust_or_execution_power() public {
        vm.prank(A);
        accepted.add(subj(B));
        grantRoles(A, link, B, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, LINK_SCOPE);
        admitAs(B, link, AIFPRoles.RESPOND, LINK_SCOPE, allowlistPredicate(address(accepted)), noEvidence());
        // B cannot change the rules, grant roles or disclose on the strength of the bond.
        bytes32 P2 = successorParadigm(A, "direct", labelString("direct"), P_DIRECT, "2", onePred(AIFPRoles.RESPOND, allowlistPredicate(address(accepted))));
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, link, B));
        channels.adoptParadigm(link, P2, now48(), false, 0);
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, link, B));
        participation.grant(link, subj(C), 0, AIFPRoles.OBSERVE, LINK_SCOPE, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, link, B));
        channels.recordDisclosure(link, 0, bytes32("obj"), bytes32("public"), 0);
    }

    function test_one_sided_follow_stays_one_sided() public {
        // A lists B but B never acts: there is no bond, only A's standing acceptance.
        vm.prank(A);
        accepted.add(subj(B));
        grantRoles(A, link, B, AIFPRoles.OBSERVE, LINK_SCOPE);
        assertOutcome(evalNow(link, B, AIFPRoles.OBSERVE, LINK_SCOPE), S, "A let B observe");
        assertOutcome(evalNow(link, B, AIFPRoles.RESPOND, LINK_SCOPE), N, "B has not accepted");
        assertEq(participation.bindingIdsOf(link, subj(B)).length, 1);
    }
}
