// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";
import {AIFPPredicates} from "../../assets/erc-aifp/contracts/libraries/AIFPPredicates.sol";
import {AIFPSubject} from "../../assets/erc-aifp/contracts/libraries/AIFPSubject.sol";
import {AIFPRoles} from "../../assets/erc-aifp/contracts/libraries/AIFPRoles.sol";
import {IAIFPChannelRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPChannelRegistry.sol";
import {IAIFPParticipationRegistry} from "../../assets/erc-aifp/contracts/interfaces/IAIFPParticipationRegistry.sol";

/// @dev Exposes internal library functions to the tests.
contract OutcomesHarness {
    function allOf(uint8[] memory o) external pure returns (uint8) {
        return AIFPOutcomes.allOf(o);
    }

    function anyOf(uint8[] memory o) external pure returns (uint8) {
        return AIFPOutcomes.anyOf(o);
    }

    function normalize(uint8 o) external pure returns (uint8) {
        return AIFPOutcomes.normalize(o);
    }
}

contract PredicatesHarness {
    function isWellFormed(bytes memory predicate) external pure returns (bool) {
        return AIFPPredicates.isWellFormed(AIFPPredicates.decode(predicate));
    }

    function hashOf(bytes memory predicate) external pure returns (bytes32) {
        return AIFPPredicates.hashOf(AIFPPredicates.decode(predicate));
    }
}

contract SubjectHarness {
    function toDecimal(uint256 v) external pure returns (string memory) {
        return AIFPSubject.toDecimal(v);
    }

    function toHexAddress(address a) external pure returns (string memory) {
        return AIFPSubject.toHexAddress(a);
    }

    function canonicalAddress(uint256 chainId, address a) external pure returns (string memory) {
        return AIFPSubject.canonicalAddress(chainId, a);
    }

    function fromAddress(uint256 chainId, address a) external pure returns (bytes32) {
        return AIFPSubject.fromAddress(chainId, a);
    }

    function self(address a) external view returns (bytes32) {
        return AIFPSubject.self(a);
    }

    function canonicalERC8004(uint256 chainId, address registry, uint256 agentId) external pure returns (string memory) {
        return AIFPSubject.canonicalERC8004(chainId, registry, agentId);
    }

    function fromERC8004(uint256 chainId, address registry, uint256 agentId) external pure returns (bytes32) {
        return AIFPSubject.fromERC8004(chainId, registry, agentId);
    }

    function fromDID(string memory method, string memory id) external pure returns (bytes32) {
        return AIFPSubject.fromDID(method, id);
    }

    function canonicalDID(string memory method, string memory id) external pure returns (string memory) {
        return AIFPSubject.canonicalDID(method, id);
    }

    function fromExt(string memory ns, string memory id) external pure returns (bytes32) {
        return AIFPSubject.fromExt(ns, id);
    }

    function fromCanonical(string memory s) external pure returns (bytes32) {
        return AIFPSubject.fromCanonical(s);
    }
}

contract RolesHarness {
    function isSingle(uint16 r) external pure returns (bool) {
        return AIFPRoles.isSingle(r);
    }

    function isDefined(uint16 r) external pure returns (bool) {
        return AIFPRoles.isDefined(r);
    }
}

/// @dev A governance executor: a contract that acts on a channel as the target of a governance binding.
contract MockExecutor {
    IAIFPChannelRegistry public immutable channels;
    IAIFPParticipationRegistry public immutable participation;

    constructor(IAIFPChannelRegistry channels_, IAIFPParticipationRegistry participation_) {
        channels = channels_;
        participation = participation_;
    }

    function adopt(bytes32 channelId, bytes32 paradigmId, uint48 effectiveAt, bool readmission, bytes32 authRef) external {
        channels.adoptParadigm(channelId, paradigmId, effectiveAt, readmission, authRef);
    }

    function grant(bytes32 channelId, bytes32 subject, uint16 roles, bytes32 scopeRef) external returns (bytes32) {
        return participation.grant(channelId, subject, bytes32(0), roles, scopeRef, 3, bytes32("decision"), 0, 0);
    }

    function suspend(bytes32 bindingId) external {
        participation.suspend(bindingId, bytes32("intervention"));
    }

    function reinstate(bytes32 bindingId) external {
        participation.reinstate(bindingId);
    }

    function disclose(bytes32 channelId, uint8 kind, bytes32 objectRef, bytes32 audienceRef) external {
        channels.recordDisclosure(channelId, kind, objectRef, audienceRef, bytes32("ruling"));
    }
}
