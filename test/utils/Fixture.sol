// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {TestBase, Vm} from "./TestBase.sol";
import {AIFPParadigmRegistry} from "../../assets/erc-aifp/contracts/AIFPParadigmRegistry.sol";
import {AIFPChannelRegistry} from "../../assets/erc-aifp/contracts/AIFPChannelRegistry.sol";
import {AIFPParticipationRegistry} from "../../assets/erc-aifp/contracts/AIFPParticipationRegistry.sol";
import {AIFPCompositeVerifier} from "../../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";
import {AIFPSubjectSet} from "../../assets/erc-aifp/contracts/AIFPSubjectSet.sol";
import {AIFPEventAnchor} from "../../assets/erc-aifp/contracts/AIFPEventAnchor.sol";
import {IAIFPParadigmRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPParadigmRegistry.sol";
import {IAIFPChannelRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPChannelRegistry.sol";
import {IAIFPParticipationRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPParticipationRegistry.sol";
import {IAIFPCompositeVerifier, IAIFPPredicateVerifier, IAIFPSubjectSet} from "../../assets/erc-aifp/contracts/interfaces/IAIFPPredicateVerifier.sol";
import {IAIFPEventAnchor} from "../../assets/erc-aifp/contracts/interfaces/IAIFPEventAnchor.sol";
import {IERC6372} from "../../assets/erc-aifp/contracts/interfaces/IERC6372.sol";
import {IERC165} from "../../assets/erc-aifp/contracts/interfaces/IERC165.sol";
import {AIFPObjectionWindow} from "../../assets/erc-aifp/contracts/companions/AIFPObjectionWindow.sol";
import {AIFPEvents} from "../../assets/erc-aifp/contracts/libraries/AIFPEvents.sol";
import {AIFPPredicates} from "../../assets/erc-aifp/contracts/libraries/AIFPPredicates.sol";
import {AIFPRoles} from "../../assets/erc-aifp/contracts/libraries/AIFPRoles.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";
import {AIFPBasis} from "../../assets/erc-aifp/contracts/libraries/AIFPBasis.sol";
import {AIFPBindings} from "../../assets/erc-aifp/contracts/libraries/AIFPBindings.sol";
import {AIFPSubject} from "../../assets/erc-aifp/contracts/libraries/AIFPSubject.sol";

/// @dev Deploys the whole reference stack and offers helpers shared by the unit tests and the boundary cases.
abstract contract Fixture is TestBase {
    AIFPParadigmRegistry internal paradigms;
    AIFPChannelRegistry internal channels;
    AIFPParticipationRegistry internal participation;
    AIFPCompositeVerifier internal verifier;
    AIFPEventAnchor internal anchor;

    // Actors: A (authority / cell A), B (cell B), C (third logical participant), O (outsider).
    address internal A = address(0xA11CE);
    address internal B = address(0xB0B);
    address internal C = address(0xCA11);
    address internal O = address(0x0DD);

    uint48 internal constant T0 = 1_700_000_000;

    function setUp() public virtual {
        vm.warp(T0);
        paradigms = new AIFPParadigmRegistry();
        channels = new AIFPChannelRegistry(paradigms);
        verifier = new AIFPCompositeVerifier();
        participation = new AIFPParticipationRegistry(channels, paradigms, verifier);
        channels.setParticipationRegistry(participation);
        anchor = new AIFPEventAnchor(channels, participation);
        vm.label(A, "A");
        vm.label(B, "B");
        vm.label(C, "C");
        vm.label(O, "O");
    }

    // ------------------------------------------------------------ subjects

    function subj(address a) internal view returns (bytes32) {
        return AIFPSubject.self(a);
    }

    // ------------------------------------------------------------ predicates

    function openPredicate() internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.OPEN, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        return abi.encode(nodes);
    }

    function allowlistPredicate(address set) internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALLOWLIST, childStart: 0, childCount: 0, verifier: set, ref: 0, params: ""});
        return abi.encode(nodes);
    }

    function externalPredicate(uint8 kind, address ext, bytes32 ref) internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: kind, childStart: 0, childCount: 0, verifier: ext, ref: ref, params: ""});
        return abi.encode(nodes);
    }

    /// @dev allOf(leaf1, leaf2) where leaves are given as single-node predicates.
    function allOf2(bytes memory p1, bytes memory p2) internal pure returns (bytes memory) {
        return composite2(AIFPPredicates.ALL_OF, p1, p2);
    }

    function anyOf2(bytes memory p1, bytes memory p2) internal pure returns (bytes memory) {
        return composite2(AIFPPredicates.ANY_OF, p1, p2);
    }

    function composite2(uint8 kind, bytes memory p1, bytes memory p2) internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory a = AIFPPredicates.decode(p1);
        AIFPPredicates.Node[] memory b = AIFPPredicates.decode(p2);
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](3);
        nodes[0] = AIFPPredicates.Node({kind: kind, childStart: 1, childCount: 2, verifier: address(0), ref: 0, params: ""});
        nodes[1] = a[0];
        nodes[2] = b[0];
        return abi.encode(nodes);
    }

    function noEvidence() internal pure returns (bytes[] memory ev) {
        ev = new bytes[](0);
    }

    // ------------------------------------------------------------ paradigms and channels

    /// @dev Registers a paradigm whose canonical descriptor is a short stand-in string (the on-chain registry
    ///      never parses it) with the given labels and role predicates.
    function registerParadigm(
        address registrant,
        string memory descriptor,
        bytes32 family,
        bytes32 supersedes,
        bytes32[] memory labels,
        IAIFPParadigmRegistry.RolePredicate[] memory preds
    ) internal returns (bytes32) {
        vm.prank(registrant);
        return paradigms.registerParadigm(bytes(descriptor), family, supersedes, labels, preds, "ipfs://descriptor");
    }

    function onePred(uint16 role, bytes memory predicate) internal pure returns (IAIFPParadigmRegistry.RolePredicate[] memory preds) {
        preds = new IAIFPParadigmRegistry.RolePredicate[](1);
        preds[0] = IAIFPParadigmRegistry.RolePredicate({role: role, predicateHash: keccak256(predicate)});
    }

    function twoPreds(uint16 r1, bytes memory p1, uint16 r2, bytes memory p2)
        internal
        pure
        returns (IAIFPParadigmRegistry.RolePredicate[] memory preds)
    {
        preds = new IAIFPParadigmRegistry.RolePredicate[](2);
        preds[0] = IAIFPParadigmRegistry.RolePredicate({role: r1, predicateHash: keccak256(p1)});
        preds[1] = IAIFPParadigmRegistry.RolePredicate({role: r2, predicateHash: keccak256(p2)});
    }

    function noPreds() internal pure returns (IAIFPParadigmRegistry.RolePredicate[] memory preds) {
        preds = new IAIFPParadigmRegistry.RolePredicate[](0);
    }

    function labels1(string memory l) internal pure returns (bytes32[] memory out) {
        out = new bytes32[](1);
        out[0] = keccak256(bytes(l));
    }

    function openChannel(address authority, bytes32 paradigmId) internal returns (bytes32) {
        IAIFPChannelRegistry.BindingDecl[] memory none = new IAIFPChannelRegistry.BindingDecl[](0);
        vm.prank(authority);
        return channels.openChannel(paradigmId, authority, bytes32(0), "ipfs://channel", none);
    }

    function grantRoles(address by, bytes32 channelId, address to, uint16 roles, bytes32 scopeRef) internal returns (bytes32) {
        vm.prank(by);
        return participation.grant(channelId, subj(to), bytes32(0), roles, scopeRef, AIFPBasis.MANAGER_GRANT, bytes32(0), 0, 0);
    }

    function evalNow(bytes32 channelId, address who, uint16 role, bytes32 scopeRef) internal view returns (uint8) {
        return participation.evaluateNow(channelId, subj(who), role, scopeRef);
    }

    function evalAt(bytes32 channelId, address who, uint16 role, bytes32 scopeRef, uint48 t) internal view returns (uint8) {
        return participation.evaluate(channelId, subj(who), role, scopeRef, t);
    }

    function warpBy(uint48 delta) internal {
        vm.warp(block.timestamp + delta);
    }

    function now48() internal view returns (uint48) {
        return uint48(block.timestamp);
    }

    // ------------------------------------------------------------ shortcuts

    /// @dev Registers a one-label paradigm with a single role predicate (or none when `predicate` is empty).
    function simpleParadigm(address registrant, string memory family, string memory label, uint16 role, bytes memory predicate)
        internal
        returns (bytes32)
    {
        IAIFPParadigmRegistry.RolePredicate[] memory preds = predicate.length == 0 ? noPreds() : onePred(role, predicate);
        string memory descriptor = string(abi.encodePacked("{\"aifp\":\"1\",\"family\":\"", family, "\",\"label\":\"", label, "\"}"));
        return registerParadigm(registrant, descriptor, keccak256(bytes(family)), bytes32(0), labels1(label), preds);
    }

    /// @dev Registers a successor version in the same family (descriptor text differs by `version`).
    function successorParadigm(
        address registrant,
        string memory family,
        string memory label,
        bytes32 supersedes,
        string memory version,
        IAIFPParadigmRegistry.RolePredicate[] memory preds
    ) internal returns (bytes32) {
        string memory descriptor = string(
            abi.encodePacked("{\"aifp\":\"1\",\"family\":\"", family, "\",\"label\":\"", label, "\",\"version\":\"", version, "\"}")
        );
        return registerParadigm(registrant, descriptor, keccak256(bytes(family)), supersedes, labels1(label), preds);
    }

    function transportBinding(uint32 capabilities, bytes32 target) internal pure returns (IAIFPChannelRegistry.BindingDecl memory d) {
        d.kind = AIFPBindings.KIND_TRANSPORT;
        d.target = target;
        d.version = bytes32("v1");
        d.capabilities = capabilities;
    }

    function governanceBinding(uint8 kind, address executor, uint32 effectScope, uint8 adoptionMode)
        internal
        pure
        returns (IAIFPChannelRegistry.BindingDecl memory d)
    {
        d.kind = kind;
        d.target = AIFPBindings.toTarget(executor);
        d.version = bytes32("v1");
        d.effectScope = effectScope;
        d.adoptionMode = adoptionMode;
    }

    function declare(address by, bytes32 channelId, IAIFPChannelRegistry.BindingDecl memory d) internal returns (bytes32) {
        vm.prank(by);
        return channels.declareBinding(channelId, d);
    }

    function admitAs(address who, bytes32 channelId, uint16 role, bytes32 scopeRef, bytes memory predicate, bytes[] memory evidence)
        internal
        returns (bytes32)
    {
        vm.prank(who);
        return participation.admit(channelId, role, scopeRef, predicate, evidence, 0);
    }

    function evidence1(bytes memory e) internal pure returns (bytes[] memory ev) {
        ev = new bytes[](1);
        ev[0] = e;
    }

    function evidenceAt(uint256 index, bytes memory e) internal pure returns (bytes[] memory ev) {
        ev = new bytes[](index + 1);
        ev[index] = e;
    }

    function sel(bytes4 s, bytes memory args) internal pure returns (bytes memory) {
        return abi.encodePacked(s, args);
    }
}
