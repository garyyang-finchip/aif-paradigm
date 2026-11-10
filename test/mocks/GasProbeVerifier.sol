// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IAIFPPredicateVerifier} from "../../assets/erc-aifp/contracts/interfaces/IAIFPPredicateVerifier.sol";
import {AIFPOutcomes} from "../../assets/erc-aifp/contracts/libraries/AIFPOutcomes.sol";

/// @dev A well-formed leaf verifier whose answer would depend on the gas it is given if the caller let it.
///      Each mode gives a definite, correct answer when the leaf receives the full bound and a different
///      result when it is starved, which is what the composite verifier must never report as an outcome.
contract GasProbeVerifier is IAIFPPredicateVerifier {
    uint8 public constant MODE_THRESHOLD = 0; // SATISFIED iff the call was given at least `amount` gas, else NOT_SATISFIED
    uint8 public constant MODE_HEAVY = 1; // burns `amount` gas, then SATISFIED; runs out of gas when given less
    uint8 public constant MODE_INNER_CATCH = 2; // a sub-call burns `amount` gas inside try/catch: SATISFIED when it
        // completes, UNDETERMINABLE when it runs out of gas (the leaf survives and still answers)

    uint8 public mode;
    uint256 public amount;

    function set(uint8 mode_, uint256 amount_) external {
        mode = mode_;
        amount = amount_;
    }

    function verify(bytes32, bytes32, uint16, bytes32, uint8, bytes32, bytes calldata, bytes calldata)
        external
        view
        returns (uint8)
    {
        uint256 given = gasleft();
        uint8 mode_ = mode;
        uint256 amount_ = amount;
        if (mode_ == MODE_THRESHOLD) return given >= amount_ ? AIFPOutcomes.SATISFIED : AIFPOutcomes.NOT_SATISFIED;
        if (mode_ == MODE_HEAVY) {
            _burn(amount_);
            return AIFPOutcomes.SATISFIED;
        }
        try this.work(amount_) {
            return AIFPOutcomes.SATISFIED;
        } catch {
            return AIFPOutcomes.UNDETERMINABLE;
        }
    }

    function work(uint256 gasToBurn) external view {
        _burn(gasToBurn);
    }

    /// @dev Spends `gasToBurn` gas; when less is available the loop ends by running out of gas.
    function _burn(uint256 gasToBurn) internal view {
        uint256 start = gasleft();
        while (start - gasleft() < gasToBurn) {}
    }
}
