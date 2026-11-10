// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 9 - a closed-door discussion produces an outside summary; one post is also forwarded verbatim.
/// Must show: a forward keeps the object reference and needs REDISTRIBUTE; a derivation is a new object
/// attributed to the deriver and pointing back to its source; disclosure to an outside audience is a
/// recorded, authorized declaration; a later restriction is appended and never deletes the earlier fact.
contract Case09_ForwardDeriveDisclose is CaseBase {
    bytes32 P_MEETING;
    bytes32 P_SOURCE;
    bytes32 room; // closed door, A and B
    bytes32 bulletin; // public outlet run by C
    bytes32 constant AUDIENCE_PUBLIC = keccak256("audience:public");

    function setUp() public override {
        super.setUp();
        P_MEETING = registerParadigm(A, "{meeting}", keccak256("closed"), 0, labels1(labelString("meeting")), noPreds());
        P_SOURCE = registerParadigm(C, "{bulletin}", keccak256("bulletin"), 0, labels1(labelString("source")), onePred(AIFPRoles.OBSERVE, openPredicate()));
        room = openChannel(A, P_MEETING);
        bulletin = openChannel(C, P_SOURCE);
        grantRoles(A, room, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE, 0);
        grantRoles(A, room, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE | AIFPRoles.REDISTRIBUTE | AIFPRoles.MANAGE_DISCLOSURE, 0);
        grantRoles(C, bulletin, C, AIFPRoles.SUBMIT, 0);
        grantRoles(C, bulletin, B, AIFPRoles.REDISTRIBUTE, 0); // C lets B bring material into the bulletin
    }

    function test_forward_keeps_reference_and_needs_redistribute() public {
        bytes32 post = keccak256("A: we should ship in Q1");
        anchorAs(A, room, AIFPEvents.ACTION_PUBLISH, post, noRel());
        // A holds no REDISTRIBUTE in the bulletin: the anchor checks the role in the channel named in the call,
        // the one that receives the record, so A cannot bring its own post there. (The anchor does not
        // consult the room, where the post was first anchored.)
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, bulletin, subj(A), uint16(AIFPRoles.REDISTRIBUTE), AIFPOutcomes.NOT_SATISFIED));
        anchor.anchor(bulletin, AIFPEvents.ACTION_FORWARD, post, rel(AIFPEvents.REL_FORWARDS, post));
        // B may: the forwarded object keeps its reference and its original author.
        uint256 idx = anchorAs(B, bulletin, AIFPEvents.ACTION_FORWARD, post, rel(AIFPEvents.REL_FORWARDS, post));
        assertEq(anchor.record(idx).objectRef, post);
        assertEq(anchor.record(idx).channelId, bulletin);
        assertEq(anchor.anchoredBy(post), subj(A), "author unchanged by forwarding");
        assertEq(anchor.anchoredIn(post), room, "origin unchanged by forwarding");
    }

    function test_derive_attributes_the_summary_to_the_deriver() public {
        bytes32 postA = keccak256("A: ship in Q1");
        bytes32 postB = keccak256("B: only if the audit is done");
        anchorAs(A, room, AIFPEvents.ACTION_PUBLISH, postA, noRel());
        anchorAs(B, room, AIFPEvents.ACTION_RESPOND, postB, rel(AIFPEvents.REL_REPLY_TO, postA));
        bytes32 summary = keccak256("Summary: Q1 target conditional on audit");
        IAIFPEventAnchor.Relation[] memory rels = new IAIFPEventAnchor.Relation[](2);
        rels[0] = IAIFPEventAnchor.Relation({kind: AIFPEvents.REL_DERIVES_FROM, objectRef: postA});
        rels[1] = IAIFPEventAnchor.Relation({kind: AIFPEvents.REL_DERIVES_FROM, objectRef: postB});
        vm.recordLogs();
        anchorAs(B, bulletin, AIFPEvents.ACTION_DERIVE, summary, rels);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(anchor.anchoredBy(summary), subj(B), "B is responsible for the summary");
        assertEq(anchor.anchoredBy(postA), subj(A), "A's signature covers A's post, not the summary");
        assertEq(countRelation(logs, summary, AIFPEvents.REL_DERIVES_FROM, postA), 1);
        assertEq(countRelation(logs, summary, AIFPEvents.REL_DERIVES_FROM, postB), 1);
    }

    function test_disclosure_is_recorded_and_restriction_appends() public {
        bytes32 summary = keccak256("summary");
        // Only the disclosure manager (B) or the authority may declare the summary disclosed to the public.
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, room, C));
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_DISCLOSED, summary, AUDIENCE_PUBLIC, bytes32("minutes-approved"));
        vm.prank(B);
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_DISCLOSED, summary, AUDIENCE_PUBLIC, bytes32("minutes-approved"));
        (uint8 k0, bytes32 o0, bytes32 a0, bytes32 r0, uint48 t0) = channels.disclosureAt(room, 0);
        assertEq(uint256(k0), uint256(AIFPBindings.DISCLOSURE_DISCLOSED));
        assertEq(o0, summary);
        assertEq(a0, AUDIENCE_PUBLIC);
        assertEq(r0, bytes32("minutes-approved"));
        assertEq(uint256(t0), uint256(now48()));
        // Later the room restricts future provision of the summary to the public: appended, not rewritten.
        warpBy(1 days);
        vm.prank(A);
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_RESTRICTED, summary, AUDIENCE_PUBLIC, bytes32("retracted-minutes"));
        assertEq(channels.disclosureCount(room), 2);
        (uint8 k0again, bytes32 o0again,,, uint48 t0again) = channels.disclosureAt(room, 0);
        assertEq(uint256(k0again), uint256(AIFPBindings.DISCLOSURE_DISCLOSED), "the earlier fact stands");
        assertEq(o0again, summary);
        assertEq(uint256(t0again), uint256(t0));
        (uint8 k1,,,, uint48 t1) = channels.disclosureAt(room, 1);
        assertEq(uint256(k1), uint256(AIFPBindings.DISCLOSURE_RESTRICTED));
        assertTrue(t1 > t0);
        // The restriction says nothing about copies already held: no record claims deletion.
        // Closing the room still allows recording what was once disclosed (history), nothing else.
        vm.prank(A);
        channels.setState(room, IAIFPChannelRegistry.ChannelState.Closed);
        vm.prank(A);
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_DISCLOSED, keccak256("other-minutes"), AUDIENCE_PUBLIC, 0);
        assertEq(channels.disclosureCount(room), 3);
    }
}
