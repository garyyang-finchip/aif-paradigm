# Deployments

Evidence records written by `script/Deploy.s.sol` (`<chainid>.json`) and `script/Cases.s.sol`
(`<chainid>.cases.json`, `<chainid>.cases.phase2.json`). The Sepolia run (chain id 11155111) is recorded in
`11155111.json` (addresses, deploy transactions, gas, runtime code hashes), `11155111.cases.json` (phase-1
identifiers and timepoints) and `11155111.cases.phase2.json` (phase-2 read-outs); `docs/sepolia-evidence.md`
summarizes it. Timestamps in these files are the Sepolia block timestamps of the recorded transactions.

The three files at the top level describe the v0.1.3 stack deployed on 2026-11-14. The records of the v0.1.1 stack
deployed on 2026-11-08 (still on chain) are kept unchanged under `archive/v0.1.1/`, summarized in
`docs/sepolia-evidence-v0.1.1.md`.
