// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IAIFPPredicateVerifier} from "../../assets/erc-aifp/contracts/interfaces/IAIFPPredicateVerifier.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";

/// @dev A well-formed leaf verifier whose cost depends on what the transaction has already touched: it reads
///      `slots` storage slots (2,100 gas each when cold, 100 when warm) and then spends `work` gas. It shows the
///      one thing a fixed gas bound cannot make reproducible: whether a leaf close to the bound fits it.
contract ColdReaderVerifier is IAIFPPredicateVerifier {
    uint256 public slots;
    uint256 public work;
    mapping(uint256 => uint256) private _data;

    function set(uint256 slots_, uint256 work_) external {
        slots = slots_;
        work = work_;
    }

    /// @dev Reads the same slots as `verify` and nothing else: what an earlier call of the same transaction,
    ///      or an access list, does to them.
    function touch() external view returns (uint256 acc) {
        uint256 n = slots;
        for (uint256 i = 0; i < n; i++) {
            acc += _data[i];
        }
    }

    function verify(bytes32, bytes32, uint16, bytes32, uint8, bytes32, bytes calldata, bytes calldata)
        external
        view
        returns (uint8)
    {
        uint256 n = slots;
        uint256 acc;
        for (uint256 i = 0; i < n; i++) {
            acc += _data[i];
        }
        uint256 start = gasleft();
        uint256 work_ = work;
        while (start - gasleft() < work_) {}
        return acc == 0 ? AIFPOutcomes.SATISFIED : AIFPOutcomes.NOT_SATISFIED;
    }
}
