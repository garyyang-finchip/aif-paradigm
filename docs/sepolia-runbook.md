# Sepolia evidence runbook

Goal: deploy the reference stack on Sepolia and run boundary cases 1, 4, 5, 8, 9 and 11 on-chain with three
actors (A authority / cell A, B cell B, C third participant), leaving a reproducible record under
`deployments/`.

## Prerequisites

- Foundry 1.x (`forge`, `cast`), a Sepolia RPC URL, and three funded keys. A needs about 0.03 Sepolia ETH
  (deployment plus roughly 30 transactions); B and C need about 0.005 each. One faucet grant to A and two
  `cast send` transfers from A to B and C is enough:

```
export RPC=https://<sepolia-rpc>
export AIFP_PK_A=0x... AIFP_PK_B=0x... AIFP_PK_C=0x...
cast send --rpc-url $RPC --private-key $AIFP_PK_A $(cast wallet address --private-key $AIFP_PK_B) --value 0.005ether
cast send --rpc-url $RPC --private-key $AIFP_PK_A $(cast wallet address --private-key $AIFP_PK_C) --value 0.005ether
```

- Gas: take limits from live estimation; the scripts use `--slow` on public RPCs so that nonces stay in
  order across the three actors.

## 1. Deploy

```
forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --private-key $AIFP_PK_A --slow
```

Writes `deployments/11155111.json` with the addresses of `AIFPParadigmRegistry`, `AIFPCompositeVerifier`,
`AIFPChannelRegistry`, `AIFPParticipationRegistry`, `AIFPEventAnchor`, `AIFPObjectionWindow` and the
`AIFPSubjectSet` roster, plus the deployer and block numbers.

## 2. Phase 1 of the cases

```
AIFP_PHASE=1 AIFP_DELAY=900 forge script script/Cases.s.sol --rpc-url $RPC --broadcast --slow
```

Phase 1 registers the paradigms, opens the channels, grants and admits roles, anchors the sealed-bid
commitments and the blackboard versions, schedules the panel-to-club adoption and the rule update
`AIFP_DELAY` seconds ahead, and opens the objection window. `AIFP_DELAY=900` leaves room for the ~45
phase-1 transactions to be mined before the scheduled timepoints.

## 3. Phase 2 of the cases

After at least `2 x AIFP_DELAY` seconds of chain time:

```
AIFP_PHASE=2 forge script script/Cases.s.sol --rpc-url $RPC --broadcast --slow
```

Phase 2 reveals the bids, re-admits and confirms the pending bindings, replays the old predicate (expected to
be rejected), records the disclosure and the restriction, and resolves the objection window. It writes
`deployments/11155111.cases.phase2.json` with the read-outs (expected: case 4 pending bindings confirmed,
case 8 old rule rejected and history unchanged, case 9 two disclosure records, case 11 window status
`DEFAULT_TRIGGERED`).

## 4. Verify and record

```
forge verify-contract --chain sepolia --verifier sourcify <address> <Contract>   # for each deployed contract
```

Commit `deployments/11155111*.json` and summarize the run in `docs/sepolia-evidence.md`: addresses, source
version, runtime code hashes, transaction list with block numbers, and the Sourcify match status. The
Magicians thread gets a short reply pointing to that file.

## Run record

The run of 2026-11-08 is recorded in `docs/sepolia-evidence.md`. Two observations from it that matter for a
repeat: Sepolia's `eth_estimateGas` for contract creation was about 5.35 times the local Anvil figure (take gas
limits from the network, never from a local estimate), and the network did not enforce a per-transaction gas
cap at 2^24, so `AIFPParticipationRegistry` deploys in one transaction (21.5M gas). `AIFP_DELAY=3000` left a
comfortable margin for the ~45 phase-1 transactions.

## Notes

- The scripts are the same ones rehearsed on a local anvil (`anvil --port 8545`, then the commands above with
  `--rpc-url http://127.0.0.1:8545` and `AIFP_DELAY=60`; advance the clock with `cast rpc evm_increaseTime`).
- Keys used for the evidence run are throwaway; channel authority and family control stay on key A unless
  transferred with `transferAuthority` / `transferFamily` after the run.
