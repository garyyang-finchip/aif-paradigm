# Pull request description (draft for ethereum/ERCs)

Title: Add ERC: Agent Information Flow Paradigm

---

This PR adds a new draft ERC, **Agent Information Flow Paradigm (AIFP)**: versioned, composable rules for how
agents provide, observe and redistribute information in a channel, with scoped role bindings and
four-valued verification.

**Scope.** Three registries (paradigms, channels, participation), a predicate verifier interface, canonical
descriptor and subject-reference encodings, and optional profiles for event anchoring and absence
semantics. Transport is out of scope and attaches through declared bindings. `requires: 165, 6372`.

**Assets.** `assets/erc-9999/` holds the interfaces and reference implementation (Solidity 0.8.28), the
descriptor and predicate JSON schemas, 17 example descriptors, and vectors (subject references, predicate
encodings, outcome tables, interface identifiers, paradigm identifiers). The Test Cases section of the ERC is
self-contained and reproduces the key vectors inline.

**Discussion.** Ethereum Magicians thread: https://ethereum-magicians.org/t/draft-erc-agent-information-flow-paradigm-aifp-versioned-composable-rules-for-how-agents-provide-observe-and-redistribute-information/30300

**Repository.** Reference repository with the Foundry suite (152 tests, 12 boundary cases), the canonical
validator and the evidence scripts: https://github.com/garyyang-finchip/aif-paradigm
