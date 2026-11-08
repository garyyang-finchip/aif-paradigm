// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MockVerifier} from "../mocks/MockVerifier.sol";
import {AIFPCompositeVerifier} from "../../assets/erc-aifp/contracts/AIFPCompositeVerifier.sol";

contract CompositeVerifierTest is Fixture {
    MockVerifier mock;
    AIFPSubjectSet set;
    bytes32 constant CH = bytes32("channel");

    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    function setUp() public override {
        super.setUp();
        mock = new MockVerifier();
        set = new AIFPSubjectSet(A);
    }

    function ev(bytes memory p, bytes[] memory evidence) internal view returns (uint8) {
        return verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), p, evidence);
    }

    function test_open_is_satisfied() public view {
        assertOutcome(ev(openPredicate(), noEvidence()), S, "open");
    }

    function test_allowlist_hit_and_miss() public {
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), N, "miss");
        vm.prank(A);
        set.add(subj(B));
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), S, "hit");
        vm.prank(A);
        set.remove(subj(B));
        assertOutcome(ev(allowlistPredicate(address(set)), noEvidence()), N, "removed");
    }

    function test_allowlist_zero_verifier_is_undeterminable() public view {
        assertOutcome(ev(allowlistPredicate(address(0)), noEvidence()), U, "no set");
    }

    function test_allowlist_non_contract_is_verifier_error() public view {
        assertOutcome(ev(allowlistPredicate(address(0xdead)), noEvidence()), E, "not a contract");
    }

    function test_external_outcomes_pass_through() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32("ref"));
        mock.setFixed(S);
        assertOutcome(ev(p, noEvidence()), S, "S");
        mock.setFixed(N);
        assertOutcome(ev(p, noEvidence()), N, "N");
        mock.setFixed(U);
        assertOutcome(ev(p, noEvidence()), U, "U");
        mock.setFixed(E);
        assertOutcome(ev(p, noEvidence()), E, "E");
    }

    function test_external_revert_is_verifier_error() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0));
        mock.setMode(mock.MODE_REVERT());
        assertOutcome(ev(p, noEvidence()), E, "revert");
    }

    function test_external_out_of_range_is_verifier_error() public {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0));
        mock.setMode(mock.MODE_OUT_OF_RANGE());
        assertOutcome(ev(p, noEvidence()), E, "7 -> E");
    }

    function test_external_zero_verifier_is_undeterminable() public view {
        bytes memory p = externalPredicate(AIFPPredicates.EXTERNAL, address(0), bytes32(0));
        assertOutcome(ev(p, noEvidence()), U, "no verifier");
    }

    function test_semantic_kinds_are_delegated() public {
        mock.setFixed(S);
        for (uint8 kind = AIFPPredicates.CREDENTIAL; kind <= AIFPPredicates.DECISION; kind++) {
            assertOutcome(ev(externalPredicate(kind, address(mock), bytes32(0)), noEvidence()), S, "semantic kind delegated");
        }
    }

    function test_unsupported_kind_anywhere_is_undeterminable_before_composition() public {
        // anyOf(open, unsupported): without the unsupported leaf this would be SATISFIED.
        bytes memory p = anyOf2(openPredicate(), externalPredicate(10, address(mock), bytes32(0)));
        mock.setFixed(S);
        assertOutcome(ev(p, noEvidence()), U, "unsupported leaf blocks composition");
        assertFalse(verifier.supportsKind(10));
        assertTrue(verifier.supportsKind(9));
    }

    function test_evidence_routed_by_node_index() public {
        // allOf(external@1, external@2) with the echo verifier: node 1 reads evidence[1], node 2 reads evidence[2].
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        bytes memory p = allOf2(
            externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0)),
            externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32(0))
        );
        bytes[] memory evidence = new bytes[](3);
        evidence[0] = "";
        evidence[1] = abi.encodePacked(uint8(S));
        evidence[2] = abi.encodePacked(uint8(S));
        assertOutcome(ev(p, evidence), S, "both satisfied");
        evidence[2] = abi.encodePacked(uint8(N));
        assertOutcome(ev(p, evidence), N, "second leaf not satisfied");
        // missing evidence for node 2 -> the echo verifier answers UNDETERMINABLE
        bytes[] memory shortEv = new bytes[](2);
        shortEv[1] = abi.encodePacked(uint8(S));
        assertOutcome(ev(p, shortEv), U, "missing evidence");
    }

    function test_nested_precedence() public {
        // allOf(anyOf(N, S), E) -> anyOf = S, allOf(S, E) = E
        mock.setMode(mock.MODE_ECHO_EVIDENCE());
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](5);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: 1, childCount: 2, verifier: address(0), ref: 0, params: ""});
        nodes[1] = AIFPPredicates.Node({kind: AIFPPredicates.ANY_OF, childStart: 3, childCount: 2, verifier: address(0), ref: 0, params: ""});
        nodes[2] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        nodes[3] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        nodes[4] = AIFPPredicates.Node({kind: AIFPPredicates.EXTERNAL, childStart: 0, childCount: 0, verifier: address(mock), ref: 0, params: ""});
        bytes[] memory evidence = new bytes[](5);
        evidence[2] = abi.encodePacked(uint8(E));
        evidence[3] = abi.encodePacked(uint8(N));
        evidence[4] = abi.encodePacked(uint8(S));
        assertOutcome(ev(abi.encode(nodes), evidence), E, "allOf(anyOf(N,S)=S, E) = E");
        evidence[2] = abi.encodePacked(uint8(S));
        assertOutcome(ev(abi.encode(nodes), evidence), S, "allOf(S, S) = S");
        evidence[4] = abi.encodePacked(uint8(U));
        assertOutcome(ev(abi.encode(nodes), evidence), U, "allOf(anyOf(N,U)=U, S) = U");
    }

    function test_malformed_reverts() public {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALL_OF, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        vm.expectRevert(AIFPCompositeVerifier.AIFP_MalformedPredicate.selector);
        verifier.evaluate(CH, subj(B), AIFPRoles.SUBMIT, bytes32(0), abi.encode(nodes), noEvidence());
    }

    function test_supports_interface() public view {
        assertTrue(verifier.supportsInterface(type(IAIFPCompositeVerifier).interfaceId));
        assertTrue(verifier.supportsInterface(0x01ffc9a7));
        assertFalse(verifier.supportsInterface(0xffffffff));
    }
}
