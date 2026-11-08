// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";

contract SmokeTest is Fixture {
    function test_stack_deploys_and_grants() public {
        bytes32 pid = registerParadigm(A, "{\"aifp\":\"1\",\"family\":\"t\"}", keccak256("fam"), 0, labels1("aifp:paradigm/club/v1"), onePred(AIFPRoles.SUBMIT, openPredicate()));
        assertTrue(paradigms.exists(pid));
        assertTrue(paradigms.hasLabel(pid, keccak256("aifp:paradigm/club/v1")));
        bytes32 ch = openChannel(A, pid);
        (bytes32 current,) = channels.currentParadigm(ch);
        assertEq(current, pid);
        // A grants B OBSERVE; B admits itself to SUBMIT through the open predicate.
        grantRoles(A, ch, B, AIFPRoles.OBSERVE, bytes32(0));
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, 0), AIFPOutcomes.SATISFIED, "B observes");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), AIFPOutcomes.NOT_SATISFIED, "B cannot submit yet");
        vm.prank(B);
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), AIFPOutcomes.SATISFIED, "B submits");
        assertEq(channels.CLOCK_MODE(), "mode=timestamp");
        assertEq(uint256(participation.clock()), uint256(T0));
    }
}
