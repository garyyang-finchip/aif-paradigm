// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/TestBase.sol";
import {OutcomesHarness, PredicatesHarness, SubjectHarness, RolesHarness} from "../mocks/Harness.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";
import {AIFPPredicates} from "../../assets/erc-aifp/contracts/libraries/AIFPPredicates.sol";
import {AIFPRoles} from "../../assets/erc-aifp/contracts/libraries/AIFPRoles.sol";

contract OutcomesTest is TestBase {
    OutcomesHarness h;

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    function setUp() public {
        h = new OutcomesHarness();
    }

    function arr(uint8 a, uint8 b) internal pure returns (uint8[] memory o) {
        o = new uint8[](2);
        o[0] = a;
        o[1] = b;
    }

    function arr(uint8 a, uint8 b, uint8 c) internal pure returns (uint8[] memory o) {
        o = new uint8[](3);
        o[0] = a;
        o[1] = b;
        o[2] = c;
    }

    function test_allOf_truth_table() public view {
        // NOT_SATISFIED dominates everything
        assertEq(uint256(h.allOf(arr(S, N))), N);
        assertEq(uint256(h.allOf(arr(N, U))), N);
        assertEq(uint256(h.allOf(arr(E, N))), N);
        assertEq(uint256(h.allOf(arr(U, E, N))), N);
        // then UNDETERMINABLE over VERIFIER_ERROR and SATISFIED
        assertEq(uint256(h.allOf(arr(S, U))), U);
        assertEq(uint256(h.allOf(arr(E, U))), U);
        assertEq(uint256(h.allOf(arr(U, E, S))), U);
        // then VERIFIER_ERROR over SATISFIED
        assertEq(uint256(h.allOf(arr(S, E))), E);
        assertEq(uint256(h.allOf(arr(E, S, S))), E);
        // all satisfied
        assertEq(uint256(h.allOf(arr(S, S))), S);
        assertEq(uint256(h.allOf(arr(S, S, S))), S);
    }

    function test_anyOf_truth_table() public view {
        // SATISFIED dominates everything
        assertEq(uint256(h.anyOf(arr(S, N))), S);
        assertEq(uint256(h.anyOf(arr(U, S))), S);
        assertEq(uint256(h.anyOf(arr(E, S))), S);
        assertEq(uint256(h.anyOf(arr(N, E, S))), S);
        // then UNDETERMINABLE
        assertEq(uint256(h.anyOf(arr(N, U))), U);
        assertEq(uint256(h.anyOf(arr(E, U))), U);
        assertEq(uint256(h.anyOf(arr(N, E, U))), U);
        // then VERIFIER_ERROR over NOT_SATISFIED
        assertEq(uint256(h.anyOf(arr(N, E))), E);
        assertEq(uint256(h.anyOf(arr(E, N, N))), E);
        // all not satisfied
        assertEq(uint256(h.anyOf(arr(N, N))), N);
    }

    function test_normalize_out_of_range_is_verifier_error() public view {
        assertEq(uint256(h.normalize(0)), S);
        assertEq(uint256(h.normalize(3)), E);
        assertEq(uint256(h.normalize(4)), E);
        assertEq(uint256(h.normalize(255)), E);
        // out-of-range values inside a composite behave as VERIFIER_ERROR
        assertEq(uint256(h.allOf(arr(S, 9))), E);
        assertEq(uint256(h.anyOf(arr(N, 200))), E);
    }

    function test_empty_lists_revert() public {
        uint8[] memory empty = new uint8[](0);
        vm.expectRevert(bytes("AIFP: empty allOf"));
        h.allOf(empty);
        vm.expectRevert(bytes("AIFP: empty anyOf"));
        h.anyOf(empty);
    }
}

contract SubjectTest is TestBase {
    SubjectHarness h;

    function setUp() public {
        h = new SubjectHarness();
    }

    function test_toDecimal() public view {
        assertEq(h.toDecimal(0), "0");
        assertEq(h.toDecimal(7), "7");
        assertEq(h.toDecimal(10), "10");
        assertEq(h.toDecimal(11155111), "11155111");
        assertEq(h.toDecimal(type(uint256).max), "115792089237316195423570985008687907853269984665640564039457584007913129639935");
    }

    function test_toHexAddress_lowercase_with_prefix() public view {
        assertEq(h.toHexAddress(address(0)), "0x0000000000000000000000000000000000000000");
        assertEq(h.toHexAddress(0x8004A818BFB912233c491871b3d84c89A494BD9e), "0x8004a818bfb912233c491871b3d84c89a494bd9e");
        assertEq(h.toHexAddress(address(0xA11CE)), "0x00000000000000000000000000000000000a11ce");
    }

    function test_address_canonical_and_ref() public view {
        string memory c = h.canonicalAddress(11155111, 0x8004A818BFB912233c491871b3d84c89A494BD9e);
        assertEq(c, "eip155-address:11155111:0x8004a818bfb912233c491871b3d84c89a494bd9e");
        assertEq(h.fromAddress(11155111, 0x8004A818BFB912233c491871b3d84c89A494BD9e), keccak256(bytes(c)));
        // self() uses the current chain id
        assertEq(h.self(address(0xB0B)), h.fromAddress(block.chainid, address(0xB0B)));
        // no second encoding: a left-padded address is not a subject reference
        assertNotEq(h.fromAddress(1, address(0xB0B)), bytes32(uint256(uint160(address(0xB0B)))));
        // chain id is part of the identity
        assertNotEq(h.fromAddress(1, address(0xB0B)), h.fromAddress(11155111, address(0xB0B)));
    }

    function test_erc8004_canonical_and_ref() public view {
        string memory c = h.canonicalERC8004(11155111, 0x8004A818BFB912233c491871b3d84c89A494BD9e, 10387);
        assertEq(c, "erc8004:11155111:0x8004a818bfb912233c491871b3d84c89a494bd9e:10387");
        assertEq(h.fromERC8004(11155111, 0x8004A818BFB912233c491871b3d84c89A494BD9e, 10387), keccak256(bytes(c)));
    }

    function test_did_and_ext() public view {
        assertEq(h.canonicalDID("aid", "eip155:11155111:0x01c05738eebd20dc80bbb9fa1ceb1165af8da00f"), "did:aid:eip155:11155111:0x01c05738eebd20dc80bbb9fa1ceb1165af8da00f");
        assertEq(h.fromDID("aid", "x"), keccak256("did:aid:x"));
        assertEq(h.fromExt("finchip.ai", "foga-cell-7"), keccak256("ext:finchip.ai:foga-cell-7"));
        assertEq(h.fromCanonical("ext:finchip.ai:foga-cell-7"), h.fromExt("finchip.ai", "foga-cell-7"));
    }
}

contract PredicatesTest is TestBase {
    PredicatesHarness h;

    function setUp() public {
        h = new PredicatesHarness();
    }

    function leaf(uint8 kind) internal pure returns (AIFPPredicates.Node memory n) {
        n.kind = kind;
    }

    function test_empty_is_malformed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](0);
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_single_leaf_is_well_formed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = leaf(AIFPPredicates.OPEN);
        assertTrue(h.isWellFormed(abi.encode(nodes)));
        assertEq(h.hashOf(abi.encode(nodes)), keccak256(abi.encode(nodes)));
    }

    /// @dev One composite root with `n - 1` open leaves under it.
    function fan(uint256 n) internal pure returns (AIFPPredicates.Node[] memory nodes) {
        nodes = new AIFPPredicates.Node[](n);
        nodes[0] = leaf(AIFPPredicates.ANY_OF);
        nodes[0].childStart = 1;
        // forge-lint: disable-next-line(unsafe-typecast)
        nodes[0].childCount = uint8(n - 1);
        for (uint256 i = 1; i < n; i++) {
            nodes[i] = leaf(AIFPPredicates.OPEN);
        }
    }

    function test_too_many_nodes() public view {
        assertFalse(h.isWellFormed(abi.encode(fan(65))), "65 nodes");
        assertTrue(h.isWellFormed(abi.encode(fan(64))), "64 nodes: a root and 63 leaves");
    }

    /// @dev A node that no composite names as its child is not part of the tree.
    function test_unreachable_node_is_malformed() public view {
        AIFPPredicates.Node[] memory two = new AIFPPredicates.Node[](2);
        two[0] = leaf(AIFPPredicates.OPEN);
        two[1] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(two)), "two roots");
        AIFPPredicates.Node[] memory nodes = fan(4);
        nodes[0].childCount = 2; // node 3 is left without a parent
        assertFalse(h.isWellFormed(abi.encode(nodes)), "an orphan after the last child");
    }

    /// @dev A node that two composites name as their child would be evaluated once per path.
    function test_node_with_two_parents_is_malformed() public view {
        // allOf(anyOf(x), anyOf(x)) with both inner composites pointing at node 3
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](4);
        nodes[0] = leaf(AIFPPredicates.ALL_OF);
        nodes[0].childStart = 1;
        nodes[0].childCount = 2;
        nodes[1] = leaf(AIFPPredicates.ANY_OF);
        nodes[1].childStart = 3;
        nodes[1].childCount = 1;
        nodes[2] = leaf(AIFPPredicates.ANY_OF);
        nodes[2].childStart = 3;
        nodes[2].childCount = 1;
        nodes[3] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(nodes)), "shared child");
        // overlapping child ranges: node 0 owns [1, 3), node 1 owns [2, 4)
        nodes[1].childStart = 2;
        nodes[1].childCount = 2;
        nodes[2] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(nodes)), "overlapping ranges");
        // the same four nodes as a proper tree: allOf(anyOf(open), open) needs node 1 to own [3, 4) only
        nodes[1].childStart = 3;
        nodes[1].childCount = 1;
        assertTrue(h.isWellFormed(abi.encode(nodes)), "each node has one parent");
    }

    /// @dev Five layers of four composites, each naming the whole next layer, and one leaf at the bottom: 22
    ///      nodes that used to be accepted and called that leaf 1,024 times.
    function test_layered_sharing_is_malformed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](22);
        nodes[0] = leaf(AIFPPredicates.ALL_OF);
        nodes[0].childStart = 1;
        nodes[0].childCount = 4;
        for (uint8 layer = 0; layer < 5; layer++) {
            for (uint8 j = 0; j < 4; j++) {
                uint8 idx = 1 + layer * 4 + j;
                nodes[idx] = leaf(AIFPPredicates.ALL_OF);
                nodes[idx].childStart = layer < 4 ? 1 + (layer + 1) * 4 : 21;
                nodes[idx].childCount = layer < 4 ? 4 : 1;
            }
        }
        nodes[21] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_child_must_follow_parent() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](2);
        nodes[0] = leaf(AIFPPredicates.OPEN);
        nodes[1] = leaf(AIFPPredicates.ALL_OF);
        nodes[1].childStart = 0; // points before itself
        nodes[1].childCount = 1;
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_leaf_with_children_is_malformed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](2);
        nodes[0] = leaf(AIFPPredicates.OPEN);
        nodes[0].childStart = 1;
        nodes[0].childCount = 1;
        nodes[1] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_composite_without_children_is_malformed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = leaf(AIFPPredicates.ANY_OF);
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_children_out_of_bounds_is_malformed() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](2);
        nodes[0] = leaf(AIFPPredicates.ALL_OF);
        nodes[0].childStart = 1;
        nodes[0].childCount = 2; // only one node follows
        nodes[1] = leaf(AIFPPredicates.OPEN);
        assertFalse(h.isWellFormed(abi.encode(nodes)));
    }

    function test_nested_well_formed() public view {
        // allOf(anyOf(open, open), open)
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](5);
        nodes[0] = leaf(AIFPPredicates.ALL_OF);
        nodes[0].childStart = 1;
        nodes[0].childCount = 2;
        nodes[1] = leaf(AIFPPredicates.ANY_OF);
        nodes[1].childStart = 3;
        nodes[1].childCount = 2;
        nodes[2] = leaf(AIFPPredicates.OPEN);
        nodes[3] = leaf(AIFPPredicates.OPEN);
        nodes[4] = leaf(AIFPPredicates.OPEN);
        assertTrue(h.isWellFormed(abi.encode(nodes)));
    }

    /// @dev `links` single-child composites in a row ending in one open leaf: the leaf lies at depth `links`.
    function chain(uint256 links) internal pure returns (AIFPPredicates.Node[] memory nodes) {
        nodes = new AIFPPredicates.Node[](links + 1);
        for (uint256 i = 0; i < links; i++) {
            nodes[i] = leaf(AIFPPredicates.ALL_OF);
            // forge-lint: disable-next-line(unsafe-typecast)
            nodes[i].childStart = uint8(i + 1);
            nodes[i].childCount = 1;
        }
        nodes[links] = leaf(AIFPPredicates.OPEN);
    }

    /// @dev anyOf(open, <branch>), the branch being `links` composites in a row ending in a leaf: that leaf
    ///      lies at depth `links + 1`, while the first child of the root lies at depth 1.
    function sideBranch(uint256 links) internal pure returns (AIFPPredicates.Node[] memory nodes) {
        nodes = new AIFPPredicates.Node[](links + 3);
        nodes[0] = leaf(AIFPPredicates.ANY_OF);
        nodes[0].childStart = 1;
        nodes[0].childCount = 2;
        nodes[1] = leaf(AIFPPredicates.OPEN);
        for (uint256 i = 2; i < links + 2; i++) {
            nodes[i] = leaf(AIFPPredicates.ALL_OF);
            // forge-lint: disable-next-line(unsafe-typecast)
            nodes[i].childStart = uint8(i + 1);
            nodes[i].childCount = 1;
        }
        nodes[links + 2] = leaf(AIFPPredicates.OPEN);
    }

    /// @dev The root has depth 0 and a child one more than its parent; no node may lie deeper than 8.
    function test_depth_limit_sits_at_eight() public view {
        assertTrue(h.isWellFormed(abi.encode(chain(8))), "a leaf at depth 8");
        assertFalse(h.isWellFormed(abi.encode(chain(9))), "a leaf at depth 9");
        assertFalse(h.isWellFormed(abi.encode(chain(63))), "a chain through all 64 nodes");
    }

    /// @dev The depth of every node counts, not only of the nodes an evaluation would visit: one branch that
    ///      is too deep makes the array malformed, however shallow the rest of the tree is.
    function test_depth_is_checked_on_every_branch() public view {
        assertTrue(h.isWellFormed(abi.encode(sideBranch(7))), "deepest leaf at depth 8");
        assertFalse(h.isWellFormed(abi.encode(sideBranch(8))), "deepest leaf at depth 9");
        // A wide tree is not a deep one: 63 leaves under the root all lie at depth 1.
        assertTrue(h.isWellFormed(abi.encode(fan(64))), "wide");
    }

    /// @dev Section 6.1 stated another way than the library computes it: count the composites that name each
    ///      node, then walk from every node up to the root and count the steps.
    function expectedWellFormed(AIFPPredicates.Node[] memory nodes) internal pure returns (bool) {
        uint256 n = nodes.length;
        if (n == 0 || n > 64) return false;
        uint256[] memory parents = new uint256[](n);
        uint256[] memory parentOf = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 start = nodes[i].childStart;
            uint256 count = nodes[i].childCount;
            if (nodes[i].kind != AIFPPredicates.ALL_OF && nodes[i].kind != AIFPPredicates.ANY_OF) {
                if (start != 0 || count != 0) return false;
                continue;
            }
            if (count == 0 || start <= i || start + count > n) return false;
            for (uint256 c = start; c < start + count; c++) {
                parents[c]++;
                parentOf[c] = i;
            }
        }
        for (uint256 j = 1; j < n; j++) {
            if (parents[j] != 1) return false;
        }
        for (uint256 j = 1; j < n; j++) {
            uint256 depth;
            for (uint256 k = j; k != 0; k = parentOf[k]) depth++;
            if (depth > 8) return false;
        }
        return true;
    }

    /// @dev A tree built breadth-first as the canonical validator allocates it, of up to `size` nodes, in which
    ///      a node becomes a composite with probability `compositeIn256 / 256` while nodes remain to be given
    ///      and a composite has between one and `maxChildren` children. With one child per composite the tree
    ///      is a chain, and deep; with three it is shallow.
    function randomTree(uint256 seed, uint256 size, uint256 compositeIn256, uint256 maxChildren)
        internal
        pure
        returns (AIFPPredicates.Node[] memory nodes)
    {
        nodes = new AIFPPredicates.Node[](size);
        uint256 next = 1;
        for (uint256 i = 0; i < next; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            if (next < size && (seed & 0xff) < compositeIn256) {
                uint256 count = 1 + ((seed >> 8) % maxChildren);
                if (count > size - next) count = size - next;
                nodes[i] = leaf((seed >> 16) & 1 == 0 ? AIFPPredicates.ALL_OF : AIFPPredicates.ANY_OF);
                // forge-lint: disable-next-line(unsafe-typecast)
                nodes[i].childStart = uint8(next);
                // forge-lint: disable-next-line(unsafe-typecast)
                nodes[i].childCount = uint8(count);
                next += count;
            } else {
                nodes[i] = leaf(AIFPPredicates.OPEN);
            }
        }
        assembly ("memory-safe") {
            mstore(nodes, next) // drop the nodes that were not given to any composite
        }
    }

    /// @dev Random trees, half of them with one field of one node changed afterwards, against the independent
    ///      statement above. Chains are deep and bushy trees shallow, so both sides of the depth limit and
    ///      both kinds of defect (shape and depth) occur.
    function testFuzz_isWellFormed_matches_an_independent_statement(uint256 seed) public view {
        AIFPPredicates.Node[] memory nodes = randomTree(seed, 1 + (seed % 64), 160 + ((seed >> 8) % 96), 1 + ((seed >> 16) % 3));
        uint256 r = uint256(keccak256(abi.encode(seed, "mutation")));
        if (r & 1 == 1) {
            AIFPPredicates.Node memory target = nodes[(r >> 8) % nodes.length];
            uint256 field = (r >> 16) % 3;
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 delta = (r >> 24) & 1 == 0 ? 1 : uint8(255); // plus or minus one, wrapping
            unchecked {
                if (field == 0) target.childStart += delta;
                else if (field == 1) target.childCount += delta;
                else target.kind = target.kind == AIFPPredicates.OPEN ? AIFPPredicates.ANY_OF : AIFPPredicates.OPEN;
            }
        }
        assertTrue(h.isWellFormed(abi.encode(nodes)) == expectedWellFormed(nodes), "isWellFormed differs from Section 6.1");
    }

    /// @dev The fuzz above is only worth something if it meets both answers and both reasons for a refusal.
    function test_the_random_trees_cover_both_answers() public view {
        uint256 wellFormed;
        uint256 tooDeepOnly;
        uint256 malformedShape;
        for (uint256 seed = 1; seed <= 400; seed++) {
            AIFPPredicates.Node[] memory nodes = randomTree(seed * 7919, 1 + (seed % 64), 160 + (seed % 96), 1 + (seed % 3));
            bool expected = expectedWellFormed(nodes);
            assertTrue(h.isWellFormed(abi.encode(nodes)) == expected, "isWellFormed differs from Section 6.1");
            if (expected) wellFormed++;
            else tooDeepOnly++; // an unmutated tree can only fail on depth
            nodes[0].childCount = 0; // a root that claims nothing: malformed unless it is the only node
            nodes[0].kind = AIFPPredicates.ANY_OF;
            assertFalse(h.isWellFormed(abi.encode(nodes)), "composite without children");
            malformedShape++;
        }
        assertTrue(wellFormed > 200, "too few well-formed trees");
        assertTrue(tooDeepOnly > 30, "too few trees beyond the depth limit");
        assertTrue(malformedShape == 400);
    }
}

contract RolesTest is TestBase {
    RolesHarness h;

    function setUp() public {
        h = new RolesHarness();
    }

    function test_single_and_defined() public view {
        assertTrue(h.isSingle(AIFPRoles.SUBMIT));
        assertTrue(h.isSingle(AIFPRoles.MANAGE_DISCLOSURE));
        assertFalse(h.isSingle(AIFPRoles.SUBMIT | AIFPRoles.RESPOND));
        assertFalse(h.isSingle(0));
        assertFalse(h.isSingle(1 << 11)); // reserved bit
        assertTrue(h.isDefined(AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE));
        assertTrue(h.isDefined(AIFPRoles.ALL_DEFINED));
        assertFalse(h.isDefined(0));
        assertFalse(h.isDefined(AIFPRoles.SUBMIT | (1 << 12)));
    }
}
