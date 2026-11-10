// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MockExecutor} from "../mocks/Harness.sol";
import {AIFPChannelRegistry} from "../../assets/erc-aifp/contracts/AIFPChannelRegistry.sol";

contract ChannelRegistryTest is Fixture {
    bytes32 P1;
    bytes32 P2;
    bytes32 ch;

    function setUp() public override {
        super.setUp();
        P1 = simpleParadigm(A, "fam", "aifp:paradigm/club/v1", AIFPRoles.SUBMIT, openPredicate());
        P2 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        ch = openChannel(A, P1);
    }

    // ------------------------------------------------------------ opening

    function test_open_records_initial_adoption_at_clock() public view {
        IAIFPChannelRegistry.ChannelRecord memory c = channels.channel(ch);
        assertEq(c.authority, A);
        assertEq(c.parent, bytes32(0));
        assertEq(uint256(c.state), uint256(IAIFPChannelRegistry.ChannelState.Active));
        assertEq(uint256(c.openedAt), uint256(T0));
        assertEq(channels.adoptionCount(ch), 1);
        IAIFPChannelRegistry.Adoption memory a0 = channels.adoptionAt(ch, 0);
        assertEq(a0.paradigmId, P1);
        assertEq(uint256(a0.effectiveAt), uint256(T0));
        assertFalse(a0.requiresReadmission);
        (bytes32 cur, uint48 since) = channels.currentParadigm(ch);
        assertEq(cur, P1);
        assertEq(uint256(since), uint256(T0));
        assertTrue(channels.channelExists(ch));
    }

    function test_open_unknown_paradigm_or_parent_reverts() public {
        IAIFPChannelRegistry.BindingDecl[] memory none = new IAIFPChannelRegistry.BindingDecl[](0);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_UnknownParadigm.selector, keccak256("ghost")));
        channels.openChannel(keccak256("ghost"), A, bytes32(0), "", none);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, keccak256("noparent")));
        channels.openChannel(P1, A, keccak256("noparent"), "", none);
    }

    function test_open_with_parent_and_initial_bindings() public {
        IAIFPChannelRegistry.BindingDecl[] memory decls = new IAIFPChannelRegistry.BindingDecl[](1);
        decls[0] = transportBinding(AIFPBindings.CAP_PUSH | AIFPBindings.CAP_RULE_ASSOCIATION, bytes32("a2a"));
        vm.prank(B);
        bytes32 child = channels.openChannel(P1, B, ch, "thread", decls);
        assertEq(channels.channel(child).parent, ch);
        assertEq(channels.channel(child).authority, B);
        bytes32[] memory ids = channels.bindingIds(child);
        assertEq(ids.length, 1);
        IAIFPChannelRegistry.BindingDecl memory d = channels.binding(child, ids[0]);
        assertTrue(d.active);
        assertEq(uint256(d.capabilities), uint256(AIFPBindings.CAP_PUSH | AIFPBindings.CAP_RULE_ASSOCIATION));
    }

    // ------------------------------------------------------------ adoption

    function test_adopt_by_authority_future_effective() public {
        uint48 eff = now48() + 100;
        vm.prank(A);
        channels.adoptParadigm(ch, P2, eff, false, bytes32("auth"));
        assertEq(channels.adoptionCount(ch), 2);
        // not yet in force
        (bytes32 cur,) = channels.currentParadigm(ch);
        assertEq(cur, P1);
        assertEq(channels.paradigmAt(ch, eff - 1), P1);
        assertEq(channels.paradigmAt(ch, eff), P2);
        vm.warp(eff);
        (cur,) = channels.currentParadigm(ch);
        assertEq(cur, P2);
    }

    function test_adopt_effective_in_past_reverts() public {
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_EffectiveInPast.selector, uint48(T0 - 1), uint48(T0)));
        channels.adoptParadigm(ch, P2, T0 - 1, false, 0);
        // effectiveAt == now is allowed
        vm.prank(A);
        channels.adoptParadigm(ch, P2, T0, false, 0);
    }

    function test_adopt_unknown_paradigm_reverts() public {
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParadigmRegistry.AIFP_UnknownParadigm.selector, keccak256("ghost")));
        channels.adoptParadigm(ch, keccak256("ghost"), T0, false, 0);
    }

    function test_adopt_by_outsider_reverts() public {
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, O));
        channels.adoptParadigm(ch, P2, T0, false, 0);
    }

    function test_adopt_by_manage_rules_holder() public {
        grantRoles(A, ch, B, AIFPRoles.MANAGE_RULES, bytes32(0));
        vm.prank(B);
        channels.adoptParadigm(ch, P2, T0, false, 0);
        assertEq(channels.paradigmAt(ch, T0), P2);
        // a scoped MANAGE_RULES binding does not authorize channel-wide rule changes
        grantRoles(A, ch, C, AIFPRoles.MANAGE_RULES, bytes32("scope"));
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, C));
        channels.adoptParadigm(ch, P1, T0, false, 0);
    }

    function test_adopt_by_governance_executor() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        // without a binding the executor is an outsider
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, address(exec)));
        exec.adopt(ch, P2, T0, false, bytes32("decision"));
        // a rules binding in automatic mode authorizes it
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_AUTOMATIC));
        assertTrue(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
        assertFalse(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_PARTICIPATION));
        exec.adopt(ch, P2, T0, false, bytes32("decision"));
        assertEq(channels.paradigmAt(ch, T0), P2);
    }

    function test_confirmed_mode_executor_is_not_an_executor() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_CONFIRMED));
        assertFalse(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, address(exec)));
        exec.adopt(ch, P2, T0, false, 0);
    }

    function test_revoked_binding_removes_executor_power() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        bytes32 bid = declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_AUTOMATIC));
        assertTrue(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
        vm.prank(A);
        channels.revokeBinding(ch, bid);
        assertFalse(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
        assertFalse(channels.binding(ch, bid).active);
        vm.prank(A);
        vm.expectRevert(IAIFPChannelRegistry.AIFP_InvalidBinding.selector);
        channels.revokeBinding(ch, bid);
    }

    /// @dev A frozen channel can still lose an executor; a closed one accepts no change to its bindings.
    function test_revokeBinding_is_accepted_in_a_frozen_channel_and_not_in_a_closed_one() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        bytes32 first = declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_AUTOMATIC));
        bytes32 second = declare(A, ch, transportBinding(1, bytes32("endpoint")));
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.prank(A);
        channels.revokeBinding(ch, first);
        assertFalse(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_ChannelClosed.selector, ch));
        channels.revokeBinding(ch, second);
    }

    function test_paradigmAt_before_first_adoption_is_zero_and_ties_resolve_to_later_record() public {
        assertEq(channels.paradigmAt(ch, T0 - 1), bytes32(0));
        uint48 eff = now48() + 50;
        vm.prank(A);
        channels.adoptParadigm(ch, P2, eff, false, 0);
        vm.prank(A);
        channels.adoptParadigm(ch, P1, eff, false, 0); // same effectiveAt, recorded later
        assertEq(channels.paradigmAt(ch, eff), P1, "later-recorded adoption wins the tie");
        assertEq(channels.paradigmAt(ch, eff + 1000), P1);
    }

    /// @dev Adoptions can be recorded out of effective order: the later one is scheduled first. The paradigm
    ///      in force is the one with the latest effective timepoint, not the one recorded last.
    function test_paradigmAt_follows_effective_order_when_adoptions_are_recorded_out_of_order() public {
        bytes32 P3 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P2, "3", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, T0 + 100, true, 0); // scheduled first, effective later
        vm.prank(A);
        channels.adoptParadigm(ch, P3, T0 + 50, false, 0); // scheduled second, effective earlier
        assertEq(channels.paradigmAt(ch, T0 + 49), P1, "before either");
        assertEq(channels.paradigmAt(ch, T0 + 50), P3, "the earlier one from its effective timepoint");
        assertEq(channels.paradigmAt(ch, T0 + 99), P3);
        assertEq(channels.paradigmAt(ch, T0 + 100), P2, "the later one from its effective timepoint, although recorded first");
        assertEq(channels.paradigmAt(ch, T0 + 1_000), P2);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 99)), 0);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 100)), 1, "its re-admission requirement comes with it");
        warpBy(100);
        (bytes32 current, uint48 since) = channels.currentParadigm(ch);
        assertEq(current, P2);
        assertEq(uint256(since), uint256(T0 + 100));
    }

    /// @dev Adoptions are never removed: one that is superseded at its own effective timepoint by a later
    ///      record no longer names the paradigm in force, but a re-admission it required still applies.
    function test_superseded_adoption_still_opens_its_readmission_epoch() public {
        bytes32 P3 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P2, "3", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, T0 + 50, true, 0);
        vm.prank(A);
        channels.adoptParadigm(ch, P3, T0 + 50, false, 0);
        assertEq(channels.paradigmAt(ch, T0 + 50), P3, "the later record wins the tie");
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 50)), 1, "the epoch of the superseded adoption stands");
    }

    function test_readmission_epoch_counts_only_effective_requiring_adoptions() public {
        assertEq(uint256(channels.readmissionEpochAt(ch, T0)), 0);
        vm.prank(A);
        channels.adoptParadigm(ch, P2, T0 + 10, true, 0);
        vm.prank(A);
        channels.adoptParadigm(ch, P1, T0 + 20, false, 0);
        vm.prank(A);
        channels.adoptParadigm(ch, P2, T0 + 30, true, 0);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 9)), 0);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 10)), 1);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 25)), 1);
        assertEq(uint256(channels.readmissionEpochAt(ch, T0 + 30)), 2);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, keccak256("x")));
        channels.readmissionEpochAt(keccak256("x"), T0);
    }

    function test_adopt_requires_active_channel() public {
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_ChannelNotActive.selector, ch));
        channels.adoptParadigm(ch, P2, T0, false, 0);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_ChannelNotActive.selector, ch));
        channels.declareBinding(ch, transportBinding(AIFPBindings.CAP_PULL, bytes32("x")));
    }

    // ------------------------------------------------------------ bindings

    function test_declare_binding_validation() public {
        IAIFPChannelRegistry.BindingDecl memory d = transportBinding(AIFPBindings.CAP_PUSH, bytes32("t"));
        d.effectScope = AIFPBindings.EFFECT_RULES; // transport bindings carry no governance effect
        vm.prank(A);
        vm.expectRevert(IAIFPChannelRegistry.AIFP_InvalidBinding.selector);
        channels.declareBinding(ch, d);

        d = transportBinding(AIFPBindings.CAP_PUSH, bytes32("t"));
        d.kind = 9;
        vm.prank(A);
        vm.expectRevert(IAIFPChannelRegistry.AIFP_InvalidBinding.selector);
        channels.declareBinding(ch, d);

        d = transportBinding(AIFPBindings.CAP_PUSH, bytes32("t"));
        d.adoptionMode = 2;
        vm.prank(A);
        vm.expectRevert(IAIFPChannelRegistry.AIFP_InvalidBinding.selector);
        channels.declareBinding(ch, d);

        // outsider cannot declare
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, O));
        channels.declareBinding(ch, transportBinding(AIFPBindings.CAP_PUSH, bytes32("t")));

        // MANAGE_RULES holder can declare
        grantRoles(A, ch, B, AIFPRoles.MANAGE_RULES, bytes32(0));
        bytes32 bid = declare(B, ch, transportBinding(AIFPBindings.CAP_PUSH, bytes32("t")));
        assertTrue(channels.binding(ch, bid).active);
        assertEq(channels.bindingIds(ch).length, 1);
    }

    function test_economic_binding_is_not_an_executor() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        IAIFPChannelRegistry.BindingDecl memory d = governanceBinding(AIFPBindings.KIND_ECONOMIC, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_AUTOMATIC);
        declare(A, ch, d);
        assertFalse(channels.isGovernanceExecutor(ch, address(exec), AIFPBindings.EFFECT_RULES));
    }

    // ------------------------------------------------------------ disclosure records

    function test_disclosure_records_are_append_only_and_typed() public {
        vm.prank(A);
        channels.recordDisclosure(ch, AIFPBindings.DISCLOSURE_DISCLOSED, bytes32("obj"), bytes32("public"), bytes32("auth"));
        warpBy(10);
        vm.prank(A);
        channels.recordDisclosure(ch, AIFPBindings.DISCLOSURE_RESTRICTED, bytes32("obj"), bytes32("public"), bytes32("auth2"));
        assertEq(channels.disclosureCount(ch), 2);
        (uint8 k0, bytes32 o0, bytes32 a0,, uint48 t0) = channels.disclosureAt(ch, 0);
        (uint8 k1,,,, uint48 t1) = channels.disclosureAt(ch, 1);
        assertEq(uint256(k0), uint256(AIFPBindings.DISCLOSURE_DISCLOSED));
        assertEq(o0, bytes32("obj"));
        assertEq(a0, bytes32("public"));
        assertEq(uint256(t0), uint256(T0));
        assertEq(uint256(k1), uint256(AIFPBindings.DISCLOSURE_RESTRICTED));
        assertEq(uint256(t1), uint256(T0 + 10));
        // invalid kind
        vm.prank(A);
        vm.expectRevert(IAIFPChannelRegistry.AIFP_InvalidBinding.selector);
        channels.recordDisclosure(ch, 2, bytes32("obj"), bytes32("public"), 0);
    }

    function test_disclosure_authorization_paths() public {
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, O));
        channels.recordDisclosure(ch, 0, bytes32("obj"), bytes32("aud"), 0);
        // MANAGE_DISCLOSURE holder
        grantRoles(A, ch, B, AIFPRoles.MANAGE_DISCLOSURE, bytes32(0));
        vm.prank(B);
        channels.recordDisclosure(ch, 0, bytes32("obj"), bytes32("aud"), 0);
        // MANAGE_RULES alone is not enough
        grantRoles(A, ch, C, AIFPRoles.MANAGE_RULES, bytes32(0));
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, C));
        channels.recordDisclosure(ch, 0, bytes32("obj"), bytes32("aud"), 0);
        // disclosure executor (e.g. a dispute registry ruling)
        MockExecutor exec = new MockExecutor(channels, participation);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_DISPUTE, address(exec), AIFPBindings.EFFECT_DISCLOSURE, AIFPBindings.ADOPTION_AUTOMATIC));
        exec.disclose(ch, 1, bytes32("obj"), bytes32("aud"));
        assertEq(channels.disclosureCount(ch), 2);
    }

    function test_disclosure_allowed_when_closed() public {
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        vm.prank(A);
        channels.recordDisclosure(ch, AIFPBindings.DISCLOSURE_DISCLOSED, bytes32("history"), bytes32("public"), 0);
        assertEq(channels.disclosureCount(ch), 1);
        // but no rule changes or bindings once closed
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_ChannelNotActive.selector, ch));
        channels.adoptParadigm(ch, P2, now48(), false, 0);
    }

    // ------------------------------------------------------------ state and authority

    function test_state_transitions_and_closed_is_terminal() public {
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, O));
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        assertEq(uint256(channels.channel(ch).state), uint256(IAIFPChannelRegistry.ChannelState.Frozen));
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_ChannelClosed.selector, ch));
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
    }

    /// @dev The interface exposes the current state only. The reference registry also counts the changes,
    ///      so that a contract can tell that a channel was not frozen and released between two reads.
    function test_state_changes_are_counted() public {
        assertEq(uint256(channels.stateChanges(ch)), 0);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active); // already active: not a change
        assertEq(uint256(channels.stateChanges(ch)), 0);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen); // still frozen: not a change
        assertEq(uint256(channels.stateChanges(ch)), 1);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        assertEq(uint256(channels.stateChanges(ch)), 2);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        assertEq(uint256(channels.stateChanges(ch)), 3);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, bytes32("nope")));
        channels.stateChanges(bytes32("nope"));
    }

    function authorityOf(Vm.Log[] memory logs, address emitter, bytes32 topic0) internal pure returns (address by, uint8 kind, bytes32 under) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != emitter || logs[i].topics[0] != topic0) continue;
            bytes memory d = logs[i].data;
            uint256 n = d.length;
            assembly ("memory-safe") {
                by := mload(add(add(d, 0x20), sub(n, 0x60)))
                kind := mload(add(add(d, 0x20), sub(n, 0x40)))
                under := mload(add(add(d, 0x20), sub(n, 0x20)))
            }
            return (by, kind, under);
        }
        revert("log not found");
    }

    /// @dev Adoption, binding declaration and revocation, and disclosure records name the caller, the grounds
    ///      and, for a role holder, the binding relied on.
    function test_management_events_name_their_authority() public {
        bytes32 rulesBid = grantRoles(A, ch, B, AIFPRoles.MANAGE_RULES, 0);
        bytes32 discBid = grantRoles(A, ch, C, AIFPRoles.MANAGE_DISCLOSURE, 0);
        MockExecutor exec = new MockExecutor(channels, participation);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_RULES, AIFPBindings.ADOPTION_AUTOMATIC));

        vm.recordLogs();
        vm.prank(B);
        channels.adoptParadigm(ch, P2, now48() + 10, false, 0);
        (address by, uint8 kind, bytes32 under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.ParadigmAdopted.selector);
        assertTrue(by == B && kind == AIFPBasis.AUTHORITY_ROLE && under == rulesBid, "adoption by a MANAGE_RULES holder");

        vm.recordLogs();
        exec.adopt(ch, P2, now48() + 20, false, 0);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.ParadigmAdopted.selector);
        assertTrue(by == address(exec) && kind == AIFPBasis.AUTHORITY_EXECUTOR && under == bytes32(0), "adoption by an executor");

        vm.recordLogs();
        bytes32 tb = declare(A, ch, transportBinding(1, bytes32("endpoint")));
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.BindingDeclared.selector);
        assertTrue(by == A && kind == AIFPBasis.AUTHORITY_CHANNEL && under == bytes32(0), "declaration by the authority");

        vm.recordLogs();
        vm.prank(B);
        channels.revokeBinding(ch, tb);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.BindingRevoked.selector);
        assertTrue(by == B && kind == AIFPBasis.AUTHORITY_ROLE && under == rulesBid, "revocation by a MANAGE_RULES holder");

        vm.recordLogs();
        vm.prank(C);
        channels.recordDisclosure(ch, AIFPBindings.DISCLOSURE_DISCLOSED, bytes32("obj"), bytes32("aud"), 0);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.DisclosureRecorded.selector);
        assertTrue(by == C && kind == AIFPBasis.AUTHORITY_ROLE && under == discBid, "disclosure by a MANAGE_DISCLOSURE holder");

        // The records written by openChannel name the opener as the authority of that moment.
        vm.recordLogs();
        vm.prank(O);
        channels.openChannel(P1, A, bytes32(0), "ipfs://x", new IAIFPChannelRegistry.BindingDecl[](0));
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(channels), IAIFPChannelRegistry.ParadigmAdopted.selector);
        assertTrue(by == O && kind == AIFPBasis.AUTHORITY_CHANNEL && under == bytes32(0), "opening adoption");
    }

    function test_transfer_authority() public {
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, O));
        channels.transferAuthority(ch, O);
        vm.prank(A);
        channels.transferAuthority(ch, B);
        assertEq(channels.channel(ch).authority, B);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_NotAuthorized.selector, ch, A));
        channels.adoptParadigm(ch, P2, now48(), false, 0);
        vm.prank(B);
        channels.adoptParadigm(ch, P2, now48(), false, 0);
    }

    function test_set_participation_registry_once_by_deployer() public {
        AIFPChannelRegistry fresh = new AIFPChannelRegistry(paradigms);
        vm.prank(O);
        vm.expectRevert(AIFPChannelRegistry.AIFP_NotDeployer.selector);
        fresh.setParticipationRegistry(participation);
        fresh.setParticipationRegistry(participation);
        vm.expectRevert(AIFPChannelRegistry.AIFP_AlreadyInitialized.selector);
        fresh.setParticipationRegistry(participation);
    }

    function test_unknown_channel_views_revert() public {
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, keccak256("x")));
        channels.channel(keccak256("x"));
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, keccak256("x")));
        channels.paradigmAt(keccak256("x"), T0);
    }

    function test_erc165_and_clock() public view {
        assertTrue(channels.supportsInterface(type(IAIFPChannelRegistry).interfaceId));
        assertTrue(channels.supportsInterface(type(IERC6372).interfaceId));
        assertTrue(channels.supportsInterface(type(IERC165).interfaceId));
        assertEq(channels.CLOCK_MODE(), "mode=timestamp");
        assertEq(uint256(channels.clock()), block.timestamp);
    }
}
