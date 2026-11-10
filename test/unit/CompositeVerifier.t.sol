// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MockVerifier} from "../mocks/MockVerifier.sol";
import {AIFPCompositeVerifier} from "../../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";

contract CompositeVerifierTest is Fixture {
    MockVerifier mock;
    AIFPSubjectSet set;
    bytes32 constant CH = bytes32("channel");

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    function setUp() public override {
        super.setUp();
        mock = new MockVerifier();
        set = new AIFPSubjectSet(A);
    }

    function ev(bytes memory p, bytes[] memory evidence) internal view returns (uint8) {
        return verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), p, evidence);
    }

    function test_open_is_satisfied() public view {
        assertOutcome(ev(openPredicate(), noEvidence()), S, "open");
    }

    function test_allowlist_hit_and_miss() public {
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), N, "miss");
        vm.prank(A);
        set.add(subj(B));
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), S, "hit");
        vm.prank(A);
        set.remove(subj(B));
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), N, "removed");
    }

    function test_allowlist_zero_verifier_is_undeterminable() public view {
        assertOutcome(ev(allowlistPredicate(address(0)), noEvidence()), U, "no set");
    }

    function test_allowlist_non_contract_is_verifier_error() public view {
        assertOutcome(ev(allowlistPredicate(address(0xdead)), noEvidence()), E, "not a contract");
    }

    function test_external_outcomes_pass_through() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32("ref"));
        mock.setFixed(S);
        assertOutcome(ev(p, noEvidence()), S, "S");
        mock.setFixed(N);
        assertOutcome(ev(p, noEvidence()), N, "N");
        mock.setFixed(U);
        assertOutcome(ev(p, noEvidence()), U, "U");
        mock.setFixed(E);
        assertOutcome(ev(p, noEvidence()), E, "E");
    }

    function test_external_revert_is_verifier_error() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0));
        mock.setMode(mock.MODE_REVERT());
        assertOutcome(ev(p, noEvidence()), E, "revert");
    }

    function test_external_out_of_range_is_verifier_error() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0));
        mock.setMode(mock.MODE_OUT_OF_RANGE());
        assertOutcome(ev(p, noEvidence()), E, "7 -> E");
    }

    function test_external_zero_verifier_is_undeterminable() public view {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(0), bytes32(0));
        assertOutcome(ev(p, noEvidence()), U, "no verifier");
    }

    function test_semantic_kinds_are_delegated() public {
        mock.setFixed(S);
        for (uint8 kind = AIFPPredicates.CREDENTIAL; kind <= AIFPPredicates.DECISION; kind++) {
            assertOutcome(ev(externalPredicate(kind, address(mock), bytes32(0)), noEvidence()), S, "semantic kind delegated");
        }
    }

    function test_unsupported_kind_anywhere_is_undeterminable_before_composition() public {
        // anyOf(open, unsupported): without the unsupported leaf this would be SATISFIED.
        bytes memory p = anyOf2(openPredicate(), externalPredicate(10, address(mock), bytes32(0)));
        mock.setFixed(S);
        assertOutcome(ev(p, noEvidence()), U, "unsupported leaf blocks composition");
        assertFalse(verifier.supportsKind(10));
        assertTrue(verifier.supportsKind(9));
    }

    function test_evidence_routed_by_node_index() public {
        // allOf(external@1, external@2) with the echo verifier: node 1 reads evidence[1], node 2 reads evidence[2].
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        bytes memory p = allOf2(
            externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0)),
            externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0))
        );
        bytes[] memory evidence = new bytes[](3);
        evidence[0] = "";
        evidence[1] = abi.encodePacked(uint8(S));
        evidence[2] = abi.encodePacked(uint8(S));
        assertOutcome(ev(p, evidence), S, "both satisfied");
        evidence[2] = abi.encodePacked(uint8(N));
        assertOutcome(ev(p, evidence), N, "second leaf not satisfied");
        // missing evidence for node 2 -> the echo verifier answers UNDETERMINABLE
        bytes[] memory shortEv = new bytes[](2);
        shortEv[1] = abi.encodePacked(uint8(S));
        assertOutcome(ev(p, shortEv), U, "missing evidence");
    }

    function test_nested_precedence() public {
        // allOf(anyOf(N, S), E) -> anyOf = S, allOf(S, E) = E
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](5);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: 1, childCount: 2, verifier: address(0), ref: 0, params: ""});
        nodes[1] = AIFPPredicates.Node({kind: AIFPPredicates.ANY_OF, childStart: 3, childCount: 2, verifier: address(0), ref: 0, params: ""});
        nodes[2] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        nodes[3] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        nodes[4] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        bytes[] memory evidence = new bytes[](5);
        evidence[2] = abi.encodePacked(uint8(E));
        evidence[3] = abi.encodePacked(uint8(N));
        evidence[4] = abi.encodePacked(uint8(S));
        assertOutcome(ev(abi.encode(nodes), evidence), E, "allOf(anyOf(N,S)=S, E) = E");
        evidence[2] = abi.encodePacked(uint8(S));
        assertOutcome(ev(abi.encode(nodes), evidence), S, "allOf(S, S) = S");
        evidence[4] = abi.encodePacked(uint8(U));
        assertOutcome(ev(abi.encode(nodes), evidence), U, "allOf(anyOf(N,U)=U, S) = U");
    }

    function test_malformed_reverts() public {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), abi.encode(nodes), noEvidence());
    }

    /// @dev A node array in which two composites share a child is not a tree: it is rejected before anything
    ///      is evaluated, so no leaf can be called more than once.
    function test_shared_child_is_malformed() public {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](4);
        nodes[0] = composite(AIFPPredicates.ALL_OF, 1, 2);
        nodes[1] = composite(AIFPPredicates.ANY_OF, 3, 1);
        nodes[2] = composite(AIFPPredicates.ANY_OF, 3, 1);
        nodes[3] = echoLeaf();
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), abi.encode(nodes), noEvidence());
    }

    /// @dev anyOf(open, <branch>): `links` composites in a row under one child of the root, ending in an
    ///      open leaf at depth `links + 1`. With `deepFirst` the branch is the first child of the root.
    function withSideBranch(uint8 links, bool deepFirst) internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](uint256(links) + 3);
        nodes[0] = composite(AIFPPredicates.ANY_OF, 1, 2);
        nodes[deepFirst ? 2 : 1] = composite(AIFPPredicates.OPEN, 0, 0);
        nodes[deepFirst ? 1 : 2] = composite(AIFPPredicates.ALL_OF, 3, 1);
        for (uint8 i = 3; i < links + 2; i++) {
            nodes[i] = composite(AIFPPredicates.ALL_OF, i + 1, 1);
        }
        nodes[uint256(links) + 2] = composite(AIFPPredicates.OPEN, 0, 0);
        return abi.encode(nodes);
    }

    /// @dev A predicate that is too deep is malformed for every subject and on every path, also when the deep
    ///      branch would never be visited: an `anyOf` whose first child is `open` stops there, and the
    ///      evaluation still reverts. (The depth was once checked while descending, so the same predicate was
    ///      an outcome on one path and a revert on another.)
    function test_too_deep_predicate_is_malformed_wherever_the_deep_branch_sits() public {
        assertOutcome(ev(withSideBranch(7, false), noEvidence()), S, "deepest leaf at depth 8, branch skipped");
        assertOutcome(ev(withSideBranch(7, true), noEvidence()), S, "deepest leaf at depth 8, branch visited");
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), withSideBranch(8, false), noEvidence());
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), withSideBranch(8, true), noEvidence());
    }

    /// @dev A kind the verifier does not know makes the whole predicate UNDETERMINABLE whatever the child
    ///      fields of that node say, and before the structure is judged: the verifier cannot tell whether an
    ///      unknown kind has children, so it cannot tell whether the array is a tree. No verifier is called.
    function test_unknown_kind_is_undeterminable_before_the_structure_is_judged() public {
        // A node of kind 42 with two children, as a composite kind added later would look.
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](3);
        nodes[0] = composite(42, 1, 2);
        nodes[1] = composite(AIFPPredicates.OPEN, 0, 0);
        nodes[2] = composite(AIFPPredicates.OPEN, 0, 0);
        assertOutcome(ev(abi.encode(nodes), noEvidence()), U, "unknown kind with children");
        // Two nodes that no composite joins: malformed when both kinds are known ...
        AIFPPredicates.Node[] memory two = new AIFPPredicates.Node[](2);
        two[0] = composite(AIFPPredicates.OPEN, 0, 0);
        two[1] = composite(AIFPPredicates.OPEN, 0, 0);
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), abi.encode(two), noEvidence());
        // ... and UNDETERMINABLE as soon as one of them is of a kind the verifier does not know.
        two[1] = composite(42, 0, 0);
        assertOutcome(ev(abi.encode(two), noEvidence()), U, "unknown kind in an array that cannot be judged");
        // No verifier is called: allOf(delegated leaf, kind 42) answers with a fifth of the gas that funding
        // one leaf call takes.
        bytes memory p = allOf2(externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0)), externalPredicate(42, address(mock), bytes32(0)));
        (bool ok, bytes memory ret) = address(verifier).staticcall{gas: 200_000}(
            abi.encodeCall(verifier.evaluate, (CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), p, noEvidence()))
        );
        assertTrue(ok, "answered without funding a leaf");
        assertOutcome(abi.decode(ret, (uint8)), U, "kind 42 after a delegated leaf");
    }

    function test_external_non_contract_is_verifier_error() public view {
        bytes memory noCode = externalPredicate(AIFPPredicates.EXTERNAL, address(0xdead), bytes32(0));
        assertOutcome(ev(noCode, noEvidence()), E, "a declared verifier without code");
        assertOutcome(ev(anyOf2(noCode, openPredicate()), noEvidence()), S, "anyOf(E, S) = S: the fault stays in the leaf");
    }

    // ------------------------------------------------------------ composition, child by child

    function composite(uint8 kind, uint8 start, uint8 count) internal pure returns (AIFPPredicates.Node memory) {
        return AIFPPredicates.Node({kind: kind, childStart: start, childCount: count, verifier: address(0), ref: 0, params: ""});
    }

    function echoLeaf() internal view returns (AIFPPredicates.Node memory) {
        return AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
    }

    /// @dev What a leaf that answers the byte `v` contributes: 0 to 3 as they are, anything above is a fault.
    function leafOutcome(uint8 v) internal pure returns (uint8) {
        return v > E ? E : v;
    }

    /// @dev The verifier stops an allOf at its first NOT_SATISFIED child and an anyOf at its first SATISFIED
    ///      child. Every combination of three leaf answers (the four outcomes and an out-of-range value), for
    ///      both composites, gives what the composition tables give when every child is evaluated.
    function test_composition_matches_the_tables_for_every_three_leaves() public {
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](4);
        nodes[1] = echoLeaf();
        nodes[2] = echoLeaf();
        nodes[3] = echoLeaf();
        bytes[] memory evidence = new bytes[](4);
        uint8[] memory children = new uint8[](3);
        for (uint8 kind = AIFPPredicates.ALL_OF; kind <= AIFPPredicates.ANY_OF; kind++) {
            nodes[0] = composite(kind, 1, 3);
            bytes memory p = abi.encode(nodes);
            for (uint8 a = 0; a < 5; a++) {
                for (uint8 b = 0; b < 5; b++) {
                    for (uint8 c = 0; c < 5; c++) {
                        evidence[1] = abi.encodePacked(a);
                        evidence[2] = abi.encodePacked(b);
                        evidence[3] = abi.encodePacked(c);
                        children[0] = leafOutcome(a);
                        children[1] = leafOutcome(b);
                        children[2] = leafOutcome(c);
                        uint8 expected = kind == AIFPPredicates.ALL_OF ? AIFPOutcomes.allOf(children) : AIFPOutcomes.anyOf(children);
                        assertOutcome(ev(p, evidence), expected, "composition differs from the tables");
                    }
                }
            }
        }
    }

    /// @dev Two levels: a root over three composites of three leaves each, kinds and leaf answers at random.
    function testFuzz_nested_composition_matches_the_tables(uint256 seed) public {
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](13);
        bytes[] memory evidence = new bytes[](13);
        uint8[] memory outer = new uint8[](3);
        uint8 rootKind = seed & 1 == 0 ? AIFPPredicates.ALL_OF : AIFPPredicates.ANY_OF;
        seed >>= 1;
        nodes[0] = composite(rootKind, 1, 3);
        for (uint256 i = 0; i < 3; i++) {
            uint8 kind = seed & 1 == 0 ? AIFPPredicates.ALL_OF : AIFPPredicates.ANY_OF;
            seed >>= 1;
            // forge-lint: disable-next-line(unsafe-typecast)
            nodes[1 + i] = composite(kind, uint8(4 + 3 * i), 3);
            uint8[] memory inner = new uint8[](3);
            for (uint256 j = 0; j < 3; j++) {
                // forge-lint: disable-next-line(unsafe-typecast)
                uint8 v = uint8(seed % 5);
                seed /= 5;
                nodes[4 + 3 * i + j] = echoLeaf();
                evidence[4 + 3 * i + j] = abi.encodePacked(v);
                inner[j] = leafOutcome(v);
            }
            outer[i] = kind == AIFPPredicates.ALL_OF ? AIFPOutcomes.allOf(inner) : AIFPOutcomes.anyOf(inner);
        }
        uint8 expected = rootKind == AIFPPredicates.ALL_OF ? AIFPOutcomes.allOf(outer) : AIFPOutcomes.anyOf(outer);
        assertOutcome(ev(abi.encode(nodes), evidence), expected, "nested composition differs from the tables");
    }

    /// @dev Once a composite is decided its remaining children are not evaluated: their leaves are not
    ///      called, so a leaf that would revert, or burn its whole gas bound, costs nothing there.
    function test_decided_composite_does_not_call_the_remaining_leaves() public {
        mock.setMode(mock.MODE_REVERT());
        bytes memory reverting = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0));
        assertOutcome(ev(anyOf2(openPredicate(), reverting), noEvidence()), S, "anyOf(S, not called) = S");
        assertOutcome(ev(allOf2(allowlistPredicate(address(set)), reverting), noEvidence()), N, "allOf(N, not called) = N");
        // In the other order the leaf is called first and its fault is combined as usual.
        assertOutcome(ev(anyOf2(reverting, openPredicate()), noEvidence()), S, "anyOf(E, S) = S");
        assertOutcome(ev(allOf2(reverting, allowlistPredicate(address(set))), noEvidence()), N, "allOf(E, N) = N");
        assertOutcome(ev(allOf2(openPredicate(), reverting), noEvidence()), E, "allOf(S, E) = E");
        // That the skipped leaf is not called shows in the gas: calling any leaf requires the whole leaf bound
        // to be available, and 200,000 gas - a fifth of it - is enough here. In the other order it is not.
        bytes memory decided = abi.encodeCall(
            verifier.evaluate, (CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), anyOf2(openPredicate(), reverting), noEvidence())
        );
        (bool ok, bytes memory ret) = address(verifier).staticcall{gas: 200_000}(decided);
        assertTrue(ok, "a decided anyOf does not need the gas of its remaining leaves");
        assertOutcome(abi.decode(ret, (uint8)), S, "anyOf(S, not called) = S");
        bytes memory undecided = abi.encodeCall(
            verifier.evaluate, (CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), anyOf2(reverting, openPredicate()), noEvidence())
        );
        (ok, ret) = address(verifier).staticcall{gas: 200_000}(undecided);
        assertFalse(ok, "the leaf that comes first has to be funded");
        assertTrue(bytes4(ret) == IAIFPCompositeVerifier.AIFP_InsufficientGas.selector, "AIFP_InsufficientGas");
    }

    function test_supports_interface() public view {
        assertTrue(verifier.supportsInterface(type(IAIFPCompositeVerifier).interfaceId));
        assertTrue(verifier.supportsInterface(0x01ffc9a7));
        assertFalse(verifier.supportsInterface(0xffffffff));
    }
}
