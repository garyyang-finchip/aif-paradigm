// JSON predicate -> AIFPPredicates.Node[] -> ABI encoding -> predicateHash.
//
// Node layout (mirrors AIFPPredicates.sol):
//   tuple(uint8 kind, uint8 childStart, uint8 childCount, address verifier, bytes32 ref, bytes params)[]
// Allocation is breadth-first: node 0 is the root; when a composite is processed, its children are
// allocated as one contiguous block at the end of the array, then processed in order. Hence every child
// index is greater than its parent's index and the array is acyclic by construction.

import { AbiCoder, keccak256, zeroPadValue, toBeHex } from "ethers";

export const KIND = Object.freeze({
  open: 0,
  allowlist: 1,
  external: 2,
  allOf: 3,
  anyOf: 4,
  credential: 5,
  stake: 6,
  identity: 7,
  member: 8,
  decision: 9,
});

export const KIND_NAMES = Object.freeze(Object.fromEntries(Object.entries(KIND).map(([k, v]) => [v, k])));

export const MAX_NODES = 64;
export const MAX_DEPTH = 8;

const ZERO32 = "0x" + "0".repeat(64);
const ZERO_ADDRESS = "0x" + "0".repeat(40);
const coder = AbiCoder.defaultAbiCoder();

const PROOF_MODE = { attested: 0, proved: 1 };
const STAKE_PERIOD = { active: 0, epoch: 1, lockup: 2 };
const IDENTITY_STATE = { registered: 0, active: 1, bound: 2 };

function lowerAddress(a, what) {
  if (typeof a !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(a)) throw new Error(`predicate: ${what} is not an address: ${a}`);
  return a.toLowerCase();
}

function bytes32(v, what) {
  if (v === undefined) return ZERO32;
  if (typeof v !== "string" || !/^0x[0-9a-fA-F]{64}$/.test(v)) throw new Error(`predicate: ${what} is not bytes32: ${v}`);
  return v.toLowerCase();
}

function hexBytes(v, what) {
  if (v === undefined) return "0x";
  if (typeof v !== "string" || !/^0x([0-9a-fA-F]{2})*$/.test(v)) throw new Error(`predicate: ${what} is not hex bytes: ${v}`);
  return v.toLowerCase();
}

function chainIdOf(chain) {
  const m = /^eip155:([0-9]+)$/.exec(chain || "");
  if (!m) throw new Error(`predicate: stake.chain must be eip155:<id>, got ${chain}`);
  return BigInt(m[1]);
}

/** Builds the leaf node for a single-key predicate object. Returns {node, children} where children is
 *  the array of child JSON predicates for composites (empty for leaves). */
function nodeOf(json) {
  if (json === null || typeof json !== "object" || Array.isArray(json)) throw new Error("predicate: must be an object");
  const keys = Object.keys(json);
  if (keys.length !== 1) throw new Error(`predicate: exactly one key expected, got [${keys.join(", ")}]`);
  const key = keys[0];
  const v = json[key];
  const leaf = (kind, verifier, ref, params) => ({
    node: { kind, childStart: 0, childCount: 0, verifier, ref, params },
    children: [],
  });
  switch (key) {
    case "open":
      if (v !== true) throw new Error("predicate: open must be true");
      return leaf(KIND.open, ZERO_ADDRESS, ZERO32, "0x");
    case "allowlist":
      return leaf(KIND.allowlist, lowerAddress(v.set, "allowlist.set"), ZERO32, "0x");
    case "external":
      return leaf(KIND.external, lowerAddress(v.verifier, "external.verifier"), bytes32(v.ref, "external.ref"), hexBytes(v.params, "external.params"));
    case "credential": {
      if (!(v.proofMode in PROOF_MODE)) throw new Error(`predicate: credential.proofMode invalid: ${v.proofMode}`);
      if (!Number.isInteger(v.minLevel) || v.minLevel < 0 || v.minLevel > 255) throw new Error("predicate: credential.minLevel must be 0..255");
      const issuers = (v.issuers || []).map((a) => lowerAddress(a, "credential.issuers[]"));
      const params = coder.encode(
        ["uint256", "uint8", "uint256", "address[]"],
        [v.minLevel, PROOF_MODE[v.proofMode], v.freshnessSeconds || 0, issuers],
      );
      return leaf(KIND.credential, lowerAddress(v.verifier, "credential.verifier"), bytes32(v.scheme, "credential.scheme"), params);
    }
    case "stake": {
      if (!(v.period in STAKE_PERIOD)) throw new Error(`predicate: stake.period invalid: ${v.period}`);
      if (typeof v.minAmount !== "string" || !/^[0-9]+$/.test(v.minAmount)) throw new Error("predicate: stake.minAmount must be a decimal string");
      const asset = v.asset === "native" ? ZERO_ADDRESS : lowerAddress(v.asset, "stake.asset");
      const params = coder.encode(
        ["uint256", "address", "address", "uint256", "uint8"],
        [chainIdOf(v.chain), lowerAddress(v.contract, "stake.contract"), asset, BigInt(v.minAmount), STAKE_PERIOD[v.period]],
      );
      return leaf(KIND.stake, lowerAddress(v.verifier, "stake.verifier"), ZERO32, params);
    }
    case "identity": {
      if (!(v.requiredState in IDENTITY_STATE)) throw new Error(`predicate: identity.requiredState invalid: ${v.requiredState}`);
      const registry = lowerAddress(v.registry, "identity.registry");
      const ref = zeroPadValue(registry, 32);
      const params = coder.encode(["uint8"], [IDENTITY_STATE[v.requiredState]]);
      return leaf(KIND.identity, lowerAddress(v.verifier, "identity.verifier"), ref, params);
    }
    case "member":
      return leaf(KIND.member, lowerAddress(v.verifier, "member.verifier"), bytes32(v.group, "member.group"), "0x");
    case "decision":
      return leaf(KIND.decision, lowerAddress(v.verifier, "decision.verifier"), bytes32(v.decision, "decision.decision"), "0x");
    case "allOf":
    case "anyOf": {
      if (!Array.isArray(v) || v.length === 0) throw new Error(`predicate: ${key} must be a non-empty array`);
      return {
        node: { kind: KIND[key], childStart: 0, childCount: v.length, verifier: ZERO_ADDRESS, ref: ZERO32, params: "0x" },
        children: v,
      };
    }
    default:
      throw new Error(`predicate: unknown predicate key ${key}`);
  }
}

/** Flattens a JSON predicate into the node array (breadth-first child allocation). */
export function toNodes(json) {
  const nodes = [];
  const queue = [];
  nodes.push(null);
  queue.push({ json, index: 0, depth: 0 });
  while (queue.length) {
    const { json: j, index, depth } = queue.shift();
    if (depth > MAX_DEPTH) throw new Error(`predicate: depth exceeds ${MAX_DEPTH}`);
    const { node, children } = nodeOf(j);
    if (children.length) {
      node.childStart = nodes.length;
      node.childCount = children.length;
      for (const child of children) {
        const childIndex = nodes.length;
        nodes.push(null);
        queue.push({ json: child, index: childIndex, depth: depth + 1 });
      }
    }
    nodes[index] = node;
    if (nodes.length > MAX_NODES) throw new Error(`predicate: more than ${MAX_NODES} nodes`);
  }
  return nodes;
}

export const NODE_TUPLE = "tuple(uint8 kind,uint8 childStart,uint8 childCount,address verifier,bytes32 ref,bytes params)[]";

export function encodeNodes(nodes) {
  return coder.encode(
    [NODE_TUPLE],
    [nodes.map((n) => [n.kind, n.childStart, n.childCount, n.verifier, n.ref, n.params])],
  );
}

export function compile(json) {
  const nodes = toNodes(json);
  const encoding = encodeNodes(nodes);
  return { nodes, encoding, hash: keccak256(encoding) };
}

export function describeNodes(nodes) {
  return nodes.map((n, i) => ({
    index: i,
    kind: n.kind,
    kindName: KIND_NAMES[n.kind],
    childStart: n.childStart,
    childCount: n.childCount,
    verifier: n.verifier,
    ref: n.ref,
    params: n.params,
  }));
}

export { toBeHex };
