// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @dev Minimal cheatcode surface so that the suite needs no submodules: `forge test` works from a fresh
///      clone with nothing else installed. Only the cheatcodes used by this repository are declared.
interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory logs);
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newHeight) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function deal(address account, uint256 newBalance) external;
    function label(address account, string calldata newLabel) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function readFile(string calldata path) external view returns (string memory data);
    function parseJsonString(string calldata json, string calldata key) external pure returns (string memory);
    function parseJsonBytes32(string calldata json, string calldata key) external pure returns (bytes32);
    function parseJsonUint(string calldata json, string calldata key) external pure returns (uint256);
    function parseJsonBytes(string calldata json, string calldata key) external pure returns (bytes memory);
    function parseJsonStringArray(string calldata json, string calldata key) external pure returns (string[] memory);
    function parseJsonBytes32Array(string calldata json, string calldata key) external pure returns (bytes32[] memory);
    function parseJsonUintArray(string calldata json, string calldata key) external pure returns (uint256[] memory);
    function keyExists(string calldata json, string calldata key) external view returns (bool);
    function keyExistsJson(string calldata json, string calldata key) external view returns (bool);
    function toString(uint256 value) external pure returns (string memory);
    function toString(bytes32 value) external pure returns (string memory);
    function toString(address value) external pure returns (string memory);
    function toString(bytes calldata value) external pure returns (string memory);
    function envOr(string calldata name, uint256 defaultValue) external view returns (uint256);
    function envOr(string calldata name, address defaultValue) external view returns (address);
    function envOr(string calldata name, string calldata defaultValue) external view returns (string memory);
    function envOr(string calldata name, bool defaultValue) external view returns (bool);
    function envOr(string calldata name, bytes32 defaultValue) external view returns (bytes32);
    function envUint(string calldata name) external view returns (uint256);
    function envAddress(string calldata name) external view returns (address);
    function envString(string calldata name) external view returns (string memory);
    function startBroadcast(uint256 privateKey) external;
    function startBroadcast() external;
    function stopBroadcast() external;
    function writeFile(string calldata path, string calldata data) external;
    function writeJson(string calldata json, string calldata path) external;
    function serializeString(string calldata objectKey, string calldata valueKey, string calldata value) external returns (string memory);
    function serializeBytes32(string calldata objectKey, string calldata valueKey, bytes32 value) external returns (string memory);
    function serializeAddress(string calldata objectKey, string calldata valueKey, address value) external returns (string memory);
    function serializeUint(string calldata objectKey, string calldata valueKey, uint256 value) external returns (string memory);
    function addr(uint256 privateKey) external pure returns (address);
    function getNonce(address account) external view returns (uint64);
    function assertTrue(bool condition) external pure;
    function assertTrue(bool condition, string calldata err) external pure;
    function assertFalse(bool condition) external pure;
    function assertFalse(bool condition, string calldata err) external pure;
    function assertEq(bool left, bool right) external pure;
    function assertEq(uint256 left, uint256 right) external pure;
    function assertEq(uint256 left, uint256 right, string calldata err) external pure;
    function assertEq(int256 left, int256 right) external pure;
    function assertEq(address left, address right) external pure;
    function assertEq(bytes32 left, bytes32 right) external pure;
    function assertEq(bytes32 left, bytes32 right, string calldata err) external pure;
    function assertEq(string calldata left, string calldata right) external pure;
    function assertEq(string calldata left, string calldata right, string calldata err) external pure;
    function assertEq(bytes calldata left, bytes calldata right) external pure;
    function assertNotEq(bytes32 left, bytes32 right) external pure;
    function assertNotEq(uint256 left, uint256 right) external pure;
    function assertGt(uint256 left, uint256 right) external pure;
    function assertGe(uint256 left, uint256 right) external pure;
    function assertLt(uint256 left, uint256 right) external pure;
}

abstract contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        vm.assertEq(a, b);
    }

    function assertEq(uint256 a, uint256 b, string memory err) internal pure {
        vm.assertEq(a, b, err);
    }

    function assertEq(bytes32 a, bytes32 b) internal pure {
        vm.assertEq(a, b);
    }

    function assertEq(bytes32 a, bytes32 b, string memory err) internal pure {
        vm.assertEq(a, b, err);
    }

    function assertEq(address a, address b) internal pure {
        vm.assertEq(a, b);
    }

    function assertEq(bool a, bool b) internal pure {
        vm.assertEq(a, b);
    }

    function assertEq(string memory a, string memory b) internal pure {
        vm.assertEq(a, b);
    }

    function assertEq(bytes memory a, bytes memory b) internal pure {
        vm.assertEq(a, b);
    }

    function assertTrue(bool c) internal pure {
        vm.assertTrue(c);
    }

    function assertTrue(bool c, string memory err) internal pure {
        vm.assertTrue(c, err);
    }

    function assertFalse(bool c) internal pure {
        vm.assertFalse(c);
    }

    function assertFalse(bool c, string memory err) internal pure {
        vm.assertFalse(c, err);
    }

    function assertNotEq(bytes32 a, bytes32 b) internal pure {
        vm.assertNotEq(a, b);
    }

    /// @dev Outcome assertion with readable failure text.
    function assertOutcome(uint8 actual, uint8 expected, string memory where) internal pure {
        vm.assertEq(uint256(actual), uint256(expected), where);
    }
}
