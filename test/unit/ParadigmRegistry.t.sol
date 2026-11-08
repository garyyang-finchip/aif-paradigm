// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";

contract ParadigmRegistryTest is Fixture {
    bytes32 constant FAM = keccak256("fam");

    function test_identity_is_hash_of_canonical_descriptor() public {
        bytes memory descriptor = bytes("{\"aifp\":\"1\",\"family\":\"fam\",\"version\":\"1\"}");
        vm.prank(A);
        bytes32 id = paradigms.registerParadigm(descriptor, FAM, 0, labels1("aifp:paradigm/source/v1"), noPreds(), "ipfs://x");
        assertEq(id, keccak256(descriptor));
        IAIFPParadigmRegistry.ParadigmRecord memory r = paradigms.paradigm(id);
        assertEq(r.family, FAM);
        assertEq(r.supersedes, bytes32(0));
        assertEq(r.registrant, A);
        assertEq(uint256(r.registeredAt), uint256(T0));
        assertEq(r.descriptorURI, "ipfs://x");
        assertTrue(paradigms.exists(id));
        assertFalse(paradigms.exists(keccak256("other")));
    }

    function test_duplicate_descriptor_reverts() public {
        bytes memory descriptor = bytes("dup");
        vm.prank(A);
        bytes32 id = paradigms.registerParadigm(descriptor, FAM, 0, labels1("aifp:paradigm/club/v1"), noPreds(), "");
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_ParadigmExists.selector, id));
        paradigms.registerParadigm(descriptor, FAM, 0, labels1("aifp:paradigm/club/v1"), noPreds(), "");
    }

    function test_empty_descriptor_reverts() public {
        vm.prank(A);
        vm.expectRevert(IAIFPParadigmRegistry.AIFP_EmptyDescriptor.selector);
        paradigms.registerParadigm("", FAM, 0, labels1("aifp:paradigm/club/v1"), noPreds(), "");
    }

    function test_family_controller_claim_and_enforcement() public {
        assertEq(paradigms.familyController(FAM), address(0));
        vm.prank(A);
        bytes32 v1 = paradigms.registerParadigm("v1", FAM, 0, labels1("aifp:paradigm/club/v1"), noPreds(), "");
        assertEq(paradigms.familyController(FAM), A);
        // B cannot add a version to A's family
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_NotFamilyController.selector, FAM, B));
        paradigms.registerParadigm("v2", FAM, v1, labels1("aifp:paradigm/club/v1"), noPreds(), "");
        // A transfers the family to B, then B can
        vm.prank(A);
        paradigms.transferFamily(FAM, B);
        assertEq(paradigms.familyController(FAM), B);
        vm.prank(B);
        bytes32 v2 = paradigms.registerParadigm("v2", FAM, v1, labels1("aifp:paradigm/club/v1"), noPreds(), "");
        assertEq(paradigms.paradigm(v2).supersedes, v1);
        // A can no longer transfer
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_NotFamilyController.selector, FAM, A));
        paradigms.transferFamily(FAM, A);
        // unknown family cannot be transferred
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_NotFamilyController.selector, keccak256("nofam"), A));
        paradigms.transferFamily(keccak256("nofam"), A);
    }

    function test_supersedes_must_exist_and_share_family() public {
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_UnknownParadigm.selector, keccak256("ghost")));
        paradigms.registerParadigm("v1", FAM, keccak256("ghost"), labels1("aifp:paradigm/club/v1"), noPreds(), "");

        vm.prank(A);
        bytes32 other = paradigms.registerParadigm("other", keccak256("otherfam"), 0, labels1("aifp:paradigm/club/v1"), noPreds(), "");
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_SupersedesOutsideFamily.selector, other, FAM));
        paradigms.registerParadigm("v1", FAM, other, labels1("aifp:paradigm/club/v1"), noPreds(), "");
    }

    function test_labels_are_deduplicated_and_queryable() public {
        bytes32[] memory labels = new bytes32[](3);
        labels[0] = keccak256("aifp:paradigm/source/v1");
        labels[1] = keccak256("aifp:paradigm/archive/v1");
        labels[2] = keccak256("aifp:paradigm/source/v1");
        vm.prank(A);
        bytes32 id = paradigms.registerParadigm("src", FAM, 0, labels, noPreds(), "");
        bytes32[] memory stored = paradigms.labelsOf(id);
        assertEq(stored.length, 2);
        assertTrue(paradigms.hasLabel(id, keccak256("aifp:paradigm/source/v1")));
        assertTrue(paradigms.hasLabel(id, keccak256("aifp:paradigm/archive/v1")));
        assertFalse(paradigms.hasLabel(id, keccak256("aifp:paradigm/club/v1")));
    }

    function test_role_predicates_recorded_and_invalid_role_rejected() public {
        bytes memory p = openPredicate();
        bytes32 id = registerParadigm(A, "preds", FAM, 0, labels1("aifp:paradigm/club/v1"), twoPreds(AIFPRoles.SUBMIT, p, AIFPRoles.OBSERVE, allowlistPredicate(address(1))));
        assertEq(paradigms.rolePredicateHash(id, AIFPRoles.SUBMIT), keccak256(p));
        assertEq(paradigms.rolePredicateHash(id, AIFPRoles.OBSERVE), keccak256(allowlistPredicate(address(1))));
        assertEq(paradigms.rolePredicateHash(id, AIFPRoles.RESPOND), bytes32(0));

        IAIFPParadigmRegistry.RolePredicate[] memory bad = new IAIFPParadigmRegistry.RolePredicate[](1);
        bad[0] = IAIFPParadigmRegistry.RolePredicate({role: AIFPRoles.SUBMIT | AIFPRoles.RESPOND, predicateHash: keccak256(p)});
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.SUBMIT | AIFPRoles.RESPOND)));
        paradigms.registerParadigm("bad", FAM, 0, labels1("aifp:paradigm/club/v1"), bad, "");
    }

    function test_events() public {
        bytes memory descriptor = bytes("evt");
        bytes32 id = keccak256(descriptor);
        vm.expectEmit(true, true, true, true);
        emit IAIFPParadigmRegistry.FamilyControllerChanged(FAM, address(0), A);
        vm.expectEmit(true, true, true, true);
        emit IAIFPParadigmRegistry.ParadigmRegistered(id, FAM, bytes32(0), A, "u");
        vm.expectEmit(true, true, true, true);
        emit IAIFPParadigmRegistry.ParadigmDescriptor(id, descriptor);
        vm.prank(A);
        paradigms.registerParadigm(descriptor, FAM, 0, labels1("aifp:paradigm/club/v1"), noPreds(), "u");
    }

    function test_unknown_paradigm_view_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_UnknownParadigm.selector, keccak256("nope")));
        paradigms.paradigm(keccak256("nope"));
    }

    function test_erc165_and_clock() public view {
        assertTrue(paradigms.supportsInterface(type(IAIFPParadigmRegistry).interfaceId));
        assertTrue(paradigms.supportsInterface(0x01ffc9a7));
        assertTrue(paradigms.supportsInterface(type(IERC6372).interfaceId));
        assertEq(paradigms.CLOCK_MODE(), "mode=timestamp");
        assertEq(uint256(paradigms.clock()), block.timestamp);
    }
}
