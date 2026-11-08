// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 10 - an Agora where contribution requires a stake (semantic leaf kind 6).
/// Must show: the stake predicate carries chain, contract, asset, amount and period, so two implementations
/// reach the same admission answer; the kernel holds no funds; evidence for another chain or contract is
/// NOT_SATISFIED, missing evidence is UNDETERMINABLE; a stake proves a cost was paid, not independence.
contract Case10_StakedAgora is CaseBase {
    MockStakeVerifier stakeVerifier;
    bytes32 P_AGORA;
    bytes32 agora;
    bytes stakePred;
    address constant STAKING = address(0x5745);
    uint256 constant MIN = 1 ether;

    function setUp() public override {
        super.setUp();
        stakeVerifier = new MockStakeVerifier();
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({
            kind: AIFPPredicates.STAKE,
            childStart: 0,
            childCount: 0,
            verifier: address(stakeVerifier),
            ref: keccak256("stake:agora"),
            params: abi.encode(block.chainid, STAKING, address(0), MIN, uint8(0))
        });
        stakePred = abi.encode(nodes);
        P_AGORA = registerParadigm(A, "{staked-agora}", keccak256("agora"), 0, labels1(labelString("club")), twoPreds(AIFPRoles.SUBMIT, stakePred, AIFPRoles.OBSERVE, openPredicate()));
        agora = openChannel(A, P_AGORA);
        admitAs(B, agora, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        admitAs(C, agora, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
    }

    function test_stake_gating_is_scope_bound_and_deterministic() public {
        // No evidence: undeterminable, nothing recorded.
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_Undeterminable.selector);
        participation.admit(agora, AIFPRoles.SUBMIT, 0, stakePred, noEvidence(), 0);
        // Right amount on the wrong contract: not satisfied.
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(agora, AIFPRoles.SUBMIT, 0, stakePred, evidence1(abi.encode(MIN, block.chainid, address(0xBAD))), 0);
        // Right contract on another chain: not satisfied.
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(agora, AIFPRoles.SUBMIT, 0, stakePred, evidence1(abi.encode(MIN, block.chainid + 1, STAKING)), 0);
        // Below the threshold: not satisfied.
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(agora, AIFPRoles.SUBMIT, 0, stakePred, evidence1(abi.encode(MIN - 1, block.chainid, STAKING)), 0);
        // Enough: admitted, basis PREDICATE with the stake predicate hash.
        bytes32 bid = admitAs(B, agora, AIFPRoles.SUBMIT, 0, stakePred, evidence1(abi.encode(MIN, block.chainid, STAKING)));
        assertEq(participation.bindingOf(bid).basisRef, keccak256(stakePred));
        assertOutcome(evalNow(agora, B, AIFPRoles.SUBMIT, 0), S, "B speaks");
        // Preview gives the same answers without state change (two implementations, one result).
        assertOutcome(participation.previewAdmission(agora, subj(C), AIFPRoles.SUBMIT, 0, stakePred, noEvidence()), U, "preview U");
        assertOutcome(participation.previewAdmission(agora, subj(C), AIFPRoles.SUBMIT, 0, stakePred, evidence1(abi.encode(MIN, block.chainid, STAKING))), S, "preview S");
        assertEq(address(participation).balance, 0, "the kernel holds no funds");
        assertEq(address(channels).balance, 0);
    }

    function test_stake_does_not_prove_independence() public {
        // Two subjects can present the same stake evidence: the predicate cannot tell one controller from two.
        bytes[] memory ev = evidence1(abi.encode(MIN, block.chainid, STAKING));
        admitAs(B, agora, AIFPRoles.SUBMIT, 0, stakePred, ev);
        admitAs(C, agora, AIFPRoles.SUBMIT, 0, stakePred, ev);
        assertOutcome(evalNow(agora, B, AIFPRoles.SUBMIT, 0), S, "B");
        assertOutcome(evalNow(agora, C, AIFPRoles.SUBMIT, 0), S, "C");
        // Reading stays open regardless of stake.
        assertOutcome(evalNow(agora, O, AIFPRoles.SUBMIT, 0), N, "O has not staked");
        admitAs(O, agora, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        assertOutcome(evalNow(agora, O, AIFPRoles.OBSERVE, 0), S, "O reads");
    }
}
