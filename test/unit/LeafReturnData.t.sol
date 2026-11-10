// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MisbehavingVerifier} from "../mocks/MisbehavingVerifier.sol";
import {AIFPCompositeVerifier} from "../../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";

/// @dev Leaf faults that are not reverts: return data that does not decode as the declared type, and a leaf
///      that exhausts its gas. Each one is VERIFIER_ERROR for that leaf alone; the rest of the tree still
///      composes, and the participation registry still admits a subject that another branch satisfies.
///      (Reported on the ERC-8489 thread: a typed `try ... returns (uint8)` decodes in the caller, so these
///      cases reverted the whole `evaluate` instead of the leaf.)
contract LeafReturnDataTest is Fixture {
    MisbehavingVerifier bad;
    AIFPSubjectSet set;
    bytes32 constant CH = bytes32("channel");

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    function setUp() public override {
        super.setUp();
        bad = new MisbehavingVerifier();
        set = new AIFPSubjectSet(A);
    }

    function ev(bytes memory p, bytes[] memory evidence) internal view returns (uint8) {
        return verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), p, evidence);
    }

    function badLeaf() internal view returns (bytes memory) {
        return externalPredicate(AIFPPredicates.EXTERNAL, address(bad), bytes32("ext"));
    }

    // ------------------------------------------------------------ delegated leaves

    function test_empty_return_data_is_verifier_error_for_the_leaf() public {
        bad.set(bad.MODE_EMPTY(), 0);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "empty");
    }

    function test_word_above_uint8_is_verifier_error_for_the_leaf() public {
        bad.set(bad.MODE_WORD(), 256);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "256");
        bad.set(bad.MODE_WORD(), type(uint256).max);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "max");
    }

    function test_word_above_three_but_within_uint8_is_verifier_error() public {
        bad.set(bad.MODE_WORD(), 7);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "7");
        bad.set(bad.MODE_WORD(), 255);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "255");
    }

    function test_well_formed_words_pass_through() public {
        bad.set(bad.MODE_WORD(), S);
        assertOutcome(ev(badLeaf(), noEvidence()), S, "S");
        bad.set(bad.MODE_WORD(), N);
        assertOutcome(ev(badLeaf(), noEvidence()), N, "N");
        bad.set(bad.MODE_WORD(), U);
        assertOutcome(ev(badLeaf(), noEvidence()), U, "U");
        bad.set(bad.MODE_WORD(), E);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "E");
    }

    function test_short_and_long_return_data_are_verifier_errors() public {
        bad.set(bad.MODE_SHORT(), 0);
        assertOutcome(ev(badLeaf(), noEvidence()), E, "16 bytes");
        bad.set(bad.MODE_LONG(), 0); // a valid outcome word followed by a second word is still not one word
        assertOutcome(ev(badLeaf(), noEvidence()), E, "64 bytes");
    }

    function test_gas_exhausting_leaf_is_verifier_error_and_is_bounded() public {
        bad.set(bad.MODE_BURN(), 0);
        uint256 before = gasleft();
        uint8 out = ev(badLeaf(), noEvidence());
        uint256 used = before - gasleft();
        assertOutcome(out, E, "burn");
        assertTrue(used < verifier.leafGasLimit() + 150_000, "one leaf spent more than its bound");
    }

    // ------------------------------------------------------------ allowlist leaves

    function test_allowlist_non_boolean_word_is_verifier_error() public {
        bad.set(bad.MODE_WORD(), 2);
        assertOutcome(ev(allowlistPredicate(address(bad)), noEvidence()), E, "2 is not a bool");
    }

    function test_allowlist_empty_return_is_verifier_error() public {
        bad.set(bad.MODE_EMPTY(), 0);
        assertOutcome(ev(allowlistPredicate(address(bad)), noEvidence()), E, "empty");
    }

    function test_allowlist_boolean_words_pass_through() public {
        bad.set(bad.MODE_WORD(), 1);
        assertOutcome(ev(allowlistPredicate(address(bad)), noEvidence()), S, "true");
        bad.set(bad.MODE_WORD(), 0);
        assertOutcome(ev(allowlistPredicate(address(bad)), noEvidence()), N, "false");
    }

    // ------------------------------------------------------------ the fault stays in its leaf

    function test_faulty_leaf_does_not_abort_composition() public {
        bad.set(bad.MODE_EMPTY(), 0);
        assertOutcome(ev(anyOf2(badLeaf(), openPredicate()), noEvidence()), S, "anyOf(E, S) = S");
        assertOutcome(ev(allOf2(badLeaf(), openPredicate()), noEvidence()), E, "allOf(E, S) = E");
        bad.set(bad.MODE_BURN(), 0);
        assertOutcome(ev(anyOf2(badLeaf(), openPredicate()), noEvidence()), S, "anyOf(burn, S) = S");
        assertOutcome(ev(anyOf2(openPredicate(), badLeaf()), noEvidence()), S, "anyOf(S, burn) = S");
    }

    /// @dev The reported scenario: anyOf(allowlist, external) with a broken external verifier must admit a
    ///      subject that is on the allowlist, and must answer NOT_SATISFIED / VERIFIER_ERROR, not revert, for
    ///      one that is not.
    function test_registry_admits_allowlisted_subject_despite_broken_external_leaf() public {
        bad.set(bad.MODE_EMPTY(), 0);
        bytes memory predicate = anyOf2(allowlistPredicate(address(set)), badLeaf());
        bytes32 pid = simpleParadigm(A, "fam", "panel", AIFPRoles.SUBMIT, predicate);
        bytes32 channel = openChannel(A, pid);

        vm.prank(A);
        set.add(subj(B));
        assertOutcome(ev(allOf2(allowlistPredicate(address(set)), badLeaf()), noEvidence()), E, "allOf of the same two leaves");
        assertOutcome(
            participation.previewAdmission(channel, subj(B), AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence()),
            S,
            "preview for an allowlisted subject"
        );
        bytes32 bindingId = admitAs(B, channel, AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence());
        assertTrue(bindingId != bytes32(0), "admitted");
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), S, "B holds SUBMIT");

        // C is not on the allowlist: the broken leaf is the only remaining branch, so the answer is the leaf's
        // fault, reported as such and never as NOT_SATISFIED.
        assertOutcome(
            participation.previewAdmission(channel, subj(C), AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence()),
            E,
            "preview for a subject outside the allowlist"
        );
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_VerifierError.selector);
        vm.prank(C);
        participation.admit(channel, AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence(), 0);
    }
}
