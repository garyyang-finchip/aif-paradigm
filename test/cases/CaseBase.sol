// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MockVerifier, MockStakeVerifier} from "../mocks/MockVerifier.sol";

/// @dev Shared material for the twelve boundary cases (memo section 14, with the six corrections).
///      Actors: A (channel authority / FOGA cell A), B (FOGA cell B), C (third logical participant), O (outsider).
abstract contract CaseBase is Fixture {
    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    function label(string memory name) internal pure returns (bytes32) {
        return keccak256(bytes(string(abi.encodePacked("aifp:paradigm/", name, "/v1"))));
    }

    function labelString(string memory name) internal pure returns (string memory) {
        return string(abi.encodePacked("aifp:paradigm/", name, "/v1"));
    }

    function rel(uint8 kind, bytes32 ref) internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](1);
        r[0] = IAIFPEventAnchor.Relation({kind: kind, objectRef: ref});
    }

    function noRel() internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](0);
    }

    function anchorAs(address who, bytes32 channelId, uint8 action, bytes32 objectRef, IAIFPEventAnchor.Relation[] memory relations)
        internal
        returns (uint256)
    {
        vm.prank(who);
        return anchor.anchor(channelId, action, objectRef, relations);
    }

    /// @dev Counts RelationAnchored logs for `objectRef` with `kind` pointing at `relatedRef` in a recorded log set.
    function countRelation(Vm.Log[] memory logs, bytes32 objectRef, uint8 kind, bytes32 relatedRef) internal pure returns (uint256 n) {
        bytes32 topic0 = keccak256("RelationAnchored(bytes32,uint8,bytes32)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 3 && logs[i].topics[0] == topic0 && logs[i].topics[1] == objectRef && logs[i].topics[2] == relatedRef) {
                uint8 k = abi.decode(logs[i].data, (uint8));
                if (k == kind) n++;
            }
        }
    }
}
