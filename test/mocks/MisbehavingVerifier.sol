// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @dev A leaf that answers any call (`verify`, `contains`, ...) with raw return data chosen by the test:
///      nothing, a word of any value, a short or a long buffer, or an endless loop that exhausts the gas it
///      was given. It models verifiers whose return data does not decode as the declared type, which a
///      typed `try ... returns (uint8)` cannot catch because the decoding happens in the caller.
contract MisbehavingVerifier {
    uint8 public constant MODE_EMPTY = 0; // returns no data
    uint8 public constant MODE_WORD = 1; // returns one 32-byte word with value `word`
    uint8 public constant MODE_SHORT = 2; // returns 16 bytes
    uint8 public constant MODE_LONG = 3; // returns two words: `word` then 1
    uint8 public constant MODE_BURN = 4; // loops until out of gas

    uint8 public mode;
    uint256 public word;
    uint256 public callsSeen; // not written during the (static) calls; kept for symmetry with MockVerifier

    function set(uint8 mode_, uint256 word_) external {
        mode = mode_;
        word = word_;
    }

    fallback() external {
        uint256 m = mode;
        uint256 w = word;
        assembly {
            switch m
            case 0 { return(0, 0) }
            case 1 {
                mstore(0, w)
                return(0, 32)
            }
            case 2 {
                mstore(0, w)
                return(0, 16)
            }
            case 3 {
                mstore(0, w)
                mstore(32, 1)
                return(0, 64)
            }
            default {
                // MODE_BURN: hash forever; the call ends only when its gas is exhausted.
                for {} 1 {} { mstore(0, keccak256(0, 32)) }
            }
        }
    }
}
