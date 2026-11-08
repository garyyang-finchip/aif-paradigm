// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @dev Minimal cheatcode surface for the deployment and evidence scripts; no forge-std, no submodules.
interface ScriptVm {
    function startBroadcast() external;
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function addr(uint256 privateKey) external pure returns (address);
    function envUint(string calldata name) external view returns (uint256);
    function envAddress(string calldata name) external view returns (address);
    function envString(string calldata name) external view returns (string memory);
    function envOr(string calldata name, uint256 defaultValue) external view returns (uint256);
    function envOr(string calldata name, string calldata defaultValue) external view returns (string memory);
    function envOr(string calldata name, bool defaultValue) external view returns (bool);
    function envOr(string calldata name, address defaultValue) external view returns (address);
    function readFile(string calldata path) external view returns (string memory);
    function writeFile(string calldata path, string calldata data) external;
    function writeJson(string calldata json, string calldata path) external;
    function exists(string calldata path) external returns (bool);
    function parseJsonAddress(string calldata json, string calldata key) external pure returns (address);
    function parseJsonBytes32(string calldata json, string calldata key) external pure returns (bytes32);
    function parseJsonUint(string calldata json, string calldata key) external pure returns (uint256);
    function keyExistsJson(string calldata json, string calldata key) external view returns (bool);
    function serializeString(string calldata objectKey, string calldata valueKey, string calldata value) external returns (string memory);
    function serializeBytes32(string calldata objectKey, string calldata valueKey, bytes32 value) external returns (string memory);
    function serializeAddress(string calldata objectKey, string calldata valueKey, address value) external returns (string memory);
    function serializeUint(string calldata objectKey, string calldata valueKey, uint256 value) external returns (string memory);
    function serializeBool(string calldata objectKey, string calldata valueKey, bool value) external returns (string memory);
    function toString(uint256 value) external pure returns (string memory);
    function toString(address value) external pure returns (string memory);
    function toString(bytes32 value) external pure returns (string memory);
}

abstract contract ScriptBase {
    ScriptVm internal constant vm = ScriptVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function deploymentsPath() internal view returns (string memory) {
        return string(abi.encodePacked("deployments/", vm.toString(block.chainid), ".json"));
    }

    function casesPath() internal view returns (string memory) {
        return string(abi.encodePacked("deployments/", vm.toString(block.chainid), ".cases.json"));
    }

    /// @dev Broadcast as the key in `envName`; with no such variable, use the key given on the command line.
    function broadcastAs(string memory envName) internal returns (address sender) {
        uint256 pk = vm.envOr(envName, uint256(0));
        if (pk == 0) {
            vm.startBroadcast();
            return address(0);
        }
        vm.startBroadcast(pk);
        return vm.addr(pk);
    }
}
