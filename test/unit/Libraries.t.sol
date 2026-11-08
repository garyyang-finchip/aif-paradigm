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

    function test_too_many_nodes() public view {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](65);
        for (uint256 i = 0; i < 65; i++) {
            nodes[i] = leaf(AIFPPredicates.OPEN);
        }
        assertFalse(h.isWellFormed(abi.encode(nodes)));
        AIFPPredicates.Node[] memory ok = new AIFPPredicates.Node[](64);
        for (uint256 i = 0; i < 64; i++) {
            ok[i] = leaf(AIFPPredicates.OPEN);
        }
        assertTrue(h.isWellFormed(abi.encode(ok)));
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
