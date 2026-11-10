// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./CaseBase.sol";

/// Case 11 - absence semantics: "no objection within the agreed window" triggers the agreed default.
/// Must show: the window is authoritative and agreed in advance (rule, role, deadline, default consequence);
/// a complete silent window yields DEFAULT_TRIGGERED, an objection yields OBJECTED, a window whose integrity
/// cannot be confirmed yields UNDETERMINABLE; and the resolution never implies that anyone read or consented.
contract Case11_ObjectionWindow is CaseBase {
    AIFPObjectionWindow win;
    bytes32 P_CLUB;
    bytes32 ch;
    bytes32 cResponder;
    uint48 start;
    uint48 deadline;

    function setUp() public override {
        super.setUp();
        win = new AIFPObjectionWindow(channels, participation);
        P_CLUB = registerParadigm(A, "{club:objection-window}", keccak256("council"), 0, labels1(labelString("club")), noPreds());
        ch = openChannel(A, P_CLUB);
        grantRoles(A, ch, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0);
        grantRoles(A, ch, B, AIFPRoles.RESPOND, 0);
        cResponder = grantRoles(A, ch, C, AIFPRoles.RESPOND, 0);
        start = now48() + 60;
        deadline = start + 7 days;
    }

    function openWindow() internal returns (uint256) {
        vm.prank(A);
        return win.open(ch, keccak256("proposal: rotate the sequencer"), start, deadline, AIFPRoles.RESPOND);
    }

    function test_default_triggered_after_complete_silent_window() public {
        uint256 id = openWindow();
        vm.warp(deadline - 1);
        vm.expectRevert(AIFPObjectionWindow.NotYetDue.selector);
        win.resolve(id);
        vm.warp(deadline);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_DEFAULT_TRIGGERED()));
        AIFPObjectionWindow.Window memory w = win.window(id);
        assertEq(uint256(w.objections), 0);
        assertTrue(w.openedAt <= w.start, "the window was open before it started");
    }

    function test_objection_inside_window_blocks_the_default() public {
        uint256 id = openWindow();
        vm.warp(start + 1 days);
        vm.prank(C);
        win.object(id, keccak256("the candidate failed the audit"));
        vm.warp(deadline);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_OBJECTED()));
    }

    function test_frozen_channel_breaks_window_integrity() public {
        uint256 id = openWindow();
        vm.warp(start + 1 days);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        // Nobody has to report it: the window records the channel's count of state changes when it opens,
        // and a count that has moved by the time it is resolved leaves its integrity unconfirmed.
        vm.warp(start + 2 days);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        assertFalse(win.integrityHolds(id), "active again, and the window is not whole again");
        vm.warp(deadline);
        assertEq(uint256(win.resolve(id)), uint256(win.STATUS_UNDETERMINABLE()), "silence in a broken window proves nothing");
    }

    function test_resolution_implies_no_consent_and_changes_no_binding() public {
        uint256 id = openWindow();
        IAIFPParticipationRegistry.RoleBinding memory before = participation.bindingOf(cResponder);
        vm.warp(deadline);
        win.resolve(id);
        IAIFPParticipationRegistry.RoleBinding memory after_ = participation.bindingOf(cResponder);
        assertEq(uint256(before.state), uint256(after_.state));
        assertEq(before.ruleVersion, after_.ruleVersion);
        assertEq(uint256(before.admittedEpoch), uint256(after_.admittedEpoch));
        assertFalse(win.objected(id, subj(C)), "C registered nothing: neither objection nor consent");
        assertFalse(win.objected(id, subj(B)));
        assertEq(anchor.recordCount(), 0, "no information event attributed to the silent parties");
        // The default consequence itself is the rule's business (for example a rotation executed by a
        // governance binding); the window only reports that the agreed condition occurred.
        assertEq(channels.adoptionCount(ch), 1);
    }

    function test_window_cannot_cover_an_unobservable_past() public {
        vm.prank(A);
        vm.expectRevert(AIFPObjectionWindow.InvalidWindow.selector);
        win.open(ch, keccak256("late proposal"), now48() - 1, deadline, AIFPRoles.RESPOND);
    }
}
