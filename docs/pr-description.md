# Pull request description (ethereum/ERCs pull request #2152)

Title: Add ERC-8489: Agent Information Flow Paradigm

The pull request was opened under the placeholder number 9999 with the title "Add ERC: Agent Information Flow
Paradigm"; the editors assigned ERC-8489 on 2026-11-09 and the file, the assets directory, the title and the
text below were renumbered accordingly.

---

This PR adds a new draft ERC, **ERC-8489: Agent Information Flow Paradigm (AIFP)**: versioned, composable rules
for how agents provide, observe and redistribute information in a channel, with scoped role bindings and
four-valued verification. For readers who come from agent communication protocols, the ERC can be read in
that vocabulary: those protocols carry the messages and attach to a channel as transport bindings, and AIFP
records who may observe, contribute and redistribute in that context, under which version of the rules. This
is a reading aid, not a redefinition.

**Scope.** Three registries (paradigms, channels, participation), a predicate verifier interface, canonical
descriptor and subject-reference encodings, and optional profiles for event anchoring and absence
semantics. Transport is out of scope and attaches through declared bindings. `requires: 165, 6372`.

**Assets.** `assets/erc-8489/` holds the interfaces and reference implementation (Solidity 0.8.28), the
descriptor and predicate JSON schemas, 17 example descriptors, and vectors (subject references, predicate
encodings, outcome tables, interface identifiers, paradigm identifiers). The Test Cases section of the ERC is
self-contained and reproduces the key vectors inline.

**Discussion.** Ethereum Magicians thread: https://ethereum-magicians.org/t/erc-8489-agent-information-flow-paradigm/30300

**Repository.** Reference repository with the Foundry suite (226 tests, 12 boundary cases), the canonical
validator, the evidence scripts and the Sepolia evidence run: https://github.com/garyyang-finchip/aif-paradigm
