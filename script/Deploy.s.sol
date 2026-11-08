// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ScriptBase} from "./ScriptBase.sol";
import {AIFPParadigmRegistry} from "../assets/erc-aifp/contracts/AIFPParadigmRegistry.sol";
import {AIFPChannelRegistry} from "../assets/erc-aifp/contracts/AIFPChannelRegistry.sol";
import {AIFPParticipationRegistry} from "../assets/erc-aifp/contracts/AIFPParticipationRegistry.sol";
import {AIFPCompositeVerifier} from "../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";
import {AIFPSubjectSet} from "../assets/erc-aifp/contracts/AIFPSubjectSet.sol";
import {AIFPEventAnchor} from "../assets/erc-aifp/contracts/AIFPEventAnchor.sol";
import {AIFPObjectionWindow} from "../assets/erc-aifp/contracts/companions/AIFPObjectionWindow.sol";

/// @notice Deploys the reference stack and writes the addresses to deployments/<chainid>.json.
///
///   AIFP_PK_A=<hex key> forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
///   (or omit AIFP_PK_A and pass --private-key; the deployer becomes the channel authority "A")
contract Deploy is ScriptBase {
    function run() external {
        address deployer = broadcastAs("AIFP_PK_A");
        AIFPParadigmRegistry paradigms = new AIFPParadigmRegistry();
        AIFPCompositeVerifier verifier = new AIFPCompositeVerifier();
        AIFPChannelRegistry channels = new AIFPChannelRegistry(paradigms);
        AIFPParticipationRegistry participation = new AIFPParticipationRegistry(channels, paradigms, verifier);
        channels.setParticipationRegistry(participation);
        AIFPEventAnchor anchor = new AIFPEventAnchor(channels, participation);
        AIFPObjectionWindow window = new AIFPObjectionWindow(channels, participation);
        AIFPSubjectSet roster = new AIFPSubjectSet(deployer == address(0) ? msg.sender : deployer);
        vm.stopBroadcast();

        string memory o = "deployment";
        vm.serializeUint(o, "chainId", block.chainid);
        vm.serializeString(o, "clockMode", channels.CLOCK_MODE());
        vm.serializeAddress(o, "AIFPParadigmRegistry", address(paradigms));
        vm.serializeAddress(o, "AIFPCompositeVerifier", address(verifier));
        vm.serializeAddress(o, "AIFPChannelRegistry", address(channels));
        vm.serializeAddress(o, "AIFPParticipationRegistry", address(participation));
        vm.serializeAddress(o, "AIFPEventAnchor", address(anchor));
        vm.serializeAddress(o, "AIFPObjectionWindow", address(window));
        vm.serializeAddress(o, "AIFPSubjectSet", address(roster));
        string memory json = vm.serializeUint(o, "deployedAt", block.timestamp);
        vm.writeJson(json, deploymentsPath());
    }
}
