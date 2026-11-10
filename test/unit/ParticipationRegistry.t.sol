// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "../utils/Fixture.sol";
import {MockVerifier} from "../mocks/MockVerifier.sol";
import {MockExecutor} from "../mocks/Harness.sol";

contract ParticipationRegistryTest is Fixture {
    uint8 constant S = AIFPOutcomes.SATISFIED;
    uint8 constant N = AIFPOutcomes.NOT_SATISFIED;
    uint8 constant U = AIFPOutcomes.UNDETERMINABLE;
    uint8 constant E = AIFPOutcomes.VERIFIER_ERROR;

    bytes32 constant SCOPE_X = keccak256("scope-x");
    bytes32 constant SCOPE_Y = keccak256("scope-y");

    MockVerifier mock;
    bytes32 P1; // SUBMIT by open predicate; RESPOND by external mock predicate
    bytes32 ch;
    bytes extPred;

    function setUp() public override {
        super.setUp();
        mock = new MockVerifier();
        extPred = externalPredicate(AIFPPredicates.EXTERNAL, address(mock), bytes32("ext"));
        P1 = registerParadigm(
            A, "P1", keccak256("fam"), 0, labels1("aifp:paradigm/club/v1"), twoPreds(AIFPRoles.SUBMIT, openPredicate(), AIFPRoles.RESPOND, extPred)
        );
        ch = openChannel(A, P1);
    }

    // ------------------------------------------------------------ grant: authorization and validation

    function test_grant_by_authority_records_binding() public {
        vm.prank(A);
        bytes32 bid = participation.grant(ch, subj(B), subj(C), AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, SCOPE_X, AIFPBasis.ALLOWLIST, bytes32("roster"), 0, T0 + 1000);
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(bid);
        assertEq(b.channelId, ch);
        assertEq(b.subject, subj(B));
        assertEq(b.onBehalfOf, subj(C));
        assertEq(uint256(b.roles), uint256(AIFPRoles.OBSERVE | AIFPRoles.SUBMIT));
        assertEq(b.scopeRef, SCOPE_X);
        assertEq(uint256(b.basisKind), uint256(AIFPBasis.ALLOWLIST));
        assertEq(b.basisRef, bytes32("roster"));
        assertEq(uint256(b.outcomeAtGrant), uint256(S));
        assertEq(b.ruleVersion, P1);
        assertEq(uint256(b.validFrom), uint256(T0));
        assertEq(uint256(b.validUntil), uint256(T0 + 1000));
        assertEq(uint256(b.state), uint256(IAIFPParticipationRegistry.BindingState.Granted));
        assertEq(uint256(b.admittedEpoch), 0);
        bytes32[] memory ids = participation.bindingIdsOf(ch, subj(B));
        assertEq(ids.length, 1);
        assertEq(ids[0], bid);
    }

    function test_grant_by_outsider_reverts() public {
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, O));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
    }

    function test_scoped_admission_manager_only_manages_its_scope() public {
        grantRoles(A, ch, B, AIFPRoles.MANAGE_ADMISSION, SCOPE_X);
        // B can grant inside scope X
        vm.prank(B);
        participation.grant(ch, subj(C), 0, AIFPRoles.OBSERVE, SCOPE_X, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, SCOPE_X), S, "C observes X");
        // not in scope Y, not channel-wide
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, B));
        participation.grant(ch, subj(C), 0, AIFPRoles.OBSERVE, SCOPE_Y, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, B));
        participation.grant(ch, subj(C), 0, AIFPRoles.OBSERVE, bytes32(0), AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        // a channel-wide manager manages every scope
        grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, bytes32(0));
        vm.prank(C);
        participation.grant(ch, subj(O), 0, AIFPRoles.OBSERVE, SCOPE_Y, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        assertOutcome(evalNow(ch, O, AIFPRoles.OBSERVE, SCOPE_Y), S, "O observes Y");
    }

    function test_grant_by_governance_executor() public {
        MockExecutor exec = new MockExecutor(channels, participation);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, address(exec)));
        exec.grant(ch, subj(B), AIFPRoles.OBSERVE, 0);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_PARTICIPATION, AIFPBindings.ADOPTION_AUTOMATIC));
        bytes32 bid = exec.grant(ch, subj(B), AIFPRoles.OBSERVE, 0);
        assertEq(uint256(participation.bindingOf(bid).basisKind), uint256(AIFPBasis.DECISION));
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, 0), S, "granted by decision executor");
    }

    function test_grant_validation() public {
        // undefined / empty roles
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(0)));
        participation.grant(ch, subj(B), 0, 0, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(1 << 12)));
        participation.grant(ch, subj(B), 0, 1 << 12, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        // PREDICATE basis is reserved for the admission path
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.OBSERVE)));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.PREDICATE, 0, 0, 0);
        // unknown basis kind
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.OBSERVE)));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, 9, 0, 0, 0);
        // validFrom in the past
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ValidFromInPast.selector, uint48(T0 - 1), uint48(T0)));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, T0 - 1, 0);
        // empty interval
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidInterval.selector, uint48(T0 + 10), uint48(T0 + 10)));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, T0 + 10, T0 + 10);
        // validFrom 0 defaults to now
        vm.prank(A);
        bytes32 bid = participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        assertEq(uint256(participation.bindingOf(bid).validFrom), uint256(T0));
    }

    function test_grant_requires_active_channel() public {
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ChannelNotActive.selector, ch));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ChannelNotActive.selector, ch));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
    }

    /// @dev Re-admission is an admission: a frozen channel accepts neither `readmit` nor
    ///      `confirmReadmission`, while suspension, reinstatement and revocation keep working.
    function test_readmission_requires_active_channel() public {
        bytes32 managerBid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        bytes32 spare = grantRoles(A, ch, B, AIFPRoles.OBSERVE, 0);
        vm.prank(C);
        bytes32 predBid = participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        bytes32 P2 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P1, "2", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48() + 100, true, bytes32("vote"));
        warpBy(100);
        bytes memory notActive = abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ChannelNotActive.selector, ch);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        // The adoption took effect although the channel is frozen: both bindings are pending.
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), U, "pending");
        vm.prank(A);
        vm.expectRevert(notActive);
        participation.confirmReadmission(managerBid);
        vm.prank(C);
        vm.expectRevert(notActive);
        participation.readmit(predBid, openPredicate(), noEvidence());
        // What reduces or restores an existing binding still works.
        vm.prank(A);
        participation.suspend(managerBid, bytes32("hold"));
        vm.prank(A);
        participation.reinstate(managerBid);
        vm.prank(A);
        participation.revoke(spare, bytes32("end"));
        // Once the channel is active again both re-admissions go through.
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        vm.prank(A);
        participation.confirmReadmission(managerBid);
        vm.prank(C);
        participation.readmit(predBid, openPredicate(), noEvidence());
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "confirmed");
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), S, "re-admitted");
        // A closed channel accepts neither, for good.
        bytes32 P3 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P2, "3", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P3, now48() + 50, true, bytes32("vote"));
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "closing changes no binding");
        warpBy(50);
        // An adoption recorded while the channel was active comes into force whatever its state is by then.
        assertEq(channels.paradigmAt(ch, now48()), P3, "in force in a closed channel");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), U, "and its re-admission requirement with it");
        vm.prank(A);
        vm.expectRevert(notActive);
        participation.confirmReadmission(managerBid);
        vm.prank(C);
        vm.expectRevert(notActive);
        participation.readmit(predBid, openPredicate(), noEvidence());
        vm.prank(A);
        participation.revoke(managerBid, bytes32("end"));
    }

    function test_max_bindings_per_subject() public {
        for (uint256 i = 0; i < participation.MAX_BINDINGS_PER_SUBJECT(); i++) {
            grantRoles(A, ch, B, AIFPRoles.OBSERVE, bytes32(i + 1));
        }
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_TooManyBindings.selector, ch, subj(B)));
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, 0, 0);
    }

    // ------------------------------------------------------------ admission path

    function test_admit_happy_path_records_predicate_basis() public {
        vm.prank(B);
        bytes32 bid = participation.admit(ch, AIFPRoles.SUBMIT, SCOPE_X, openPredicate(), noEvidence(), T0 + 500);
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(bid);
        assertEq(b.subject, subj(B));
        assertEq(uint256(b.roles), uint256(AIFPRoles.SUBMIT));
        assertEq(b.scopeRef, SCOPE_X);
        assertEq(uint256(b.basisKind), uint256(AIFPBasis.PREDICATE));
        assertEq(b.basisRef, keccak256(openPredicate()));
        assertEq(uint256(b.validFrom), uint256(T0));
        assertEq(uint256(b.validUntil), uint256(T0 + 500));
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, SCOPE_X), S, "admitted");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, SCOPE_Y), N, "scoped");
    }

    function test_admit_subject_is_always_msg_sender() public {
        vm.prank(B);
        bytes32 bid = participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        assertEq(participation.bindingOf(bid).subject, subj(B));
        assertEq(participation.bindingIdsOf(ch, subj(C)).length, 0);
    }

    function test_admit_rejects_multi_role_and_wrong_predicate() public {
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.SUBMIT | AIFPRoles.RESPOND)));
        participation.admit(ch, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0, openPredicate(), noEvidence(), 0);

        bytes memory wrong = allowlistPredicate(address(1));
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_PredicateMismatch.selector, keccak256(openPredicate()), keccak256(wrong)));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, wrong, noEvidence(), 0);

        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NoPredicateForRole.selector, P1, uint16(AIFPRoles.OBSERVE)));
        participation.admit(ch, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence(), 0);
    }

    function test_admit_reverts_with_the_outcome() public {
        mock.setFixed(N);
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_NotSatisfied.selector);
        participation.admit(ch, AIFPRoles.RESPOND, 0, extPred, noEvidence(), 0);
        mock.setFixed(U);
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_Undeterminable.selector);
        participation.admit(ch, AIFPRoles.RESPOND, 0, extPred, noEvidence(), 0);
        mock.setMode(mock.MODE_REVERT());
        vm.prank(B);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_VerifierError.selector);
        participation.admit(ch, AIFPRoles.RESPOND, 0, extPred, noEvidence(), 0);
        // nothing was recorded for the failed attempts
        assertEq(participation.bindingIdsOf(ch, subj(B)).length, 0);
        mock.setFixed(S);
        vm.prank(B);
        participation.admit(ch, AIFPRoles.RESPOND, 0, extPred, noEvidence(), 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.RESPOND, 0), S, "admitted after fix");
    }

    function test_admit_validUntil_must_be_in_future() public {
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidInterval.selector, uint48(T0), uint48(T0)));
        participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), T0);
    }

    function test_preview_admission() public {
        assertOutcome(participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence()), S, "open");
        mock.setFixed(U);
        assertOutcome(participation.previewAdmission(ch, subj(B), AIFPRoles.RESPOND, 0, extPred, noEvidence()), U, "undeterminable passes through");
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_PredicateMismatch.selector, keccak256(openPredicate()), keccak256(extPred)));
        participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT, 0, extPred, noEvidence());
    }

    /// @dev A preview reverts where an admission would be rejected, with the same error: it reports an
    ///      outcome only when the composite verifier returned one. In particular a role that the paradigm
    ///      gives no predicate is not reported as NOT_SATISFIED - nothing was evaluated.
    function test_preview_rejects_what_admit_rejects() public {
        bytes memory noPredicate = abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NoPredicateForRole.selector, P1, uint16(AIFPRoles.OBSERVE));
        vm.expectRevert(noPredicate);
        participation.previewAdmission(ch, subj(B), AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence());
        vm.prank(B);
        vm.expectRevert(noPredicate);
        participation.admit(ch, AIFPRoles.OBSERVE, 0, openPredicate(), noEvidence(), 0);

        bytes memory twoRoles = abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.SUBMIT | AIFPRoles.RESPOND));
        vm.expectRevert(twoRoles);
        participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT | AIFPRoles.RESPOND, 0, openPredicate(), noEvidence());

        bytes memory notActive = abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_ChannelNotActive.selector, ch);
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Frozen);
        vm.expectRevert(notActive);
        participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Active);
        assertOutcome(participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence()), S, "active again");
        vm.prank(A);
        channels.setState(ch, IAIFPChannelRegistry.ChannelState.Closed);
        vm.expectRevert(notActive);
        participation.previewAdmission(ch, subj(B), AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence());
    }

    // ------------------------------------------------------------ suspend / reinstate / revoke

    function test_suspend_and_reinstate_only_by_suspender() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, 0);
        // outsider cannot suspend
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, O));
        participation.suspend(bid, bytes32("x"));
        // manager C suspends
        vm.prank(C);
        participation.suspend(bid, bytes32("abuse"));
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), N, "suspended");
        assertEq(uint256(participation.bindingOf(bid).state), uint256(IAIFPParticipationRegistry.BindingState.Suspended));
        // double suspension is rejected
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_BindingNotActive.selector, bid));
        participation.suspend(bid, bytes32("again"));
        // the authority did not impose it, so it cannot lift it
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotSuspender.selector, bid, A));
        participation.reinstate(bid);
        // reinstating a non-suspended binding is rejected (use another binding)
        bytes32 other = grantRoles(A, ch, O, AIFPRoles.OBSERVE, 0);
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_BindingNotSuspended.selector, other));
        participation.reinstate(other);
        // C lifts it
        warpBy(10);
        vm.prank(C);
        participation.reinstate(bid);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "reinstated");
        assertEq(uint256(participation.bindingOf(bid).state), uint256(IAIFPParticipationRegistry.BindingState.Granted));
    }

    function test_intervener_suspension_not_liftable_by_authority() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        MockExecutor intervener = new MockExecutor(channels, participation);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_SAFETY, address(intervener), AIFPBindings.EFFECT_PARTICIPATION, AIFPBindings.ADOPTION_AUTOMATIC));
        intervener.suspend(bid);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), N, "intervened");
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotSuspender.selector, bid, A));
        participation.reinstate(bid);
        intervener.reinstate(bid);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "lifted by intervener");
    }

    function test_revoke_is_terminal_and_closes_suspension() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        vm.prank(A);
        participation.suspend(bid, bytes32("s"));
        warpBy(5);
        vm.prank(A);
        participation.revoke(bid, bytes32("r"));
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(bid);
        assertEq(uint256(b.state), uint256(IAIFPParticipationRegistry.BindingState.Revoked));
        assertEq(uint256(b.revokedAt), uint256(T0 + 5));
        assertEq(uint256(b.reinstatedAt), uint256(T0 + 5), "suspension closed at revocation");
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_BindingNotActive.selector, bid));
        participation.revoke(bid, bytes32("again"));
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_BindingNotActive.selector, bid));
        participation.suspend(bid, bytes32("again"));
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_BindingNotSuspended.selector, bid));
        participation.reinstate(bid);
        // history: suspended during [T0, T0+5), revoked from T0+5
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0), N, "suspended at T0");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 5), N, "revoked at T0+5");
    }

    function test_revoke_authorization() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, SCOPE_X);
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, O));
        participation.revoke(bid, 0);
        // a manager of another scope cannot revoke a scope-X binding
        grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, SCOPE_Y);
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, C));
        participation.revoke(bid, 0);
        grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, SCOPE_X);
        vm.prank(C);
        participation.revoke(bid, 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, SCOPE_X), N, "revoked by scope manager");
    }

    function test_unknown_binding_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_UnknownBinding.selector, keccak256("x")));
        participation.bindingOf(keccak256("x"));
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_UnknownBinding.selector, keccak256("x")));
        participation.suspend(keccak256("x"), 0);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_UnknownBinding.selector, keccak256("x")));
        participation.isPending(keccak256("x"), T0);
    }

    // ------------------------------------------------------------ re-admission

    function _adoptWithReadmission() internal returns (bytes32 P2) {
        P2 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P1, "2", onePred(AIFPRoles.SUBMIT, allowlistPredicate(address(0))));
        vm.prank(A);
        channels.adoptParadigm(ch, P2, now48() + 100, true, bytes32("vote"));
    }

    function test_pending_after_readmission_adoption() public {
        bytes32 managerBid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        vm.prank(C);
        bytes32 predBid = participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        _adoptWithReadmission();
        // before the effective timepoint nothing changes
        assertFalse(participation.isPending(managerBid, now48()));
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "still satisfied");
        warpBy(100);
        assertTrue(participation.isPending(managerBid, now48()));
        assertTrue(participation.isPending(predBid, now48()));
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), U, "pending -> undeterminable");
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), U, "pending -> undeterminable");
        // history before the change is unaffected
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0), S, "history");
        assertFalse(participation.isPending(managerBid, T0));
    }

    /// @dev What decides is whether the adoption was already in effect when the binding was granted, not
    ///      whether it was already recorded: a binding granted while the adoption is still scheduled becomes
    ///      pending at its effective timepoint like every earlier one. Otherwise a subject could be admitted
    ///      under the old rules a moment before the change and skip the re-admission it requires.
    function test_binding_granted_while_an_adoption_is_scheduled_is_pending_from_its_effective_timepoint() public {
        bytes32 before = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        _adoptWithReadmission(); // recorded at T0, effective at T0 + 100
        warpBy(10);
        bytes32 between = grantRoles(A, ch, C, AIFPRoles.SUBMIT, 0);
        assertEq(uint256(participation.bindingOf(between).admittedEpoch), 0, "the adoption is not in effect yet");
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), S, "valid until the change");
        // A grant whose validity starts at the effective timepoint is recorded now, under the epoch of now.
        vm.prank(A);
        bytes32 future = participation.grant(ch, subj(O), 0, AIFPRoles.SUBMIT, 0, AIFPBasis.MANAGER_GRANT, 0, T0 + 100, 0);
        warpBy(90);
        assertOutcome(evalAt(ch, C, AIFPRoles.SUBMIT, 0, T0 + 99), S, "the last timepoint under the old rules");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), U, "granted before the adoption was recorded");
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), U, "granted while it was scheduled");
        assertOutcome(evalNow(ch, O, AIFPRoles.SUBMIT, 0), U, "granted while it was scheduled, valid from its effective timepoint");
        assertTrue(participation.isPending(before, now48()) && participation.isPending(between, now48()) && participation.isPending(future, now48()));
        // A binding granted once the adoption is in effect is not pending.
        bytes32 after_ = grantRoles(A, ch, A, AIFPRoles.SUBMIT, 0);
        assertEq(uint256(participation.bindingOf(after_).admittedEpoch), 1);
        assertOutcome(evalNow(ch, A, AIFPRoles.SUBMIT, 0), S, "granted at the effective timepoint, after the adoption");
    }

    function test_confirm_readmission_for_manager_bindings() public {
        bytes32 managerBid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        bytes32 P2 = _adoptWithReadmission();
        warpBy(100);
        // not pending until effective: already effective now; outsider cannot confirm
        vm.prank(O);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, O));
        participation.confirmReadmission(managerBid);
        vm.prank(A);
        participation.confirmReadmission(managerBid);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "confirmed");
        IAIFPParticipationRegistry.RoleBinding memory b = participation.bindingOf(managerBid);
        assertEq(uint256(b.admittedEpoch), 1);
        assertEq(b.ruleVersion, P2);
        // confirming twice is rejected
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotPending.selector, managerBid));
        participation.confirmReadmission(managerBid);
        // The confirmation was recorded at the adoption's own effective timepoint, so no timepoint reads as
        // pending: the pending state lasted for part of T0+100 only and shows in the logs, not in a read.
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 100), S, "readmitted at T0+100");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 50), S, "before change");
    }

    function test_readmit_predicate_bindings_against_new_rules() public {
        vm.prank(C);
        bytes32 predBid = participation.admit(ch, AIFPRoles.SUBMIT, 0, openPredicate(), noEvidence(), 0);
        bytes32 P2 = _adoptWithReadmission(); // new SUBMIT predicate = allowlist on a zero set (UNDETERMINABLE)
        // not pending yet
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotPending.selector, predBid));
        participation.readmit(predBid, openPredicate(), noEvidence());
        warpBy(100);
        // the subject must act, with the predicate of the new version
        vm.prank(B);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_SubjectMismatch.selector, subj(C), B));
        participation.readmit(predBid, allowlistPredicate(address(0)), noEvidence());
        vm.prank(C);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_PredicateMismatch.selector, keccak256(allowlistPredicate(address(0))), keccak256(openPredicate())));
        participation.readmit(predBid, openPredicate(), noEvidence());
        vm.prank(C);
        vm.expectRevert(IAIFPParticipationRegistry.AIFP_Undeterminable.selector);
        participation.readmit(predBid, allowlistPredicate(address(0)), noEvidence());
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), U, "still pending");
        // a manager cannot confirm a predicate binding
        vm.prank(A);
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_NotAuthorized.selector, ch, A));
        participation.confirmReadmission(predBid);
        // a third version with an open predicate lets C re-admit
        bytes32 P3 = successorParadigm(A, "fam", "aifp:paradigm/club/v1", P2, "3", onePred(AIFPRoles.SUBMIT, openPredicate()));
        vm.prank(A);
        channels.adoptParadigm(ch, P3, now48(), false, 0);
        vm.prank(C);
        participation.readmit(predBid, openPredicate(), noEvidence());
        assertOutcome(evalNow(ch, C, AIFPRoles.SUBMIT, 0), S, "readmitted");
        assertEq(participation.bindingOf(predBid).ruleVersion, P3);
    }

    // ------------------------------------------------------------ evaluation semantics

    function test_interval_boundaries() public {
        vm.prank(A);
        participation.grant(ch, subj(B), 0, AIFPRoles.OBSERVE, 0, AIFPBasis.MANAGER_GRANT, 0, T0 + 10, T0 + 20);
        assertOutcome(evalAt(ch, B, AIFPRoles.OBSERVE, 0, T0 + 9), N, "before validFrom");
        assertOutcome(evalAt(ch, B, AIFPRoles.OBSERVE, 0, T0 + 10), S, "validFrom inclusive");
        assertOutcome(evalAt(ch, B, AIFPRoles.OBSERVE, 0, T0 + 19), S, "inside");
        assertOutcome(evalAt(ch, B, AIFPRoles.OBSERVE, 0, T0 + 20), N, "validUntil exclusive");
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, 0), N, "not yet valid now");
    }

    function test_revocation_excludes_its_timepoint_and_keeps_history() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        warpBy(100);
        vm.prank(A);
        participation.revoke(bid, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0), S, "grant timepoint");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 99), S, "just before revocation");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 100), N, "at revocation");
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), N, "now");
    }

    function test_same_timepoint_grant_then_revoke_then_regrant() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        vm.prank(A);
        participation.revoke(bid, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0), N, "grant then revoke in the same timepoint -> excluded");
        grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0), S, "a new binding at the same timepoint is included");
    }

    function test_suspension_history_after_reinstate() public {
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        warpBy(10);
        vm.prank(A);
        participation.suspend(bid, 0);
        warpBy(10);
        vm.prank(A);
        participation.reinstate(bid);
        warpBy(10);
        vm.prank(A);
        participation.suspend(bid, 0);
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 5), S, "before first suspension");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 10), N, "first suspension start");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 19), N, "inside first suspension");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 20), S, "reinstated (exclusive end)");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 25), S, "between suspensions");
        assertOutcome(evalAt(ch, B, AIFPRoles.SUBMIT, 0, T0 + 30), N, "second suspension");
        assertEq(participation.suspensionsOf(bid).length, 2);
    }

    function test_another_satisfied_binding_wins_over_pending_or_suspended() public {
        bytes32 first = grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        vm.prank(A);
        participation.suspend(first, 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), N, "only a suspended binding");
        grantRoles(A, ch, B, AIFPRoles.SUBMIT, 0);
        assertOutcome(evalNow(ch, B, AIFPRoles.SUBMIT, 0), S, "second binding satisfied");
    }

    function test_scope_semantics() public {
        grantRoles(A, ch, B, AIFPRoles.OBSERVE, 0); // channel-wide
        grantRoles(A, ch, C, AIFPRoles.OBSERVE, SCOPE_X); // scoped
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, 0), S, "wide @ channel");
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, SCOPE_X), S, "wide @ X");
        assertOutcome(evalNow(ch, B, AIFPRoles.OBSERVE, SCOPE_Y), S, "wide @ Y");
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, SCOPE_X), S, "scoped @ X");
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, SCOPE_Y), N, "scoped @ Y");
        assertOutcome(evalNow(ch, C, AIFPRoles.OBSERVE, 0), N, "scoped @ channel");
    }

    function test_rolesOf_union_and_role_filter() public {
        grantRoles(A, ch, B, AIFPRoles.OBSERVE | AIFPRoles.RESPOND, 0);
        bytes32 bid = grantRoles(A, ch, B, AIFPRoles.SUBMIT, SCOPE_X);
        assertEq(uint256(participation.rolesOf(ch, subj(B), 0, now48())), uint256(AIFPRoles.OBSERVE | AIFPRoles.RESPOND));
        assertEq(uint256(participation.rolesOf(ch, subj(B), SCOPE_X, now48())), uint256(AIFPRoles.OBSERVE | AIFPRoles.RESPOND | AIFPRoles.SUBMIT));
        vm.prank(A);
        participation.suspend(bid, 0);
        assertEq(uint256(participation.rolesOf(ch, subj(B), SCOPE_X, now48())), uint256(AIFPRoles.OBSERVE | AIFPRoles.RESPOND));
        assertEq(uint256(participation.rolesOf(ch, subj(O), 0, now48())), 0);
        // evaluate requires a single role bit
        vm.expectRevert(abi.encodeWithSelector(IAIFPParticipationRegistry.AIFP_InvalidRole.selector, uint16(AIFPRoles.OBSERVE | AIFPRoles.RESPOND)));
        participation.evaluate(ch, subj(B), AIFPRoles.OBSERVE | AIFPRoles.RESPOND, 0, now48());
    }

    function test_evaluate_unknown_channel_reverts_and_no_bindings_is_not_satisfied() public {
        vm.expectRevert(abi.encodeWithSelector(IAIFPChannelRegistry.AIFP_UnknownChannel.selector, keccak256("x")));
        participation.evaluate(keccak256("x"), subj(B), AIFPRoles.OBSERVE, 0, now48());
        assertOutcome(evalNow(ch, O, AIFPRoles.OBSERVE, 0), N, "no bindings");
    }

    function test_erc165_and_clock_follow_channel_registry() public view {
        assertTrue(participation.supportsInterface(type(IAIFPParticipationRegistry).interfaceId));
        assertTrue(participation.supportsInterface(type(IERC6372).interfaceId));
        assertEq(participation.CLOCK_MODE(), channels.CLOCK_MODE());
        assertEq(uint256(participation.clock()), uint256(channels.clock()));
    }

    function test_events_on_grant_and_admit() public {
        vm.expectEmit(true, true, false, false);
        emit IAIFPParticipationRegistry.RoleGranted(ch, subj(B), bytes32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, address(0), 0, 0);
        grantRoles(A, ch, B, AIFPRoles.OBSERVE, 0);
        vm.expectEmit(true, true, false, true);
        emit IAIFPParticipationRegistry.AdmissionEvaluated(ch, subj(B), AIFPRoles.SUBMIT, SCOPE_X, S);
        vm.prank(B);
        participation.admit(ch, AIFPRoles.SUBMIT, SCOPE_X, openPredicate(), noEvidence(), 0);
    }

    // ------------------------------------------------------------ the management events name their authority

    /// @dev Last three data words of the first log with `topic0` from `emitter`: by, authorityKind, binding.
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

    /// @dev Last three data words as (uint48, uint8, bytes32): for RoleSuspended and RoleRevoked these are
    ///      at, authorityKind and authorizingBinding (the caller is an indexed topic there).
    function lastThree(Vm.Log[] memory logs, address emitter, bytes32 topic0) internal pure returns (uint48 a, uint8 kind, bytes32 under) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != emitter || logs[i].topics[0] != topic0) continue;
            bytes memory d = logs[i].data;
            uint256 n = d.length;
            assembly ("memory-safe") {
                a := mload(add(add(d, 0x20), sub(n, 0x60)))
                kind := mload(add(add(d, 0x20), sub(n, 0x40)))
                under := mload(add(add(d, 0x20), sub(n, 0x20)))
            }
            return (a, kind, under);
        }
        revert("log not found");
    }

    /// @dev A grant by the authority, by an executor and by a MANAGE_ADMISSION holder: the event says which,
    ///      and names the manager's binding so that a reader of the log can check it against the role history
    ///      in log order (asked on the ERC-8489 thread: a smart wallet's transaction sender alone does not say
    ///      which account the registry authorized).
    function test_grant_event_names_caller_authority_kind_and_binding() public {
        bytes32 managerBid = grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, 0);
        MockExecutor exec = new MockExecutor(channels, participation);
        declare(A, ch, governanceBinding(AIFPBindings.KIND_GOVERNANCE_RULES, address(exec), AIFPBindings.EFFECT_PARTICIPATION, AIFPBindings.ADOPTION_AUTOMATIC));
        bytes32 sel = IAIFPParticipationRegistry.RoleGranted.selector;

        vm.recordLogs();
        grantRoles(A, ch, B, AIFPRoles.OBSERVE, 0);
        (address by, uint8 kind, bytes32 under) = authorityOf(vm.getRecordedLogs(), address(participation), sel);
        assertEq(by, A);
        assertEq(uint256(kind), uint256(AIFPBasis.AUTHORITY_CHANNEL));
        assertEq(under, bytes32(0));

        vm.recordLogs();
        exec.grant(ch, subj(B), AIFPRoles.OBSERVE, 0);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(participation), sel);
        assertEq(by, address(exec));
        assertEq(uint256(kind), uint256(AIFPBasis.AUTHORITY_EXECUTOR));
        assertEq(under, bytes32(0));

        vm.recordLogs();
        bytes32 granted = grantRoles(C, ch, B, AIFPRoles.OBSERVE, 0);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(participation), sel);
        assertEq(by, C);
        assertEq(uint256(kind), uint256(AIFPBasis.AUTHORITY_ROLE));
        assertEq(under, managerBid, "the manager's own binding is named");

        // Suspension and revocation by the manager name the same binding (their caller is an indexed topic, so
        // the last three data words are at, kind, binding); an admission names the subject.
        vm.recordLogs();
        vm.prank(C);
        participation.suspend(granted, bytes32("hold"));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint48 at_, uint8 k2, bytes32 u2) = lastThree(logs, address(participation), IAIFPParticipationRegistry.RoleSuspended.selector);
        assertTrue(at_ == now48() && k2 == AIFPBasis.AUTHORITY_ROLE && u2 == managerBid, "suspend");
        vm.recordLogs();
        vm.prank(C);
        participation.revoke(granted, bytes32("end"));
        (at_, k2, u2) = lastThree(vm.getRecordedLogs(), address(participation), IAIFPParticipationRegistry.RoleRevoked.selector);
        assertTrue(at_ == now48() && k2 == AIFPBasis.AUTHORITY_ROLE && u2 == managerBid, "revoke");
        vm.recordLogs();
        vm.prank(B);
        participation.admit(ch, AIFPRoles.SUBMIT, SCOPE_X, openPredicate(), noEvidence(), 0);
        (by, kind, under) = authorityOf(vm.getRecordedLogs(), address(participation), sel);
        assertTrue(by == B && kind == AIFPBasis.AUTHORITY_SUBJECT && under == bytes32(0), "admit");
    }

    /// @dev The manager's binding named in a grant is the one that satisfied the check at that position: a
    ///      grant made at t, followed by the revocation of the manager's binding at t, is authorized by the
    ///      log order although a read at t no longer shows the manager as holding the role.
    function test_manager_binding_named_in_a_grant_survives_its_revocation_in_the_same_timepoint() public {
        bytes32 managerBid = grantRoles(A, ch, C, AIFPRoles.MANAGE_ADMISSION, 0);
        warpBy(5);
        vm.recordLogs();
        grantRoles(C, ch, B, AIFPRoles.OBSERVE, 0);
        vm.prank(A);
        participation.revoke(managerBid, bytes32("end"));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (, uint8 kind, bytes32 under) = authorityOf(logs, address(participation), IAIFPParticipationRegistry.RoleGranted.selector);
        assertTrue(kind == AIFPBasis.AUTHORITY_ROLE && under == managerBid);
        assertOutcome(evalNow(ch, C, AIFPRoles.MANAGE_ADMISSION, 0), N, "the read at t no longer shows it");
        uint256 grantedAt;
        uint256 revokedAt;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(participation)) continue;
            if (logs[i].topics[0] == IAIFPParticipationRegistry.RoleGranted.selector) grantedAt = i;
            if (logs[i].topics[0] == IAIFPParticipationRegistry.RoleRevoked.selector) revokedAt = i;
        }
        assertTrue(grantedAt < revokedAt, "the grant precedes the revocation of its authority");
    }
}
