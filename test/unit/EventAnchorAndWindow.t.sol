// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {AIFPEventAnchor} from "../../assets/erc-aifp/contracts/AIFPEventAnchor.sol";

contract EventAnchorTest is Fixture {
    bytes32 P1;
    bytes32 ch;

    function setUp() public override {
        super.setUp();
        P1 = simpleParadigm(A, "fam", "aifp:paradigm/blackboard/v1", AIFPRoles.SUBMIT, openPredicate());
        ch = openChannel(A, P1);
        grantRoles(A, ch, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.MODIFY | AIFPRoles.REDISTRIBUTE, 0);
        grantRoles(A, ch, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0);
    }

    function rel(uint8 kind, bytes32 ref) internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](1);
        r[0] = IAIFPEventAnchor.Relation({kind: kind, objectRef: ref});
    }

    function none() internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](0);
    }

    function test_publish_records_subject_rule_version_and_time() public {
        warpBy(7);
        vm.prank(A);
        uint256 idx = anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj1"), none());
        IAIFPEventAnchor.EventRecord memory r = anchor.record(idx);
        assertEq(r.channelId, ch);
        assertEq(r.subject, subj(A));
        assertEq(uint256(r.action), uint256(AIFPEvents.ACTION_PUBLISH));
        assertEq(r.objectRef, bytes32("obj1"));
        assertEq(r.ruleVersion, P1);
        assertEq(uint256(r.at), uint256(T0 + 7));
        assertEq(anchor.anchoredBy(bytes32("obj1")), subj(A));
        assertEq(anchor.anchoredIn(bytes32("obj1")), ch);
        assertEq(anchor.recordCount(), 1);
    }

    function test_role_checks_per_action() public {
        // O holds nothing
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(O), uint16(AIFPRoles.SUBMIT)));
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("x"), none());
        // B lacks MODIFY and REDISTRIBUTE
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.MODIFY)));
        anchor.anchor(ch, AIFPEvents.ACTION_MODIFY, bytes32("x"), none());
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("src"), none());
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_RoleNotHeld.selector, ch, subj(B), uint16(AIFPRoles.REDISTRIBUTE)));
        anchor.anchor(ch, AIFPEvents.ACTION_FORWARD, bytes32("src"), rel(AIFPEvents.REL_FORWARDS, bytes32("src")));
        // B can respond
        vm.prank(B);
        anchor.anchor(ch, AIFPEvents.ACTION_RESPOND, bytes32("reply"), rel(AIFPEvents.REL_REPLY_TO, bytes32("src")));
        // invalid action
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_InvalidAction.selector, uint8(9)));
        anchor.anchor(ch, 9, bytes32("y"), none());
    }

    function test_duplicate_object_reverts() public {
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj"), none());
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_ObjectAlreadyAnchored.selector, bytes32("obj")));
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj"), none());
    }

    function test_forward_keeps_reference_and_requires_relation() public {
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj"), none());
        // forwarding an unknown object
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_NotAnchoredBySubject.selector, bytes32("ghost"), bytes32(0)));
        anchor.anchor(ch, AIFPEvents.ACTION_FORWARD, bytes32("ghost"), rel(AIFPEvents.REL_FORWARDS, bytes32("ghost")));
        // forwarding without the forwards relation
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_MissingRelation.selector, AIFPEvents.ACTION_FORWARD, AIFPEvents.REL_FORWARDS));
        anchor.anchor(ch, AIFPEvents.ACTION_FORWARD, bytes32("obj"), none());
        // a forward into another channel keeps the object reference and the original anchoring subject
        bytes32 ch2 = openChannel(B, P1);
        grantRoles(B, ch2, A, AIFPRoles.REDISTRIBUTE, 0);
        vm.prank(A);
        uint256 idx = anchor.anchor(ch2, AIFPEvents.ACTION_FORWARD, bytes32("obj"), rel(AIFPEvents.REL_FORWARDS, bytes32("obj")));
        assertEq(anchor.record(idx).objectRef, bytes32("obj"));
        assertEq(anchor.anchoredBy(bytes32("obj")), subj(A));
        assertEq(anchor.anchoredIn(bytes32("obj")), ch, "origin unchanged");
    }

    function test_derive_and_synthesize_require_relations() public {
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj"), none());
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_MissingRelation.selector, AIFPEvents.ACTION_DERIVE, AIFPEvents.REL_DERIVES_FROM));
        anchor.anchor(ch, AIFPEvents.ACTION_DERIVE, bytes32("summary"), none());
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_DERIVE, bytes32("summary"), rel(AIFPEvents.REL_DERIVES_FROM, bytes32("obj")));
        assertEq(anchor.anchoredBy(bytes32("summary")), subj(A), "the deriver owns the derived object");
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_MissingRelation.selector, AIFPEvents.ACTION_SYNTHESIZE, AIFPEvents.REL_SYNTHESIZES));
        anchor.anchor(ch, AIFPEvents.ACTION_SYNTHESIZE, bytes32("digest"), rel(AIFPEvents.REL_REFERENCES, bytes32("obj")));
    }

    function test_supersede_and_retract_only_by_original_subject() public {
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("v1"), none());
        // B may not supersede A's object
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_NotAnchoredBySubject.selector, bytes32("v1"), subj(B)));
        anchor.anchor(ch, AIFPEvents.ACTION_SUPERSEDE, bytes32("v2"), rel(AIFPEvents.REL_SUPERSEDES, bytes32("v1")));
        // missing relation
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_MissingRelation.selector, AIFPEvents.ACTION_SUPERSEDE, AIFPEvents.REL_SUPERSEDES));
        anchor.anchor(ch, AIFPEvents.ACTION_SUPERSEDE, bytes32("v2"), none());
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_SUPERSEDE, bytes32("v2"), rel(AIFPEvents.REL_SUPERSEDES, bytes32("v1")));
        // the old object stays anchored (history is marked, not erased)
        assertEq(anchor.anchoredBy(bytes32("v1")), subj(A));
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPEventAnchor.AIFP_NotAnchoredBySubject.selector, bytes32("v2"), subj(B)));
        anchor.anchor(ch, AIFPEvents.ACTION_RETRACT, bytes32("r"), rel(AIFPEvents.REL_RETRACTS, bytes32("v2")));
        vm.prank(A);
        anchor.anchor(ch, AIFPEvents.ACTION_RETRACT, bytes32("r"), rel(AIFPEvents.REL_RETRACTS, bytes32("v2")));
        assertEq(anchor.recordCount(), 3);
    }

    function test_invalid_relation_kind_reverts() public {
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(AIFPEventAnchor.AIFP_InvalidRelation.selector, uint8(9)));
        anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("obj"), rel(9, bytes32("x")));
    }

    function test_rule_version_follows_adoption() public {
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/blackboard/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48() + 10, false, 0);
        vm.prank(A);
        uint256 i1 = anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("o1"), none());
        warpBy(10);
        vm.prank(A);
        uint256 i2 = anchor.anchor(ch, AIFPEvents.ACTION_PUBLISH, bytes32("o2"), none());
        assertEq(anchor.record(i1).ruleVersion, P1);
        assertEq(anchor.record(i2).ruleVersion, P2);
        assertTrue(anchor.supportsInterface(type(IAIFPEventAnchor).interfaceId));
    }
}

contract ObjectionWindowTest is Fixture {
    AIFPObjectionWindow win;
    bytes32 P1;
    bytes32 ch;

    function setUp() public override {
        super.setUp();
        win = new AIFPObjectionWindow(channels, participation);
        P1 = simpleParadigm(A, "fam", "aifp:paradigm/club/v1", AIFPRoles.SUBMIT, openPredicate());
        ch = openChannel(A, P1);
        grantRoles(A, ch, A, AIFPRoles.SUBMIT, 0);
        grantRoles(A, ch, B, AIFPRoles.RESPOND, 0);
        grantRoles(A, ch, C, AIFPRoles.RESPOND, 0);
    }

    function openWindow() internal returns (uint256) {
        vm.prank(A);
        return win.open(ch, bytes32("proposal"), now48() + 10, now48() + 110, AIFPRoles.RESPOND);
    }

    function test_open_requires_submit_and_valid_bounds() public {
        vm.prank(B);
        vm.expectRevert(AIFPObjectionWindow.RoleNotHeld.selector);
        win.open(ch, bytes32("p"), now48() + 10, now48() + 20, AIFPRoles.RESPOND);
        vm.prank(A);
        vm.expectRevert(AIFPObjectionWindow.InvalidWindow.selector);
        win.open(ch, bytes32("p"), now48() - 1, now48() + 20, AIFPRoles.RESPOND);
        vm.prank(A);
        vm.expectRevert(AIFPObjectionWindow.InvalidWindow.selector);
        win.open(ch, bytes32("p"), now48() + 20, now48() + 20, AIFPRoles.RESPOND);
        uint256 id = openWindow();
        AIFPObjectionWindow.Window memory w = win.window(id);
        assertEq(w.proposer, subj(A));
        assertEq(uint256(w.status), uint256(win.STATUS_OPEN()));
        assertEq(win.windowCount(), 1);
    }

    function test_object_requires_role_and_window() public {
        uint256 id = openWindow();
        // before start
        vm.prank(B);
        vm.expectRevert(AIFPObjectionWindow.OutsideWindow.selector);
        win.object(id, bytes32("too early"));
        warpBy(10);
        // outsider / wrong role
        vm.prank(O);
        vm.expectRevert(AIFPObjectionWindow.RoleNotHeld.selector);
        win.object(id, bytes32("x"));
        vm.prank(B);
        win.object(id, bytes32("disagree"));
        vm.prank(B);
        vm.expectRevert(AIFPObjectionWindow.AlreadyObjected.selector);
        win.object(id, bytes32("again"));
        assertTrue(win.objected(id, subj(B)));
        warpBy(100); // at deadline
        vm.prank(C);
        vm.expectRevert(AIFPObjectionWindow.OutsideWindow.selector);
        win.object(id, bytes32("late"));
    }

    function test_resolve_default_triggered_after_complete_silent_window() public {
        uint256 id = openWindow();
        vm.expectRevert(AIFPObjectionWindow.NotYetDue.selector);
        win.resolve(id);
        warpBy(110);
        uint8 status = win.resolve(id);
        assertEq(uint256(status), uint256(win.STATUS_DEFAULT_TRIGGERED()));
        vm.expectRevert(AIFPObjectionWindow.NotOpen.selector);
        win.resolve(id);
        vm.prank(B);
        vm.expectRevert(AIFPObjectionWindow.NotOpen.selector);
        win.object(id, bytes32("late"));
    }

    function test_resolve_objected() public {
        uint256 id = openWindow();
        warpBy(50);
        vm.prank(C);
        win.object(id, bytes32("no"));
        warpBy(60);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_OBJECTED()));
        assertEq(uint256(win.window(id).objections), 1);
    }

    function test_resolve_undeterminable_when_integrity_broken() public {
        uint256 id = openWindow();
        warpBy(20);
        // cannot report while the channel is active
        vm.expectRevert(AIFPObjectionWindow.InvalidWindow.selector);
        win.reportIntegrityBreak(id);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        win.reportIntegrityBreak(id);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        warpBy(100);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_UNDETERMINABLE()));
    }

    function test_resolve_undeterminable_when_channel_not_active_at_resolution() public {
        uint256 id = openWindow();
        warpBy(110);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_UNDETERMINABLE()));
    }
}
