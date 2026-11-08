// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IAIFPPredicateVerifier} from "../../assets/erc-aifp/contracts/interfaces/IAIFPPredicateVerifier.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";

/// @dev Configurable leaf verifier used by the unit tests and the boundary cases.
contract MockVerifier is IAIFPPredicateVerifier {
    uint8 public constant MODE_FIXED = 0; // always returns `fixedOutcome`
    uint8 public constant MODE_MATCH_EVIDENCE = 1; // SATISFIED iff keccak(evidence) == expectedEvidence; empty evidence -> UNDETERMINABLE; else NOT_SATISFIED
    uint8 public constant MODE_REVERT = 2; // always reverts
    uint8 public constant MODE_OUT_OF_RANGE = 3; // returns 7
    uint8 public constant MODE_ECHO_EVIDENCE = 4; // returns uint8(evidence[0]) (to test routing by node index)

    uint8 public mode;
    uint8 public fixedOutcome;
    bytes32 public expectedEvidence;
    uint256 public calls;
    uint8 public lastKind;
    bytes32 public lastRef;
    bytes public lastParams;

    constructor() {
        mode = MODE_FIXED;
        fixedOutcome = AIFPOutcomes.SATISFIED;
    }

    function setFixed(uint8 outcome) external {
        mode = MODE_FIXED;
        fixedOutcome = outcome;
    }

    function setMatchEvidence(bytes memory evidence) external {
        mode = MODE_MATCH_EVIDENCE;
        expectedEvidence = keccak256(evidence);
    }

    function setMode(uint8 mode_) external {
        mode = mode_;
    }

    function verify(
        bytes32,
        bytes32,
        uint16,
        bytes32,
        uint8 kind,
        bytes32 ref,
        bytes calldata params,
        bytes calldata evidence
    ) external view returns (uint8) {
        if (mode == MODE_REVERT) revert("MockVerifier: boom");
        if (mode == MODE_OUT_OF_RANGE) return 7;
        if (mode == MODE_ECHO_EVIDENCE) {
            if (evidence.length == 0) return AIFPOutcomes.UNDETERMINABLE;
            return uint8(evidence[0]);
        }
        if (mode == MODE_MATCH_EVIDENCE) {
            if (evidence.length == 0) return AIFPOutcomes.UNDETERMINABLE;
            return keccak256(evidence) == expectedEvidence ? AIFPOutcomes.SATISFIED : AIFPOutcomes.NOT_SATISFIED;
        }
        // silence unused warnings for the recording fields in view context
        kind;
        ref;
        params;
        return fixedOutcome;
    }
}

/// @dev Stake-style semantic verifier (kind 6): params = abi.encode(chainId, contract, asset, minAmount, period),
///      evidence = abi.encode(stakedAmount). SATISFIED iff staked >= minAmount; UNDETERMINABLE without evidence;
///      NOT_SATISFIED when the evidence is for another chain/contract (encoded as a second word).
contract MockStakeVerifier is IAIFPPredicateVerifier {
    function verify(
        bytes32,
        bytes32,
        uint16,
        bytes32,
        uint8 kind,
        bytes32,
        bytes calldata params,
        bytes calldata evidence
    ) external pure returns (uint8) {
        if (kind != 6) return AIFPOutcomes.UNDETERMINABLE;
        (uint256 chainId, address contract_,, uint256 minAmount,) = abi.decode(params, (uint256, address, address, uint256, uint8));
        if (evidence.length == 0) return AIFPOutcomes.UNDETERMINABLE;
        (uint256 staked, uint256 evChain, address evContract) = abi.decode(evidence, (uint256, uint256, address));
        if (evChain != chainId || evContract != contract_) return AIFPOutcomes.NOT_SATISFIED;
        return staked >= minAmount ? AIFPOutcomes.SATISFIED : AIFPOutcomes.NOT_SATISFIED;
    }
}
