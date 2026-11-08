// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ScriptBase} from "./ScriptBase.sol";
import {AIFPParadigmRegistry} from "../assets/erc-aifp/contracts/AIFPParadigmRegistry.sol";
import {AIFPChannelRegistry} from "../assets/erc-aifp/contracts/AIFPChannelRegistry.sol";
import {AIFPParticipationRegistry} from "../assets/erc-aifp/contracts/AIFPParticipationRegistry.sol";
import {AIFPSubjectSet} from "../assets/erc-aifp/contracts/AIFPSubjectSet.sol";
import {AIFPEventAnchor} from "../assets/erc-aifp/contracts/AIFPEventAnchor.sol";
import {AIFPObjectionWindow} from "../assets/erc-aifp/contracts/companions/AIFPObjectionWindow.sol";
import {IAIFPParadigmRegistry} from "../assets/erc-aifp/contracts/interfaces/IAIFPParadigmRegistry.sol";
import {IAIFPChannelRegistry} from "../assets/erc-aifp/contracts/interfaces/IAIFPChannelRegistry.sol";
import {IAIFPEventAnchor} from "../assets/erc-aifp/contracts/interfaces/IAIFPEventAnchor.sol";
import {AIFPPredicates} from "../assets/erc-aifp/contracts/libraries/AIFPPredicates.sol";
import {AIFPRoles} from "../assets/erc-aifp/contracts/libraries/AIFPRoles.sol";
import {AIFPBasis} from "../assets/erc-aifp/contracts/libraries/AIFPBasis.sol";
import {AIFPBindings} from "../assets/erc-aifp/contracts/libraries/AIFPBindings.sol";
import {AIFPEvents} from "../assets/erc-aifp/contracts/libraries/AIFPEvents.sol";
import {AIFPSubject} from "../assets/erc-aifp/contracts/libraries/AIFPSubject.sol";

/// @notice On-chain evidence run for boundary cases 1, 4, 5, 8, 9 and 11 in two phases.
///
///   Phase 1 sets everything up and schedules the time-dependent steps AIFP_DELAY seconds ahead (the objection
///   window then runs for another AIFP_DELAY seconds; choose AIFP_DELAY larger than the time the phase-1
///   transactions take to be mined, e.g. 60 on anvil, 900 on Sepolia):
///     AIFP_PHASE=1 AIFP_PK_A=.. AIFP_PK_B=.. AIFP_PK_C=.. AIFP_DELAY=120 \
///       forge script script/Cases.s.sol --rpc-url $RPC --broadcast
///   Phase 2 runs once 2 x AIFP_DELAY seconds have passed on the chain clock:
///     AIFP_PHASE=2 AIFP_PK_A=.. AIFP_PK_B=.. AIFP_PK_C=.. forge script script/Cases.s.sol --rpc-url $RPC --broadcast
///
///   Reads deployments/<chainid>.json (written by Deploy.s.sol); writes deployments/<chainid>.cases.json.
contract Cases is ScriptBase {
    AIFPParadigmRegistry paradigms;
    AIFPChannelRegistry channels;
    AIFPParticipationRegistry participation;
    AIFPEventAnchor anchor;
    AIFPObjectionWindow window;
    AIFPSubjectSet roster;

    uint256 pkA;
    uint256 pkB;
    uint256 pkC;
    address A;
    address B;
    address C;

    // case material
    bytes32 constant LINK_SCOPE = keccak256("link:A:B");
    bytes32 constant BID_B = keccak256("bid:B");
    bytes32 constant BID_C = keccak256("bid:C");
    bytes32 constant AUDIENCE_PUBLIC = keccak256("audience:public");

    string out = "cases";
    string json;

    function run() external {
        _load();
        uint256 phase = vm.envOr("AIFP_PHASE", uint256(1));
        if (phase == 1) _phase1();
        else _phase2();
    }

    // ------------------------------------------------------------------ setup

    function _load() internal {
        string memory d = vm.readFile(deploymentsPath());
        paradigms = AIFPParadigmRegistry(vm.parseJsonAddress(d, ".AIFPParadigmRegistry"));
        channels = AIFPChannelRegistry(vm.parseJsonAddress(d, ".AIFPChannelRegistry"));
        participation = AIFPParticipationRegistry(vm.parseJsonAddress(d, ".AIFPParticipationRegistry"));
        anchor = AIFPEventAnchor(vm.parseJsonAddress(d, ".AIFPEventAnchor"));
        window = AIFPObjectionWindow(vm.parseJsonAddress(d, ".AIFPObjectionWindow"));
        roster = AIFPSubjectSet(vm.parseJsonAddress(d, ".AIFPSubjectSet"));
        pkA = vm.envUint("AIFP_PK_A");
        pkB = vm.envUint("AIFP_PK_B");
        pkC = vm.envUint("AIFP_PK_C");
        A = vm.addr(pkA);
        B = vm.addr(pkB);
        C = vm.addr(pkC);
    }

    function openPredicate() internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.OPEN, childStart: 0, childCount: 0, verifier: address(0), ref: 0, params: ""});
        return abi.encode(nodes);
    }

    function allowlistPredicate(address set) internal pure returns (bytes memory) {
        AIFPPredicates.Node[] memory nodes = new AIFPPredicates.Node[](1);
        nodes[0] = AIFPPredicates.Node({kind: AIFPPredicates.ALLOWLIST, childStart: 0, childCount: 0, verifier: set, ref: 0, params: ""});
        return abi.encode(nodes);
    }

    function pred(uint16 role, bytes memory p) internal pure returns (IAIFPParadigmRegistry.RolePredicate[] memory preds) {
        preds = new IAIFPParadigmRegistry.RolePredicate[](1);
        preds[0] = IAIFPParadigmRegistry.RolePredicate({role: role, predicateHash: keccak256(p)});
    }

    function preds2(uint16 r1, bytes memory p1, uint16 r2, bytes memory p2) internal pure returns (IAIFPParadigmRegistry.RolePredicate[] memory preds) {
        preds = new IAIFPParadigmRegistry.RolePredicate[](2);
        preds[0] = IAIFPParadigmRegistry.RolePredicate({role: r1, predicateHash: keccak256(p1)});
        preds[1] = IAIFPParadigmRegistry.RolePredicate({role: r2, predicateHash: keccak256(p2)});
    }

    function labels1(string memory l) internal pure returns (bytes32[] memory out_) {
        out_ = new bytes32[](1);
        out_[0] = keccak256(bytes(l));
    }

    function register(string memory descriptor, string memory family, bytes32 supersedes, string memory label, IAIFPParadigmRegistry.RolePredicate[] memory preds)
        internal
        returns (bytes32)
    {
        return paradigms.registerParadigm(bytes(descriptor), keccak256(bytes(family)), supersedes, labels1(label), preds, "");
    }

    function open(bytes32 paradigmId, string memory name) internal returns (bytes32) {
        IAIFPChannelRegistry.BindingDecl[] memory none = new IAIFPChannelRegistry.BindingDecl[](0);
        return channels.openChannel(paradigmId, A, bytes32(0), name, none);
    }

    function grant(bytes32 ch, address to, uint16 roles, bytes32 scope) internal returns (bytes32) {
        return participation.grant(ch, AIFPSubject.self(to), bytes32(0), roles, scope, AIFPBasis.MANAGER_GRANT, bytes32(0), 0, 0);
    }

    function rel(uint8 kind, bytes32 ref) internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](1);
        r[0] = IAIFPEventAnchor.Relation({kind: kind, objectRef: ref});
    }

    function noRel() internal pure returns (IAIFPEventAnchor.Relation[] memory r) {
        r = new IAIFPEventAnchor.Relation[](0);
    }

    function noEvidence() internal pure returns (bytes[] memory ev) {
        ev = new bytes[](0);
    }

    function put(string memory key, bytes32 v) internal {
        json = vm.serializeBytes32(out, key, v);
    }

    function putU(string memory key, uint256 v) internal {
        json = vm.serializeUint(out, key, v);
    }

    // ------------------------------------------------------------------ phase 1

    // Script-contract storage keeps the identifiers out of the stack.
    bytes32 pDirect;
    bytes32 pPanel;
    bytes32 pClub;
    bytes32 pIntake;
    bytes32 pMeeting;
    bytes32 pSource;
    bytes32 pRulesV1;
    bytes32 pRulesV2;
    bytes32 link;
    bytes32 talk;
    bytes32 tender;
    bytes32 rules;
    bytes32 room;
    bytes32 bulletin;
    bytes32 council;
    bytes32 bPanelist;
    bytes32 cObserver;
    bytes32 bLink;
    bytes32 bRules;
    bytes32 commitB;
    bytes32 commitC;
    bytes32 postA;
    bytes32 postB;
    bytes32 summary;
    uint256 windowId;
    uint48 effectiveAt;

    uint48 delay;

    function _phase1() internal {
        delay = uint48(vm.envOr("AIFP_DELAY", uint256(120)));
        effectiveAt = uint48(block.timestamp) + delay;
        _phase1A();
        _phase1B();
        _phase1C();
        _phase1Write();
    }

    function _phase1A() internal {
        vm.startBroadcast(pkA);
        pDirect = register("{aifp:direct}", "aifp.cases.direct", 0, "aifp:paradigm/direct/v1", pred(AIFPRoles.RESPOND, allowlistPredicate(address(roster))));
        pPanel = register("{aifp:panel}", "aifp.cases.talk", 0, "aifp:paradigm/panel/v1", pred(AIFPRoles.OBSERVE, openPredicate()));
        pClub = register("{aifp:club}", "aifp.cases.talk", pPanel, "aifp:paradigm/club/v1", preds2(AIFPRoles.OBSERVE, openPredicate(), AIFPRoles.SUBMIT, openPredicate()));
        pIntake = register("{aifp:intake}", "aifp.cases.tender", 0, "aifp:paradigm/intake/v1", pred(AIFPRoles.SUBMIT, openPredicate()));
        pMeeting = register("{aifp:meeting}", "aifp.cases.room", 0, "aifp:paradigm/meeting/v1", new IAIFPParadigmRegistry.RolePredicate[](0));
        pSource = register("{aifp:source}", "aifp.cases.bulletin", 0, "aifp:paradigm/source/v1", pred(AIFPRoles.OBSERVE, openPredicate()));
        pRulesV1 = register("{aifp:rules:v1}", "aifp.cases.rules", 0, "aifp:paradigm/club/v1", pred(AIFPRoles.SUBMIT, openPredicate()));
        pRulesV2 = register("{aifp:rules:v2}", "aifp.cases.rules", pRulesV1, "aifp:paradigm/club/v1", pred(AIFPRoles.SUBMIT, allowlistPredicate(address(roster))));

        link = open(pDirect, "case1:link");
        talk = open(pPanel, "case4:talk");
        tender = open(pIntake, "case5:tender");
        rules = open(pRulesV1, "case8:rules");
        room = open(pMeeting, "case9:room");
        bulletin = open(pSource, "case9:bulletin");
        council = open(pPanel, "case11:council");

        // case 1: A's side of the handshake
        grant(link, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE, LINK_SCOPE);
        roster.add(AIFPSubject.self(B));
        grant(link, B, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, LINK_SCOPE);
        // case 4: panelist B, change scheduled with re-admission
        bPanelist = grant(talk, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, bytes32(0));
        channels.adoptParadigm(talk, pClub, effectiveAt, true, keccak256("decision:open-the-floor"));
        // case 5: collector and lanes
        grant(tender, A, AIFPRoles.OBSERVE | AIFPRoles.SUBMIT, bytes32(0));
        grant(tender, B, AIFPRoles.OBSERVE, BID_B);
        grant(tender, C, AIFPRoles.OBSERVE, BID_C);
        // case 8: tightened rules scheduled
        channels.adoptParadigm(rules, pRulesV2, effectiveAt, false, keccak256("rules-tightened"));
        // case 9: closed room and public bulletin
        grant(room, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE, bytes32(0));
        grant(room, B, AIFPRoles.SUBMIT | AIFPRoles.RESPOND | AIFPRoles.OBSERVE | AIFPRoles.REDISTRIBUTE | AIFPRoles.MANAGE_DISCLOSURE, bytes32(0));
        grant(bulletin, C, AIFPRoles.SUBMIT, bytes32(0));
        grant(bulletin, B, AIFPRoles.REDISTRIBUTE, bytes32(0));
        postA = keccak256("A: ship in Q1");
        anchor.anchor(room, AIFPEvents.ACTION_PUBLISH, postA, noRel());
        // case 11: council with an objection window closing at effectiveAt
        grant(council, A, AIFPRoles.SUBMIT | AIFPRoles.RESPOND, bytes32(0));
        grant(council, B, AIFPRoles.RESPOND, bytes32(0));
        grant(council, C, AIFPRoles.RESPOND, bytes32(0));
        // The window opens when the scheduled changes take effect and closes one delay later, so that every
        // phase-1 transaction is mined before the window starts (on a live chain set AIFP_DELAY well above the
        // time the phase-1 transactions take, e.g. 900 seconds on Sepolia).
        windowId = window.open(council, keccak256("proposal: rotate the sequencer"), effectiveAt, effectiveAt + delay, AIFPRoles.RESPOND);
        vm.stopBroadcast();
    }

    function _phase1B() internal {
        vm.startBroadcast(pkB);
        bLink = participation.admit(link, AIFPRoles.RESPOND, LINK_SCOPE, allowlistPredicate(address(roster)), noEvidence(), 0);
        participation.admit(tender, AIFPRoles.SUBMIT, bytes32(0), openPredicate(), noEvidence(), 0);
        commitB = keccak256(abi.encode("commit", keccak256(abi.encode("B", 1000, "salt-b"))));
        anchor.anchor(tender, AIFPEvents.ACTION_SUBMIT, commitB, noRel());
        bRules = participation.admit(rules, AIFPRoles.SUBMIT, bytes32(0), openPredicate(), noEvidence(), 0);
        anchor.anchor(rules, AIFPEvents.ACTION_PUBLISH, keccak256("B: post under v1"), noRel());
        postB = keccak256("B: only if the audit is done");
        anchor.anchor(room, AIFPEvents.ACTION_RESPOND, postB, rel(AIFPEvents.REL_REPLY_TO, postA));
        anchor.anchor(bulletin, AIFPEvents.ACTION_FORWARD, postA, rel(AIFPEvents.REL_FORWARDS, postA));
        summary = keccak256("Summary: Q1 target conditional on audit");
        anchor.anchor(bulletin, AIFPEvents.ACTION_DERIVE, summary, rel(AIFPEvents.REL_DERIVES_FROM, postB));
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_DISCLOSED, summary, AUDIENCE_PUBLIC, keccak256("minutes-approved"));
        vm.stopBroadcast();
    }

    function _phase1C() internal {
        vm.startBroadcast(pkC);
        cObserver = participation.admit(talk, AIFPRoles.OBSERVE, bytes32(0), openPredicate(), noEvidence(), 0);
        participation.admit(tender, AIFPRoles.SUBMIT, bytes32(0), openPredicate(), noEvidence(), 0);
        commitC = keccak256(abi.encode("commit", keccak256(abi.encode("C", 900, "salt-c"))));
        anchor.anchor(tender, AIFPEvents.ACTION_SUBMIT, commitC, noRel());
        vm.stopBroadcast();
    }

    function _phase1Write() internal {
        put("pDirect", pDirect);
        put("pPanel", pPanel);
        put("pClub", pClub);
        put("pIntake", pIntake);
        put("pMeeting", pMeeting);
        put("pSource", pSource);
        put("pRulesV1", pRulesV1);
        put("pRulesV2", pRulesV2);
        put("link", link);
        put("talk", talk);
        put("tender", tender);
        put("rules", rules);
        put("room", room);
        put("bulletin", bulletin);
        put("council", council);
        put("bPanelist", bPanelist);
        put("cObserver", cObserver);
        put("bLink", bLink);
        put("bRules", bRules);
        put("commitB", commitB);
        put("commitC", commitC);
        put("postA", postA);
        put("summary", summary);
        putU("windowId", windowId);
        putU("effectiveAt", effectiveAt);
        putU("windowDeadline", effectiveAt + delay);
        putU("phase1At", block.timestamp);
        vm.writeJson(json, casesPath());
    }

    // ------------------------------------------------------------------ phase 2

    function _phase2() internal {
        string memory s = vm.readFile(casesPath());
        talk = vm.parseJsonBytes32(s, ".talk");
        tender = vm.parseJsonBytes32(s, ".tender");
        rules = vm.parseJsonBytes32(s, ".rules");
        room = vm.parseJsonBytes32(s, ".room");
        bPanelist = vm.parseJsonBytes32(s, ".bPanelist");
        cObserver = vm.parseJsonBytes32(s, ".cObserver");
        bRules = vm.parseJsonBytes32(s, ".bRules");
        commitB = vm.parseJsonBytes32(s, ".commitB");
        commitC = vm.parseJsonBytes32(s, ".commitC");
        summary = vm.parseJsonBytes32(s, ".summary");
        windowId = vm.parseJsonUint(s, ".windowId");
        effectiveAt = uint48(vm.parseJsonUint(s, ".effectiveAt"));
        require(block.timestamp >= vm.parseJsonUint(s, ".windowDeadline"), "phase 2: wait until the objection window has closed");

        // Pre-state read-outs (history vs present).
        uint8 bPendingNow = participation.evaluate(talk, AIFPSubject.self(B), AIFPRoles.SUBMIT, bytes32(0), uint48(block.timestamp));
        uint8 bHistory = participation.evaluate(talk, AIFPSubject.self(B), AIFPRoles.SUBMIT, bytes32(0), uint48(effectiveAt - 1));
        bool oldRuleRejected;
        try participation.previewAdmission(rules, AIFPSubject.self(C), AIFPRoles.SUBMIT, bytes32(0), openPredicate(), noEvidence()) returns (uint8) {
            oldRuleRejected = false;
        } catch {
            oldRuleRejected = true;
        }

        // ---- A: confirm the panelist, admit C to the roster of the tightened rules, revoke B, restrict the summary
        vm.startBroadcast(pkA);
        participation.confirmReadmission(bPanelist);
        roster.add(AIFPSubject.self(C));
        participation.revoke(bRules, keccak256("rules tightened: B re-applies under v2"));
        channels.recordDisclosure(room, AIFPBindings.DISCLOSURE_RESTRICTED, summary, AUDIENCE_PUBLIC, keccak256("retracted-minutes"));
        uint8 windowStatus = window.resolve(windowId);
        vm.stopBroadcast();

        // ---- B: reveal its bid
        vm.startBroadcast(pkB);
        anchor.anchor(tender, AIFPEvents.ACTION_SUPERSEDE, keccak256(abi.encode("B", 1000, "salt-b")), rel(AIFPEvents.REL_SUPERSEDES, commitB));
        vm.stopBroadcast();

        // ---- C: take the floor by rule, re-prove observation, enter the tightened rules, reveal its bid
        vm.startBroadcast(pkC);
        bytes32 cSubmit = participation.admit(talk, AIFPRoles.SUBMIT, bytes32(0), openPredicate(), noEvidence(), 0);
        participation.readmit(cObserver, openPredicate(), noEvidence());
        bytes32 cRules = participation.admit(rules, AIFPRoles.SUBMIT, bytes32(0), allowlistPredicate(address(roster)), noEvidence(), 0);
        anchor.anchor(tender, AIFPEvents.ACTION_SUPERSEDE, keccak256(abi.encode("C", 900, "salt-c")), rel(AIFPEvents.REL_SUPERSEDES, commitC));
        vm.stopBroadcast();

        // Post-state read-outs.
        uint8 bRulesHistory = participation.evaluate(rules, AIFPSubject.self(B), AIFPRoles.SUBMIT, bytes32(0), uint48(effectiveAt - 1));
        uint8 bRulesNow = participation.evaluate(rules, AIFPSubject.self(B), AIFPRoles.SUBMIT, bytes32(0), uint48(block.timestamp));

        json = s;
        out = "cases2";
        put("cSubmit", cSubmit);
        put("cRules", cRules);
        putU("phase2At", block.timestamp);
        putU("windowStatus", windowStatus); // 1 = DEFAULT_TRIGGERED (no objection registered), 2 = OBJECTED, 3 = UNDETERMINABLE
        putU("case4.bPendingBeforeConfirm", bPendingNow); // expected 2 = UNDETERMINABLE
        putU("case4.bHistoryBeforeChange", bHistory); // expected 0 = SATISFIED
        putU("case8.oldRuleRejectedAfterChange", oldRuleRejected ? 1 : 0); // expected 1
        putU("case8.bHistoryUnderV1", bRulesHistory); // expected 0 = SATISFIED
        putU("case8.bNowAfterRevocation", bRulesNow); // expected 1 = NOT_SATISFIED
        putU("case9.disclosureRecords", channels.disclosureCount(room)); // expected 2 (DISCLOSED then RESTRICTED)
        vm.writeJson(json, string(abi.encodePacked("deployments/", vm.toString(block.chainid), ".cases.phase2.json")));
    }
}
