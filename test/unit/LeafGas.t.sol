// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {GasProbeVerifier} from "../mocks/GasProbeVerifier.sol";
import {ColdReaderVerifier} from "../mocks/ColdReaderVerifier.sol";
import {MisbehavingVerifier} from "../mocks/MisbehavingVerifier.sol";
import {AIFPCompositeVerifier} from "../../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";

/// @dev Evaluates the same predicate twice inside one call, reading the leaf's storage in between as an
///      earlier call of the same transaction (or an access list) would, so that the second evaluation finds
///      it warm however the test itself is run. A leaf call that fails leaves nothing warm behind: the
///      accesses of a reverted frame are rolled back with it.
contract TwoEvaluations {
    function run(AIFPCompositeVerifier verifier, bytes32 subject, bytes calldata predicate, ColdReaderVerifier leaf)
        external
        view
        returns (uint8 first, uint8 second)
    {
        bytes[] memory none = new bytes[](0);
        first = verifier.evaluate(bytes32("channel"), subject, 4, bytes32(0), predicate, none);
        leaf.touch();
        second = verifier.evaluate(bytes32("channel"), subject, 4, bytes32(0), predicate, none);
    }
}

/// @dev Gas and return-data properties of a leaf call (second review round on the ERC-8489 thread):
///      - the outcome of an evaluation does not depend on the gas its caller supplied: a leaf is given exactly
///        the bound or the evaluation fails as a whole with AIFP_InsufficientGas, and through the
///        participation registry a failed evaluation is never reported as an outcome;
///      - a leaf that does not complete within the bound is VERIFIER_ERROR however much gas the caller adds;
///      - the verifier never copies more than 32 bytes of what a leaf returns, and the registry never more
///        than 32 bytes of what the verifier returns.
contract LeafGasTest is Fixture {
    GasProbeVerifier probe;
    ColdReaderVerifier cold;
    MisbehavingVerifier bad;
    AIFPSubjectSet set;
    bytes32 constant CH = bytes32("channel");
    uint256 constant AMPLE = 30_000_000;
    address constant RAW_LEAF = address(0x1EAF);

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    bytes4 constant INSUFFICIENT_GAS = 0xc9b4ddbd; // AIFP_InsufficientGas()
    bytes4 constant EVALUATION_FAILED = 0x69812968; // AIFP_EvaluationFailed(bytes4)

    function setUp() public override {
        super.setUp();
        probe = new GasProbeVerifier();
        cold = new ColdReaderVerifier();
        bad = new MisbehavingVerifier();
        set = new AIFPSubjectSet(A);
    }

    // ------------------------------------------------------------ helpers

    function leafOf(address verifier_) internal pure returns (bytes memory) {
        return externalPredicate(AIFPPredicates.EXTERNAL, verifier_, bytes32("leaf"));
    }

    function probeLeaf() internal view returns (bytes memory) {
        return leafOf(address(probe));
    }

    function badLeaf() internal view returns (bytes memory) {
        return leafOf(address(bad));
    }

    /// @dev A leaf of eleven bytes whose first opcode reads its own gas:
    ///      GAS, PUSH3 threshold, GT, PUSH0, MSTORE, PUSH1 0x20, PUSH0, RETURN.
    ///      It returns the word 0 when it observes at least `threshold` gas and the word 1 when it observes
    ///      less. GAS reports what is left after its own 2 gas, so a call given F gas observes F - 2.
    function etchRawProbe(uint256 threshold) internal {
        // forge-lint: disable-next-line(unsafe-typecast)
        vm.etch(RAW_LEAF, abi.encodePacked(hex"5a62", bytes3(uint24(threshold)), hex"115f5260205ff3"));
    }

    /// @dev `evaluate` with an explicit gas limit: an outcome, or the selector it failed with (zero when the
    ///      call simply ran out of gas).
    function evalWithGas(bytes memory p, uint256 gasLimit) internal view returns (bool ok, uint8 outcome, bytes4 selector) {
        (bool success, bytes memory ret) = address(verifier).staticcall{gas: gasLimit}(
            abi.encodeCall(verifier.evaluate, (CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), p, noEvidence()))
        );
        if (success) return (true, abi.decode(ret, (uint8)), bytes4(0));
        if (ret.length >= 4) selector = bytes4(ret);
    }

    function previewOn(AIFPParticipationRegistry registry, bytes32 channel, address who, bytes memory p, uint256 gasLimit)
        internal
        view
        returns (bool ok, uint8 outcome, bytes memory failure)
    {
        (bool success, bytes memory ret) = address(registry).staticcall{gas: gasLimit}(
            abi.encodeCall(registry.previewAdmission, (channel, subj(who), AIFPRoles.SUBMIT, bytes32(0), p, noEvidence()))
        );
        if (success) return (true, abi.decode(ret, (uint8)), "");
        failure = ret;
    }

    /// @dev A failed call that names no outcome: a leaf could not be funded, the evaluation did not complete,
    ///      or the call itself ran out of gas. The errors that name an outcome are excluded.
    function namesNoOutcome(bytes memory failure) internal pure returns (bool) {
        if (failure.length == 0) return true;
        bytes4 selector = bytes4(failure);
        return selector == INSUFFICIENT_GAS || selector == EVALUATION_FAILED;
    }

    /// @dev Evaluates with every gas limit from `from` to `to`. A call that answers must answer `expected`; a
    ///      call that does not must have failed for lack of gas (AIFP_InsufficientGas, or plain exhaustion).
    function sweep(bytes memory p, uint8 expected, uint256 from, uint256 to, uint256 step)
        internal
        view
        returns (uint256 answered, uint256 refused)
    {
        for (uint256 g = from; g <= to; g += step) {
            (bool ok, uint8 outcome, bytes4 selector) = evalWithGas(p, g);
            if (ok) {
                assertOutcome(outcome, expected, "the outcome changed with the caller's gas");
                answered++;
            } else {
                assertTrue(selector == INSUFFICIENT_GAS || selector == bytes4(0), "failed for a reason other than gas");
                if (selector == INSUFFICIENT_GAS) refused++;
            }
        }
    }

    function sweepPreview(bytes32 channel, address who, bytes memory p, uint8 expected, uint256 from, uint256 to, uint256 step)
        internal
        view
        returns (uint256 answered, uint256 refused)
    {
        for (uint256 g = from; g <= to; g += step) {
            (bool ok, uint8 outcome, bytes memory failure) = previewOn(participation, channel, who, p, g);
            if (ok) {
                assertOutcome(outcome, expected, "the registry's outcome changed with the caller's gas");
                answered++;
            } else {
                assertTrue(namesNoOutcome(failure), "a failure that names an outcome");
                if (failure.length != 0) refused++;
            }
        }
    }

    function channelWith(bytes memory predicate) internal returns (bytes32 channel) {
        bytes32 pid = simpleParadigm(A, "fam", "panel", AIFPRoles.SUBMIT, predicate);
        channel = openChannel(A, pid);
    }

    // ------------------------------------------------------------ a leaf is given exactly the bound

    function test_error_selectors() public pure {
        assertTrue(IAIFPCompositeVerifier.AIFP_InsufficientGas.selector == INSUFFICIENT_GAS, "the composite verifier's error");
        assertTrue(IAIFPParticipationRegistry.AIFP_InsufficientGas.selector == INSUFFICIENT_GAS, "same error in the registry");
        assertTrue(IAIFPParticipationRegistry.AIFP_EvaluationFailed.selector == EVALUATION_FAILED, "the failed-evaluation error");
    }

    function test_bound_is_exposed_through_the_interface() public view {
        assertEq(IAIFPCompositeVerifier(address(verifier)).leafGasLimit(), 1_000_000);
    }

    /// @dev Gas limit by gas limit across the point where the evaluation starts to answer, for a delegated
    ///      leaf: below it the evaluation refuses with AIFP_InsufficientGas; from it on the leaf is given the
    ///      bound exactly - not one gas less, not one gas more.
    function test_delegated_leaf_is_given_the_bound_to_the_gas() public {
        scanFundingBoundary(leafOf(RAW_LEAF), S, N);
    }

    /// @dev The same for the `contains` call of an allowlist leaf (the probe's word 0 reads as "not contained").
    function test_allowlist_leaf_is_given_the_bound_to_the_gas() public {
        scanFundingBoundary(allowlistPredicate(RAW_LEAF), N, S);
    }

    /// @param whenAtLeast outcome of the predicate when the probe observes at least its threshold
    /// @param whenLess    outcome when it observes less
    function scanFundingBoundary(bytes memory p, uint8 whenAtLeast, uint8 whenLess) internal {
        uint256 bound = verifier.leafGasLimit();
        etchRawProbe(bound - 2); // observes bound - 2 exactly when it is given the bound
        (bool ok, uint8 outcome,) = evalWithGas(p, AMPLE);
        assertTrue(ok, "answered");
        assertOutcome(outcome, whenAtLeast, "with ample gas the leaf is given the bound");

        // Smallest gas limit at which the evaluation answers.
        uint256 lo = 900_000;
        uint256 hi = 1_200_000;
        (ok,,) = evalWithGas(p, lo);
        assertFalse(ok, "900,000 gas cannot fund a 1,000,000 gas leaf");
        (ok,,) = evalWithGas(p, hi);
        assertTrue(ok, "1,200,000 gas funds it");
        while (hi - lo > 1) {
            uint256 mid = (lo + hi) / 2;
            (ok,,) = evalWithGas(p, mid);
            if (ok) hi = mid;
            else lo = mid;
        }
        assertTrue(hi > bound + bound / 63, "the evaluation needs 64/63 of the bound before the leaf call");
        bytes4 selector;
        for (uint256 g = hi - 3_000; g < hi + 3_000; g++) {
            (ok, outcome, selector) = evalWithGas(p, g);
            if (g < hi) {
                assertFalse(ok, "answered below the funding point");
                assertTrue(selector == INSUFFICIENT_GAS, "refused with AIFP_InsufficientGas");
            } else {
                assertTrue(ok, "refused above the funding point");
                assertOutcome(outcome, whenAtLeast, "the leaf was called with less than the bound");
            }
        }
        // Never more than the bound either: a probe that asks for one gas more is never satisfied.
        etchRawProbe(bound - 1);
        for (uint256 g = hi; g < hi + 3_000; g += 7) {
            (ok, outcome,) = evalWithGas(p, g);
            assertTrue(ok, "refused above the funding point");
            assertOutcome(outcome, whenLess, "the leaf was called with more than the bound");
        }
        (ok, outcome,) = evalWithGas(p, AMPLE);
        assertOutcome(outcome, whenLess, "ample gas does not reach the leaf");
    }

    /// @dev The reported scenario: a leaf that needs 800,000 gas passes with ample gas and used to come back
    ///      VERIFIER_ERROR when the caller left it less than that.
    function test_starved_leaf_is_never_reported_heavy() public {
        probe.set(probe.MODE_HEAVY(), 800_000);
        (uint256 answered, uint256 refused) = sweep(probeLeaf(), S, 40_000, 1_400_000, 10_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
    }

    /// @dev A leaf that answers NOT_SATISFIED when it sees less than (almost) the full bound: a starved call
    ///      would obtain a definite, wrong answer without running out of gas.
    function test_starved_leaf_is_never_reported_threshold() public {
        probe.set(probe.MODE_THRESHOLD(), verifier.leafGasLimit() - 2_000);
        (uint256 answered, uint256 refused) = sweep(probeLeaf(), S, 40_000, 1_400_000, 10_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
    }

    /// @dev A leaf that survives its own inner out-of-gas and still answers (here UNDETERMINABLE) leaves gas
    ///      behind, so a check made after the call would not notice that it was starved. Funding is checked
    ///      before the call for that reason.
    function test_starved_leaf_is_never_reported_inner_catch() public {
        probe.set(probe.MODE_INNER_CATCH(), 600_000);
        (uint256 answered, uint256 refused) = sweep(probeLeaf(), S, 40_000, 1_400_000, 5_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
    }

    function test_leaf_that_does_not_complete_within_the_bound_is_verifier_error_at_any_gas() public {
        probe.set(probe.MODE_HEAVY(), verifier.leafGasLimit() + 200_000);
        (bool ok, uint8 outcome,) = evalWithGas(probeLeaf(), AMPLE);
        assertTrue(ok, "answered");
        assertOutcome(outcome, E, "ample gas does not help a leaf that exceeds the bound");
        (uint256 answered, uint256 refused) = sweep(probeLeaf(), E, 40_000, 3_000_000, 20_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
        // The fault stays in the leaf.
        (ok, outcome,) = evalWithGas(allOf2(openPredicate(), probeLeaf()), AMPLE);
        assertOutcome(outcome, E, "allOf(S, E) = E");
        (ok, outcome,) = evalWithGas(anyOf2(probeLeaf(), openPredicate()), AMPLE);
        assertOutcome(outcome, S, "anyOf(E, S) = S");
    }

    function test_every_leaf_that_is_called_is_funded_or_the_evaluation_fails() public {
        probe.set(probe.MODE_HEAVY(), 700_000);
        vm.prank(A);
        set.add(subj(B));
        // allOf(allowlist, heavy external): both leaves are called; the truth is SATISFIED.
        bytes memory p = allOf2(allowlistPredicate(address(set)), probeLeaf());
        (uint256 answered, uint256 refused) = sweep(p, S, 40_000, 2_200_000, 10_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
    }

    /// @dev For any leaf behaviour and any gas limit: the evaluation answers what it answers with ample gas,
    ///      or it does not answer.
    function testFuzz_outcome_is_independent_of_the_callers_gas(uint256 gasSeed, uint256 amountSeed, uint8 modeSeed) public {
        probe.set(modeSeed % 3, amountSeed % 1_500_001);
        uint256 gasLimit = 20_000 + (gasSeed % 3_980_001);
        // The delegated leaf comes first, so that it is called whatever the allowlist would answer.
        bytes memory p = anyOf2(probeLeaf(), allowlistPredicate(address(set)));
        (bool ok, uint8 truth,) = evalWithGas(p, AMPLE);
        assertTrue(ok, "ample gas answers");
        uint8 outcome;
        bytes4 selector;
        (ok, outcome, selector) = evalWithGas(p, gasLimit);
        if (ok) {
            assertOutcome(outcome, truth, "the outcome changed with the caller's gas");
        } else {
            assertTrue(selector == INSUFFICIENT_GAS || selector == bytes4(0), "failed for a reason other than gas");
        }
    }

    // ------------------------------------------------------------ what the bound cannot fix

    /// @dev Gas is not the only thing a transaction brings: state it has already touched is cheaper to read
    ///      (2,100 gas for a cold storage slot, 100 for a warm one). A leaf that reads 200 slots and then
    ///      works for 700,000 gas does not complete within the bound from a cold start and does once the slots
    ///      are warm. A leaf that fits the bound from a cold start answers the same both times. The caveat is
    ///      stated in the specification (Section 6.3); this test keeps it honest.
    function test_caveat_a_leaf_close_to_the_bound_depends_on_what_the_transaction_touched() public {
        TwoEvaluations twice = new TwoEvaluations();
        cold.set(200, 700_000);
        (uint8 first, uint8 second) = twice.run(verifier, subj(B), leafOf(address(cold)), cold);
        assertOutcome(first, E, "cold: 200 * 2,100 + 700,000 gas does not fit the bound");
        assertOutcome(second, S, "warm: 200 * 100 + 700,000 gas does");

        ColdReaderVerifier sound = new ColdReaderVerifier();
        sound.set(200, 500_000);
        (first, second) = twice.run(verifier, subj(B), leafOf(address(sound)), sound);
        assertOutcome(first, S, "cold: 200 * 2,100 + 500,000 gas fits the bound");
        assertOutcome(second, S, "and so does the warm call");
    }

    // ------------------------------------------------------------ return data is not copied

    /// @dev A leaf may spend its own bound on a 600 KB return buffer. The verifier reads the size, finds that
    ///      it is not one word and copies nothing: the only cost of the large return is the leaf's own.
    function test_large_return_data_is_not_copied() public {
        uint256 size = 600_000;
        uint256 words = (size + 31) / 32;
        uint256 leafMemoryCost = 3 * words + (words * words) / 512; // what the leaf pays to return `size` bytes

        bad.set(bad.MODE_LONG(), 0); // 64 bytes: the baseline of a malformed answer
        uint256 before = gasleft();
        (bool ok, uint8 outcome,) = evalWithGas(badLeaf(), AMPLE);
        uint256 usedSmall = before - gasleft();
        assertTrue(ok, "answered");
        assertOutcome(outcome, E, "64 bytes");

        bad.set(bad.MODE_HUGE(), size);
        before = gasleft();
        (ok, outcome,) = evalWithGas(badLeaf(), AMPLE);
        uint256 usedHuge = before - gasleft();
        assertTrue(ok, "answered");
        assertOutcome(outcome, E, "600 KB is not one word");

        assertTrue(leafMemoryCost < verifier.leafGasLimit(), "the leaf can afford the buffer inside its bound");
        assertTrue(usedHuge - usedSmall < leafMemoryCost + 5_000, "the verifier paid for the leaf's return data");
    }

    /// @dev "At most 32 bytes", measured: a leaf that returns 4,096 bytes costs the evaluation exactly as
    ///      much more than one that returns 64 bytes as the leaf itself pays for the larger buffer (416 gas
    ///      against 6). Copying the 4 KB would add several hundred gas on the verifier's side.
    function test_return_data_beyond_one_word_costs_the_verifier_nothing() public {
        bytes memory p = badLeaf();
        bad.set(bad.MODE_HUGE(), 64);
        evalWithGas(p, AMPLE); // first call: everything the measurement touches is warm afterwards
        uint256 before = gasleft();
        evalWithGas(p, AMPLE);
        uint256 used64 = before - gasleft();
        bad.set(bad.MODE_HUGE(), 4_096);
        before = gasleft();
        (bool ok, uint8 outcome,) = evalWithGas(p, AMPLE);
        uint256 used4096 = before - gasleft();
        assertTrue(ok, "answered");
        assertOutcome(outcome, E, "4,096 bytes is not one word");
        uint256 leafExtra = (3 * 128 + (128 * 128) / 512) - (3 * 2); // memory for 128 words less memory for 2
        assertTrue(used4096 >= used64 + leafExtra - 20 && used4096 <= used64 + leafExtra + 20, "the verifier's own cost grew with the return data");
    }

    function test_large_return_data_does_not_hide_another_branch() public {
        bad.set(bad.MODE_HUGE(), 600_000);
        (bool ok, uint8 outcome,) = evalWithGas(anyOf2(badLeaf(), openPredicate()), AMPLE);
        assertTrue(ok, "answered");
        assertOutcome(outcome, S, "anyOf(E, S) = S");
        (ok, outcome,) = evalWithGas(allowlistPredicate(address(bad)), AMPLE);
        assertTrue(ok, "answered");
        assertOutcome(outcome, E, "an allowlist that returns 600 KB");
    }

    /// @dev A leaf cannot make the evaluation look unfunded: reverting with, or returning, the four bytes of
    ///      AIFP_InsufficientGas is a fault of that leaf like any other.
    function test_leaf_that_imitates_the_refusal_is_just_a_faulty_leaf() public {
        bad.setRevert(INSUFFICIENT_GAS, 4);
        (bool ok, uint8 outcome,) = evalWithGas(badLeaf(), AMPLE);
        assertTrue(ok, "the evaluation was not refused");
        assertOutcome(outcome, E, "a leaf that reverts with the refusal selector");
        (ok, outcome,) = evalWithGas(anyOf2(badLeaf(), openPredicate()), AMPLE);
        assertOutcome(outcome, S, "anyOf(E, S) = S");
        bad.set(bad.MODE_SHORT(), uint256(bytes32(INSUFFICIENT_GAS)));
        (ok, outcome,) = evalWithGas(badLeaf(), AMPLE);
        assertTrue(ok, "the evaluation was not refused");
        assertOutcome(outcome, E, "a leaf that returns the selector");
    }

    // ------------------------------------------------------------ through the participation registry

    /// @dev `previewAdmission` over a generous `eth_call` and `admit` in a transaction with a tight gas limit
    ///      used to disagree: SATISFIED in the first, AIFP_VerifierError in the second. The tight transaction
    ///      now fails with AIFP_InsufficientGas, and the same call with more gas is admitted.
    function test_admit_with_a_tight_gas_limit_fails_for_gas_not_for_the_verifier() public {
        probe.set(probe.MODE_HEAVY(), 800_000);
        bytes memory predicate = probeLeaf();
        bytes32 channel = channelWith(predicate);

        (bool ok, uint8 outcome,) = previewOn(participation, channel, B, predicate, AMPLE);
        assertTrue(ok, "preview answered");
        assertOutcome(outcome, S, "preview with ample gas");

        bytes memory call_ = abi.encodeCall(participation.admit, (channel, AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence(), 0));
        vm.prank(B);
        (bool admitted, bytes memory ret) = address(participation).call{gas: 700_000}(call_);
        assertFalse(admitted, "a starved admit must not go through");
        assertTrue(ret.length == 4 && bytes4(ret) == INSUFFICIENT_GAS, "it fails for lack of gas, not with AIFP_VerifierError");
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), N, "nothing was recorded");

        vm.prank(B);
        (admitted,) = address(participation).call{gas: 3_000_000}(call_);
        assertTrue(admitted, "the same call with more gas is admitted");
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), S, "B holds SUBMIT");
    }

    /// @dev Re-admission goes through the same evaluation and fails the same way when it is starved.
    function test_readmit_with_a_tight_gas_limit_fails_for_gas() public {
        probe.set(probe.MODE_HEAVY(), 800_000);
        bytes memory predicate = probeLeaf();
        bytes32 p1 = simpleParadigm(A, "fam", "panel", AIFPRoles.SUBMIT, predicate);
        bytes32 channel = openChannel(A, p1);
        bytes32 bindingId = admitAs(B, channel, AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence());
        bytes32 p2 = successorParadigm(A, "fam", "panel", p1, "2", onePred(AIFPRoles.SUBMIT, predicate));
        vm.prank(A);
        channels.adoptParadigm(channel, p2, now48() + 10, true, 0);
        warpBy(10);
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), U, "pending re-admission");

        bytes memory call_ = abi.encodeCall(participation.readmit, (bindingId, predicate, noEvidence()));
        vm.prank(B);
        (bool done, bytes memory ret) = address(participation).call{gas: 700_000}(call_);
        assertFalse(done, "a starved re-admission must not go through");
        assertTrue(ret.length == 4 && bytes4(ret) == INSUFFICIENT_GAS, "it fails for lack of gas");
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), U, "still pending");
        vm.prank(B);
        (done,) = address(participation).call{gas: 3_000_000}(call_);
        assertTrue(done, "the same call with more gas re-admits");
        assertOutcome(evalNow(channel, B, AIFPRoles.SUBMIT, bytes32(0)), S, "re-admitted");
    }

    function test_preview_outcome_is_independent_of_gas_heavy_leaf() public {
        probe.set(probe.MODE_HEAVY(), 800_000);
        bytes memory predicate = probeLeaf();
        bytes32 channel = channelWith(predicate);
        (uint256 answered, uint256 refused) = sweepPreview(channel, B, predicate, S, 60_000, 1_500_000, 10_000);
        assertTrue(answered > 0 && refused > 0, "the sweep crosses the funding threshold");
    }

    function testFuzz_preview_outcome_is_independent_of_the_callers_gas(uint256 gasSeed, uint256 amountSeed, uint8 modeSeed) public {
        probe.set(modeSeed % 3, amountSeed % 1_500_001);
        bytes memory predicate = anyOf2(probeLeaf(), allowlistPredicate(address(set)));
        bytes32 channel = channelWith(predicate);
        (bool ok, uint8 truth,) = previewOn(participation, channel, B, predicate, AMPLE);
        assertTrue(ok, "ample gas answers");
        uint8 outcome;
        bytes memory failure;
        (ok, outcome, failure) = previewOn(participation, channel, B, predicate, 30_000 + (gasSeed % 3_970_001));
        if (ok) {
            assertOutcome(outcome, truth, "the registry's outcome changed with the caller's gas");
        } else {
            assertTrue(namesNoOutcome(failure), "a failure that names an outcome");
        }
    }

    /// @dev No leaf call at all: 63 allOf children that are all satisfied. With too little gas the composite
    ///      verifier runs out in its own code; the registry reports a failed evaluation, never VERIFIER_ERROR.
    function test_preview_outcome_is_independent_of_gas_when_the_verifier_itself_runs_out() public {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](64);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: 1, childCount: 63, verifier: address(0), ref: 0, params: ""});
        for (uint256 i = 1; i < 64; i++) {
            nodes[i] = AIFPPredicates.Node({kind: AIFPPredicates.OPEN, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        }
        bytes memory predicate = abi.encode(nodes);
        bytes32 channel = channelWith(predicate);
        (bool ok, uint8 outcome,) = previewOn(participation, channel, B, predicate, AMPLE);
        assertTrue(ok, "preview answered");
        assertOutcome(outcome, S, "truth");
        (uint256 answered, uint256 refused) = sweepPreview(channel, B, predicate, S, 30_000, 400_000, 1_000);
        assertTrue(answered > 0 && refused > 0, "the registry reported evaluations its verifier could not finish");
    }

    /// @dev A composite verifier that reverts has not evaluated anything. The registry reports that as a
    ///      failed evaluation carrying the verifier's own error selector, never as VERIFIER_ERROR: an outcome
    ///      is what a completed evaluation returns.
    function test_reverting_composite_verifier_is_a_failed_evaluation_not_an_outcome() public {
        // A predicate nested deeper than a tree may be: the registry's own hash check passes, the verifier
        // reverts with AIFP_MalformedPredicate and plenty of gas left.
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](11);
        for (uint256 i = 0; i < 10; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            nodes[i] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: uint8(i + 1), childCount: 1, verifier: address(0), ref: 0, params: ""});
        }
        nodes[10] = AIFPPredicates.Node({kind: AIFPPredicates.OPEN, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        bytes memory predicate = abi.encode(nodes);
        bytes32 channel = channelWith(predicate);
        bytes memory expected = abi.encodeWithSelector(EVALUATION_FAILED, AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        vm.expectRevert(expected);
        participation.previewAdmission(channel, subj(B), AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence());
        vm.expectRevert(expected);
        vm.prank(B);
        participation.admit(channel, AIFPRoles.SUBMIT, bytes32(0), predicate, noEvidence(), 0);
    }

    /// @dev A registry deployed over a composite verifier that does not behave: the registry accepts one
    ///      well-formed outcome word and reports everything else as a failed evaluation. In particular an
    ///      empty or short answer, whose first word reads as zero, is not SATISFIED.
    function test_registry_accepts_only_a_well_formed_answer_from_its_verifier() public {
        MisbehavingVerifier fake = new MisbehavingVerifier();
        AIFPParticipationRegistry registry = new AIFPParticipationRegistry(channels, paradigms, IAIFPCompositeVerifier(address(fake)));
        bytes memory predicate = openPredicate();
        bytes32 channel = channelWith(predicate);
        bool ok;
        uint8 outcome;
        bytes memory failure;
        for (uint8 w = 0; w <= E; w++) {
            fake.set(fake.MODE_WORD(), w);
            (ok, outcome,) = previewOn(registry, channel, B, predicate, AMPLE);
            assertTrue(ok, "a well-formed word is an outcome");
            assertOutcome(outcome, w, "and passes through unchanged");
        }
        bytes memory noReason = abi.encodeWithSelector(EVALUATION_FAILED, bytes4(0));
        fake.set(fake.MODE_EMPTY(), 0);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "no data is not SATISFIED");
        assertEq(failure, noReason);
        fake.set(fake.MODE_SHORT(), 0);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "16 bytes of zeros are not SATISFIED");
        assertEq(failure, noReason);
        fake.set(fake.MODE_LONG(), 0);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "two words are not an outcome");
        assertEq(failure, noReason);
        fake.set(fake.MODE_WORD(), 4);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "4 is not an outcome");
        assertEq(failure, noReason);
        fake.set(fake.MODE_WORD(), 256);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "256 would truncate to SATISFIED");
        assertEq(failure, noReason);
        // 600 KB: nothing beyond the first word is copied by the registry.
        fake.set(fake.MODE_HUGE(), 600_000);
        uint256 before = gasleft();
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        uint256 used = before - gasleft();
        assertFalse(ok, "600 KB are not an outcome");
        assertEq(failure, noReason);
        assertTrue(used < 900_000, "the registry paid for the verifier's return data");
        // A verifier that uses up whatever it is given: a failed evaluation at any gas, never an outcome.
        fake.set(fake.MODE_BURN(), 0);
        (ok,, failure) = previewOn(registry, channel, B, predicate, 2_000_000);
        assertFalse(ok, "exhaustion is not an outcome");
        assertEq(failure, noReason);
    }

    /// @dev The refusal is exactly the four bytes of AIFP_InsufficientGas as revert data. A longer revert that
    ///      begins with them, or the same four bytes returned, is a failed evaluation of another kind.
    function test_registry_recognizes_the_refusal_exactly() public {
        MisbehavingVerifier fake = new MisbehavingVerifier();
        AIFPParticipationRegistry registry = new AIFPParticipationRegistry(channels, paradigms, IAIFPCompositeVerifier(address(fake)));
        bytes memory predicate = openPredicate();
        bytes32 channel = channelWith(predicate);
        fake.setRevert(INSUFFICIENT_GAS, 4);
        (bool ok,, bytes memory failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "refused");
        assertEq(failure, abi.encodeWithSelector(INSUFFICIENT_GAS));
        fake.setRevert(INSUFFICIENT_GAS, 36);
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "failed");
        assertEq(failure, abi.encodeWithSelector(EVALUATION_FAILED, INSUFFICIENT_GAS));
        fake.set(fake.MODE_SHORT(), uint256(bytes32(INSUFFICIENT_GAS)));
        (ok,, failure) = previewOn(registry, channel, B, predicate, AMPLE);
        assertFalse(ok, "failed");
        assertEq(failure, abi.encodeWithSelector(EVALUATION_FAILED, bytes4(0)));
    }
}
