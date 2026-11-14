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
  order across the three actors. Since v0.1.3 an admission checks, before each leaf call, that the fixed leaf
  bound (`leafGasLimit()`, 1,000,000 in the reference build) plus a margin is still available, and reverts with
  `AIFP_InsufficientGas` otherwise. `eth_estimateGas` finds the limit that satisfies this check (the gas is
  checked, not consumed), but Foundry's broadcast multiplies the *consumed* gas by 130 percent by default, which
  is far below it. Run `script/Cases.s.sol` with `--gas-estimate-multiplier 400` or more, or set the limit per
  transaction from `eth_estimateGas`; a limit of 3,000,000 was ample for every case call on Sepolia.

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
phase-1 transactions to be mined before the scheduled timepoints when the script broadcasts directly. Every
phase-1 transaction has to be mined before `effectiveAt`: the scheduled adoptions and the window opening
reject a timepoint in the past, and the admissions of B under the panel and the v1 rules are evaluated against
the paradigm in force when they are mined, so an admission that lands after the switch fails with
`AIFP_PredicateMismatch`. If the transactions are relayed by hand or through an unreliable connection, choose
`AIFP_DELAY` well above the time the relay can take (3,600 seconds was used for the v0.1.3 run) and, if the
deadline is missed, rerun phase 1 from the first case transaction with the same deployment: the deployment
itself does not depend on the clock.

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

## Run records

The run of 2026-11-08 (v0.1.1 build) is recorded in `docs/sepolia-evidence-v0.1.1.md`, the run of 2026-11-14
(v0.1.3 build) in `docs/sepolia-evidence.md`. Observations that matter for a repeat: Sepolia's `eth_estimateGas`
for contract creation was about 5.35 times the local Anvil figure (take gas limits from the network, never from
a local estimate); the network did not enforce a per-transaction gas cap at 2^24, so
`AIFPParticipationRegistry` deploys in one transaction (21.7M gas); the v0.1.3 admissions need a gas limit
above Foundry's default estimate (see Prerequisites); and a phase-1 relay that overran `AIFP_DELAY` cost one
abandoned attempt (see the v0.1.3 record), so the second attempt used `AIFP_DELAY=3600`.

## Notes

- The scripts are the same ones rehearsed on a local anvil (`anvil --port 8545`, then the commands above with
  `--rpc-url http://127.0.0.1:8545` and `AIFP_DELAY=60`; advance the clock with `cast rpc evm_increaseTime`).
- Keys used for the evidence run are throwaway; channel authority and family control stay on key A unless
  transferred with `transferAuthority` / `transferFamily` after the run.
