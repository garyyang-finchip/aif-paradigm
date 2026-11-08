#!/usr/bin/env node
// Regenerates assets/erc-aifp/vectors/*.json from the examples, the libraries in tools/lib and the
// compiled interface ABIs under out/ (run `forge build` first for interface-ids.json).
//
//   node tools/make-vectors.mjs [--skip-interfaces]

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { Interface } from "ethers";
import { REPO_ROOT, validateFile } from "./lib/validate.mjs";
import { compile, describeNodes } from "./lib/predicates.mjs";
import { canonicalAddress, canonicalERC8004, canonicalDID, canonicalExt, refOf } from "./lib/subject.mjs";

const EX = join(REPO_ROOT, "assets", "erc-aifp", "examples");
const OUT = join(REPO_ROOT, "assets", "erc-aifp", "vectors");
const BUILD = join(REPO_ROOT, "out");
mkdirSync(OUT, { recursive: true });

const skipInterfaces = process.argv.includes("--skip-interfaces");

function writeJson(name, data) {
  writeFileSync(join(OUT, name), JSON.stringify(data, null, 2) + "\n");
  console.log("wrote", join("assets/erc-aifp/vectors", name));
}

// ---------------------------------------------------------------- paradigm ids
const exampleFiles = [];
for (const dir of ["paradigms", "composites"]) {
  for (const f of readdirSync(join(EX, dir)).filter((n) => n.endsWith(".json")).sort()) exampleFiles.push(join(dir, f));
}
const paradigmVectors = [];
for (const rel of exampleFiles) {
  const r = validateFile(join(EX, rel));
  if (!r.ok) {
    console.error(`example ${rel} is invalid:\n  ${r.errors.join("\n  ")}`);
    process.exit(1);
  }
  const b = r.bundle;
  paradigmVectors.push({
    file: `examples/${rel}`,
    family: b.family,
    familyId: b.familyId,
    labels: b.labels,
    labelIds: b.labelIds,
    canonical: b.canonical,
    paradigmId: b.paradigmId,
    rolePredicates: b.rolePredicates.map((p) => ({ role: p.role, roleBit: p.roleBit, nodeCount: p.nodeCount, predicateHex: p.predicateHex, predicateHash: p.predicateHash })),
  });
}
writeJson("paradigm-ids.json", {
  description: "paradigmId = keccak256(utf8(JCS canonical descriptor)); familyId = keccak256(utf8(family)); labelId = keccak256(utf8(label)); predicateHash = keccak256(abi.encode(Node[])).",
  count: paradigmVectors.length,
  vectors: paradigmVectors,
});

// ---------------------------------------------------------------- subject refs
const subjectCases = [
  { kind: "eip155-address", chainId: 1, address: "0x0000000000000000000000000000000000000001" },
  { kind: "eip155-address", chainId: 11155111, address: "0x0000000000000000000000000000000000000001" },
  { kind: "eip155-address", chainId: 1, address: "0xAbCDef0123456789aBCDeF0123456789AbCdEf01" },
  { kind: "eip155-address", chainId: 11155111, address: "0xAbCDef0123456789aBCDeF0123456789AbCdEf01" },
  { kind: "erc8004", chainId: 11155111, registry: "0x8004A818BFB912233c491871b3d84c89A494BD9e", agentId: 10387 },
  { kind: "did", method: "aid", id: "example-7" },
  { kind: "ext", namespace: "finchip.ai", identifier: "foga-cell-7" },
];
const subjectVectors = subjectCases.map((c) => {
  let canonical;
  if (c.kind === "eip155-address") canonical = canonicalAddress(c.chainId, c.address);
  else if (c.kind === "erc8004") canonical = canonicalERC8004(c.chainId, c.registry, c.agentId);
  else if (c.kind === "did") canonical = canonicalDID(c.method, c.id);
  else canonical = canonicalExt(c.namespace, c.identifier);
  return { ...c, canonical, ref: refOf(canonical) };
});
writeJson("subject-refs.json", {
  description: "subjectRef = keccak256(utf8(canonical)); canonical = <scheme>:<domain>:<identifier> with lowercase hex addresses and decimal integers.",
  count: subjectVectors.length,
  vectors: subjectVectors,
});

// ---------------------------------------------------------------- predicate encodings
const A1 = "0x0000000000000000000000000000000000000001";
const A2 = "0x0000000000000000000000000000000000000002";
const A3 = "0x0000000000000000000000000000000000000003";
const A5 = "0x0000000000000000000000000000000000000005";
const SCHEME = "0xc3d44c830a5c118f980f48317b97e9eaa920a7bbd204c7d3595ac191d4726764";
const predicateCases = [
  { name: "open", json: { open: true } },
  { name: "allowlist", json: { allowlist: { set: A1 } } },
  { name: "external-with-ref", json: { external: { verifier: A2, ref: SCHEME, params: "0x1234" } } },
  { name: "credential-attested", json: { credential: { verifier: A1, scheme: SCHEME, minLevel: 2, proofMode: "attested" } } },
  { name: "credential-proved-fresh", json: { credential: { verifier: A1, scheme: SCHEME, minLevel: 4, proofMode: "proved", freshnessSeconds: 86400, issuers: [A2, A3] } } },
  { name: "stake-native-lockup", json: { stake: { verifier: A5, chain: "eip155:11155111", contract: A5, asset: "native", minAmount: "1000000000000000", period: "lockup" } } },
  { name: "identity-active", json: { identity: { verifier: A2, registry: A3, requiredState: "active" } } },
  { name: "member", json: { member: { verifier: A2, group: "0x" + "11".repeat(32) } } },
  { name: "decision", json: { decision: { verifier: A2, decision: "0x" + "22".repeat(32) } } },
  { name: "allOf-two-leaves", json: { allOf: [{ credential: { verifier: A1, scheme: SCHEME, minLevel: 1, proofMode: "attested" } }, { identity: { verifier: A2, registry: A3, requiredState: "active" } }] } },
  { name: "anyOf-two-leaves", json: { anyOf: [{ identity: { verifier: A2, registry: A3, requiredState: "active" } }, { credential: { verifier: A1, scheme: SCHEME, minLevel: 1, proofMode: "proved" } }] } },
  {
    name: "nested-allOf-anyOf",
    json: {
      allOf: [
        { allowlist: { set: A1 } },
        { anyOf: [{ open: true }, { external: { verifier: A2 } }] },
        { anyOf: [{ member: { verifier: A2, group: "0x" + "11".repeat(32) } }, { allOf: [{ stake: { verifier: A5, chain: "eip155:1", contract: A5, asset: A3, minAmount: "5", period: "active" } }, { decision: { verifier: A2, decision: "0x" + "22".repeat(32) } }] }] },
      ],
    },
  },
];
const predicateVectors = predicateCases.map((c) => {
  const { nodes, encoding, hash } = compile(c.json);
  return { name: c.name, json: c.json, nodes: describeNodes(nodes), encoding, predicateHash: hash };
});
writeJson("predicate-encoding.json", {
  description: "Breadth-first allocation of child blocks; encoding = abi.encode(tuple(uint8 kind,uint8 childStart,uint8 childCount,address verifier,bytes32 ref,bytes params)[]); predicateHash = keccak256(encoding).",
  kinds: { open: 0, allowlist: 1, external: 2, allOf: 3, anyOf: 4, credential: 5, stake: 6, identity: 7, member: 8, decision: 9 },
  count: predicateVectors.length,
  vectors: predicateVectors,
});

// ---------------------------------------------------------------- outcome tables
const OUTCOME = { SATISFIED: 0, NOT_SATISFIED: 1, UNDETERMINABLE: 2, VERIFIER_ERROR: 3 };
const NAMES = Object.fromEntries(Object.entries(OUTCOME).map(([k, v]) => [v, k]));
const norm = (o) => (o > 3 ? 3 : o);
function allOf(list) {
  let und = false;
  let err = false;
  for (const raw of list) {
    const o = norm(raw);
    if (o === 1) return 1;
    if (o === 2) und = true;
    else if (o === 3) err = true;
  }
  if (und) return 2;
  if (err) return 3;
  return 0;
}
function anyOf(list) {
  let und = false;
  let err = false;
  for (const raw of list) {
    const o = norm(raw);
    if (o === 0) return 0;
    if (o === 2) und = true;
    else if (o === 3) err = true;
  }
  if (und) return 2;
  if (err) return 3;
  return 1;
}
const pairs = [];
for (let a = 0; a < 4; a++) for (let b = 0; b < 4; b++) pairs.push([a, b]);
const triples = [
  [0, 0, 0],
  [1, 2, 3],
  [3, 2, 1],
  [0, 2, 3],
  [2, 3, 0],
  [1, 1, 3],
  [3, 3, 3],
  [2, 2, 2],
  [0, 1, 2],
];
const outcomeVectors = [...pairs, ...triples].map((inputs) => ({
  inputs,
  inputNames: inputs.map((i) => NAMES[i]),
  allOf: allOf(inputs),
  anyOf: anyOf(inputs),
  allOfName: NAMES[allOf(inputs)],
  anyOfName: NAMES[anyOf(inputs)],
}));
writeJson("outcome-tables.json", {
  description: "allOf precedence NOT_SATISFIED > UNDETERMINABLE > VERIFIER_ERROR > SATISFIED; anyOf precedence SATISFIED > UNDETERMINABLE > VERIFIER_ERROR > NOT_SATISFIED; values above 3 normalize to VERIFIER_ERROR; empty lists are rejected.",
  outcomes: OUTCOME,
  count: outcomeVectors.length,
  vectors: outcomeVectors,
});

// ---------------------------------------------------------------- interface ids
if (!skipInterfaces) {
  const interfaces = ["IAIFPParadigmRegistry", "IAIFPChannelRegistry", "IAIFPParticipationRegistry", "IAIFPCompositeVerifier", "IAIFPPredicateVerifier", "IAIFPSubjectSet", "IAIFPEventAnchor"];
  const files = {
    IAIFPParadigmRegistry: "IAIFPParadigmRegistry.sol",
    IAIFPChannelRegistry: "IAIFPChannelRegistry.sol",
    IAIFPParticipationRegistry: "IAIFPParticipationRegistry.sol",
    IAIFPCompositeVerifier: "IAIFPPredicateVerifier.sol",
    IAIFPPredicateVerifier: "IAIFPPredicateVerifier.sol",
    IAIFPSubjectSet: "IAIFPPredicateVerifier.sol",
    IAIFPEventAnchor: "IAIFPEventAnchor.sol",
  };
  const ifaceVectors = [];
  for (const name of interfaces) {
    const artifact = join(BUILD, files[name], `${name}.json`);
    if (!existsSync(artifact)) {
      console.error(`missing artifact ${artifact}; run forge build first (or pass --skip-interfaces)`);
      process.exit(1);
    }
    const abi = JSON.parse(readFileSync(artifact, "utf8")).abi;
    const iface = new Interface(abi);
    let acc = 0n;
    const functions = [];
    iface.forEachFunction((fn) => {
      functions.push({ signature: fn.format("sighash"), selector: fn.selector });
      acc ^= BigInt(fn.selector);
    });
    functions.sort((a, b) => a.signature.localeCompare(b.signature));
    ifaceVectors.push({ name, interfaceId: "0x" + acc.toString(16).padStart(8, "0"), functionCount: functions.length, functions });
  }
  writeJson("interface-ids.json", {
    description: "ERC-165 interface id = XOR of the function selectors of the interface (ethers Interface over the compiled ABI).",
    count: ifaceVectors.length,
    vectors: ifaceVectors,
  });
}
