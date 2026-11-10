// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 3 - an announcement channel that both pushes and offers archive pull.
/// Must show: Source, Archive and push/pull compose on one channel; the Source label is a registered
/// declaration that does not change when delivery changes; readers are open, the publisher is single.
contract Case03_SourceArchive is CaseBase {
    bytes32 P_SRC;
    bytes32 ann;

    function setUp() public override {
        super.setUp();
        bytes32[] memory labels = new bytes32[](2);
        labels[0] = label("source");
        labels[1] = label("archive");
        P_SRC = registerParadigm(A, "{source+archive}", keccak256("announce"), 0, labels, onePred(AIFPRoles.OBSERVE, openPredicate()));
        // Push binding (stream) and archive binding (pull + retained history) on the same channel.
        IAIFPChannelRegistry.BindingDecl[] memory decls = new IAIFPChannelRegistry.BindingDecl[](2);
        decls[0] = transportBinding(AIFPBindings.CAP_RULE_ASSOCIATION | AIFPBindings.CAP_PUSH | AIFPBindings.CAP_STREAM, bytes32("a2a:stream"));
        decls[1] = transportBinding(
            AIFPBindings.CAP_RULE_ASSOCIATION | AIFPBindings.CAP_PULL | AIFPBindings.CAP_HISTORY_RETENTION | AIFPBindings.CAP_LATE_JOIN_HISTORY,
            bytes32("mcp:resource")
        );
        vm.prank(A);
        ann = channels.openChannel(P_SRC, A, bytes32(0), "announcements", decls);
        grantRoles(A, ann, A, AIFPRoles.SUBMIT, 0);
    }

    function test_push_and_pull_bindings_coexist_under_one_paradigm() public view {
        bytes32[] memory ids = channels.bindingIds(ann);
        assertEq(ids.length, 2);
        IAIFPChannelRegistry.BindingDecl memory push = channels.binding(ann, ids[0]);
        IAIFPChannelRegistry.BindingDecl memory pull = channels.binding(ann, ids[1]);
        assertTrue(push.capabilities & AIFPBindings.CAP_PUSH != 0);
        assertTrue(pull.capabilities & AIFPBindings.CAP_PULL != 0);
        assertTrue(pull.capabilities & AIFPBindings.CAP_LATE_JOIN_HISTORY != 0);
        assertTrue(paradigms.hasLabel(P_SRC, label("source")));
        assertTrue(paradigms.hasLabel(P_SRC, label("archive")));
    }

    function test_single_publisher_open_readers() public {
        // Readers self-admit (open predicate); nobody but A can publish.
        admitAs(B, ann, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        admitAs(C, ann, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        assertOutcome(evalNow(ann, B, AIFPRoles.OBSERVE, 0), S, "B reads");
        assertOutcome(evalNow(ann, C, AIFPRoles.OBSERVE, 0), S, "C reads");
        assertOutcome(evalNow(ann, B, AIFPRoles.SUBMIT, 0), N, "B cannot publish");
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NoPredicateForRole.selector, P_SRC, uint16(AIFPRoles.SUBMIT)));
        participation.admit(ann, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        anchorAs(A, ann, AIFPEvents.ACTION_PUBLISH, bytes32("bulletin-1"), noRel());
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ann, subj(B), uint16(AIFPRoles.SUBMIT), AIFPOutcomes.NOT_SATISFIED));
        anchor.anchor(ann, AIFPEvents.ACTION_PUBLISH, bytes32("bulletin-2"), noRel());
    }

    function test_label_is_declaration_not_delivery() public {
        // Switching from push to pull-only is a binding change, not a paradigm change: the Source label stays.
        bytes32[] memory ids = channels.bindingIds(ann);
        vm.prank(A);
        channels.revokeBinding(ann, ids[0]);
        assertFalse(channels.binding(ann, ids[0]).active);
        (bytes32 cur,) = channels.currentParadigm(ann);
        assertEq(cur, P_SRC);
        assertTrue(paradigms.hasLabel(P_SRC, label("source")));
        // Late joiners see the retained archive through the pull binding; on-chain nothing else changes.
        assertTrue(channels.binding(ann, ids[1]).active);
        assertEq(channels.adoptionCount(ann), 1);
    }
}
