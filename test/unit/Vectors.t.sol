// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {TestBase} from "../utils/TestBase.sol";
import {AIFPSubject} from "../../assets/erc-aifp/contracts/libraries/AIFPSubject.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";
import {AIFPPredicates} from "../../assets/erc-aifp/contracts/libraries/AIFPPredicates.sol";
import {IAIFPParadigmRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPParadigmRegistry.sol";
import {IAIFPChannelRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPChannelRegistry.sol";
import {IAIFPParticipationRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPParticipationRegistry.sol";
import {IAIFPCompositeVerifier, IAIFPPredicateVerifier, IAIFPSubjectSet} from "../../assets/erc-aifp/contracts/interfaces/IAIFPPredicateVerifier.sol";
import {IAIFPEventAnchor} from "../../assets/erc-aifp/contracts/interfaces/IAIFPEventAnchor.sol";

/// @dev Exposes the internal library functions to the vector tests.
contract LibHarness {
    function subjectAddress(uint256 chainId, address a) external pure returns (string memory, bytes32) {
        return (AIFPSubject.canonicalAddress(chainId, a), AIFPSubject.fromAddress(chainId, a));
    }

    function subjectERC8004(uint256 chainId, address registry, uint256 agentId) external pure returns (string memory, bytes32) {
        return (AIFPSubject.canonicalERC8004(chainId, registry, agentId), AIFPSubject.fromERC8004(chainId, registry, agentId));
    }

    function subjectDID(string memory method, string memory id) external pure returns (string memory, bytes32) {
        return (AIFPSubject.canonicalDID(method, id), AIFPSubject.fromDID(method, id));
    }

    function subjectExt(string memory ns, string memory id) external pure returns (string memory, bytes32) {
        return (AIFPSubject.canonicalExt(ns, id), AIFPSubject.fromExt(ns, id));
    }

    function allOf(uint8[] memory o) external pure returns (uint8) {
        return AIFPOutcomes.allOf(o);
    }

    function anyOf(uint8[] memory o) external pure returns (uint8) {
        return AIFPOutcomes.anyOf(o);
    }

    function predicateHash(bytes memory encoding) external pure returns (bytes32, uint256, bool) {
        AIFPPredicates.Node[] memory nodes = AIFPPredicates.decode(encoding);
        return (AIFPPredicates.hashOf(nodes), nodes.length, AIFPPredicates.isWellFormed(nodes));
    }

    function nodeAt(bytes memory encoding, uint256 i) external pure returns (uint8 kind, uint8 childStart, uint8 childCount) {
        AIFPPredicates.Node[] memory nodes = AIFPPredicates.decode(encoding);
        return (nodes[i].kind, nodes[i].childStart, nodes[i].childCount);
    }
}

/// @notice Cross-checks the JSON vectors produced by tools/make-vectors.mjs against the Solidity libraries
///         and interfaces, so that the off-chain tooling and the on-chain reference agree byte for byte.
contract VectorsTest is TestBase {
    string constant DIR = "assets/erc-aifp/vectors/";
    LibHarness h;

    function setUp() public {
        h = new LibHarness();
    }

    function _read(string memory name) internal view returns (string memory) {
        return vm.readFile(string.concat(DIR, name));
    }

    function _key(string memory prefix, uint256 i, string memory field) internal pure returns (string memory) {
        return string.concat(prefix, "[", vm.toString(i), "].", field);
    }

    // ------------------------------------------------------------------ subject refs

    function test_subjectRefs_matchLibrary() public view {
        string memory json = _read("subject-refs.json");
        uint256 n = vm.parseJsonUint(json, ".count");
        assertTrue(n >= 7, "subject vectors present");
        for (uint256 i = 0; i < n; i++) {
            string memory kind = vm.parseJsonString(json, _key(".vectors", i, "kind"));
            string memory expectedCanonical = vm.parseJsonString(json, _key(".vectors", i, "canonical"));
            bytes32 expectedRef = vm.parseJsonBytes32(json, _key(".vectors", i, "ref"));
            string memory canonical;
            bytes32 ref;
            if (_eq(kind, "eip155-address")) {
                uint256 chainId = vm.parseJsonUint(json, _key(".vectors", i, "chainId"));
                address a = _parseAddress(vm.parseJsonString(json, _key(".vectors", i, "address")));
                (canonical, ref) = h.subjectAddress(chainId, a);
            } else if (_eq(kind, "erc8004")) {
                uint256 chainId = vm.parseJsonUint(json, _key(".vectors", i, "chainId"));
                address registry = _parseAddress(vm.parseJsonString(json, _key(".vectors", i, "registry")));
                uint256 agentId = vm.parseJsonUint(json, _key(".vectors", i, "agentId"));
                (canonical, ref) = h.subjectERC8004(chainId, registry, agentId);
            } else if (_eq(kind, "did")) {
                (canonical, ref) = h.subjectDID(vm.parseJsonString(json, _key(".vectors", i, "method")), vm.parseJsonString(json, _key(".vectors", i, "id")));
            } else {
                (canonical, ref) = h.subjectExt(vm.parseJsonString(json, _key(".vectors", i, "namespace")), vm.parseJsonString(json, _key(".vectors", i, "identifier")));
            }
            vm.assertEq(canonical, expectedCanonical, string.concat("canonical ", vm.toString(i)));
            vm.assertEq(ref, expectedRef, string.concat("ref ", vm.toString(i)));
            vm.assertEq(keccak256(bytes(expectedCanonical)), expectedRef, string.concat("ref is keccak of canonical ", vm.toString(i)));
        }
    }

    // ------------------------------------------------------------------ predicate encodings

    function test_predicateEncodings_matchLibrary() public view {
        string memory json = _read("predicate-encoding.json");
        uint256 n = vm.parseJsonUint(json, ".count");
        assertTrue(n >= 10, "predicate vectors present");
        for (uint256 i = 0; i < n; i++) {
            _checkPredicateVector(json, i);
        }
    }

    function _checkPredicateVector(string memory json, uint256 i) internal view {
        bytes memory encoding = vm.parseJsonBytes(json, _key(".vectors", i, "encoding"));
        bytes32 expectedHash = vm.parseJsonBytes32(json, _key(".vectors", i, "predicateHash"));
        (bytes32 hash, uint256 nodeCount, bool wellFormed) = h.predicateHash(encoding);
        vm.assertEq(hash, expectedHash, string.concat("predicate hash ", vm.toString(i)));
        vm.assertEq(hash, keccak256(encoding), "hash is keccak of encoding");
        assertTrue(wellFormed, string.concat("well formed ", vm.toString(i)));
        for (uint256 j = 0; j < nodeCount; j++) {
            _checkNode(json, _key(".vectors", i, "nodes"), encoding, j);
        }
    }

    /// @dev Node-level check: kind / childStart / childCount of every node as the tool described them.
    function _checkNode(string memory json, string memory nodesKey, bytes memory encoding, uint256 j) internal view {
        string memory p = string.concat(nodesKey, "[", vm.toString(j), "].");
        (uint8 kind, uint8 childStart, uint8 childCount) = h.nodeAt(encoding, j);
        vm.assertEq(uint256(kind), vm.parseJsonUint(json, string.concat(p, "kind")), "kind");
        vm.assertEq(uint256(childStart), vm.parseJsonUint(json, string.concat(p, "childStart")), "childStart");
        vm.assertEq(uint256(childCount), vm.parseJsonUint(json, string.concat(p, "childCount")), "childCount");
    }

    // ------------------------------------------------------------------ outcome tables

    function test_outcomeTables_matchLibrary() public view {
        string memory json = _read("outcome-tables.json");
        uint256 n = vm.parseJsonUint(json, ".count");
        assertTrue(n >= 16, "outcome vectors present");
        for (uint256 i = 0; i < n; i++) {
            uint256[] memory raw = vm.parseJsonUintArray(json, _key(".vectors", i, "inputs"));
            uint8[] memory inputs = new uint8[](raw.length);
            for (uint256 j = 0; j < raw.length; j++) inputs[j] = uint8(raw[j]);
            vm.assertEq(uint256(h.allOf(inputs)), vm.parseJsonUint(json, _key(".vectors", i, "allOf")), string.concat("allOf ", vm.toString(i)));
            vm.assertEq(uint256(h.anyOf(inputs)), vm.parseJsonUint(json, _key(".vectors", i, "anyOf")), string.concat("anyOf ", vm.toString(i)));
        }
    }

    // ------------------------------------------------------------------ interface ids

    function test_interfaceIds_matchContracts() public view {
        string memory json = _read("interface-ids.json");
        uint256 n = vm.parseJsonUint(json, ".count");
        assertTrue(n == 7, "seven interfaces");
        for (uint256 i = 0; i < n; i++) {
            string memory name = vm.parseJsonString(json, _key(".vectors", i, "name"));
            bytes memory raw = vm.parseJsonBytes(json, _key(".vectors", i, "interfaceId"));
            require(raw.length == 4, "interface id length");
            bytes4 expected = bytes4(raw);
            bytes4 actual;
            if (_eq(name, "IAIFPParadigmRegistry")) actual = type(IAIFPParadigmRegistry).interfaceId;
            else if (_eq(name, "IAIFPChannelRegistry")) actual = type(IAIFPChannelRegistry).interfaceId;
            else if (_eq(name, "IAIFPParticipationRegistry")) actual = type(IAIFPParticipationRegistry).interfaceId;
            else if (_eq(name, "IAIFPCompositeVerifier")) actual = type(IAIFPCompositeVerifier).interfaceId;
            else if (_eq(name, "IAIFPPredicateVerifier")) actual = type(IAIFPPredicateVerifier).interfaceId;
            else if (_eq(name, "IAIFPSubjectSet")) actual = type(IAIFPSubjectSet).interfaceId;
            else if (_eq(name, "IAIFPEventAnchor")) actual = type(IAIFPEventAnchor).interfaceId;
            else revert(string.concat("unknown interface in vectors: ", name));
            vm.assertEq(bytes32(actual), bytes32(expected), name);
        }
    }

    // ------------------------------------------------------------------ paradigm ids

    function test_paradigmIds_areKeccakOfCanonical() public view {
        string memory json = _read("paradigm-ids.json");
        uint256 n = vm.parseJsonUint(json, ".count");
        assertTrue(n == 17, "seventeen example descriptors");
        for (uint256 i = 0; i < n; i++) {
            string memory canonical = vm.parseJsonString(json, _key(".vectors", i, "canonical"));
            bytes32 expected = vm.parseJsonBytes32(json, _key(".vectors", i, "paradigmId"));
            vm.assertEq(keccak256(bytes(canonical)), expected, string.concat("paradigmId ", vm.toString(i)));
            string memory family = vm.parseJsonString(json, _key(".vectors", i, "family"));
            vm.assertEq(keccak256(bytes(family)), vm.parseJsonBytes32(json, _key(".vectors", i, "familyId")), "familyId");
            _checkRolePredicates(json, _key(".vectors", i, "rolePredicates"));
        }
    }

    /// @dev Role predicate hashes are keccak of their encodings and decode into well-formed trees.
    function _checkRolePredicates(string memory json, string memory rp) internal view {
        uint256 k = 0;
        while (vm.keyExists(json, string.concat(rp, "[", vm.toString(k), "].predicateHash"))) {
            bytes memory enc = vm.parseJsonBytes(json, string.concat(rp, "[", vm.toString(k), "].predicateHex"));
            (bytes32 hash,, bool wellFormed) = h.predicateHash(enc);
            vm.assertEq(hash, vm.parseJsonBytes32(json, string.concat(rp, "[", vm.toString(k), "].predicateHash")), "role predicate hash");
            assertTrue(wellFormed, "role predicate well formed");
            k++;
        }
    }

    // ------------------------------------------------------------------ helpers

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @dev Parses "0x" + 40 hex characters of either case.
    function _parseAddress(string memory s) internal pure returns (address) {
        bytes memory b = bytes(s);
        require(b.length == 42, "address length");
        uint160 v;
        for (uint256 i = 2; i < 42; i++) {
            uint8 c = uint8(b[i]);
            uint8 d;
            if (c >= 48 && c <= 57) d = c - 48;
            else if (c >= 97 && c <= 102) d = c - 87;
            else if (c >= 65 && c <= 70) d = c - 55;
            else revert("address hex");
            v = (v << 4) | d;
        }
        return address(v);
    }
}
