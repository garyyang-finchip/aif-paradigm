// Canonical subject references (mirrors AIFPSubject.sol).
//
//   eip155-address:<chainId>:<0x + 40 lowercase hex>
//   erc8004:<chainId>:<0x + 40 lowercase hex registry>:<agentId decimal>
//   did:<method>:<method-specific-id as given>
//   ext:<namespace lowercase>:<opaque identifier>
//
// subjectRef = keccak256(utf8(canonical)). There is no second encoding.

import { keccak256, toUtf8Bytes } from "ethers";

function lowerAddress(a) {
  if (typeof a !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(a)) throw new Error(`subject: not an address: ${a}`);
  // The canonical form is lowercase hex; mixed-case input is accepted and lowercased (no checksum check).
  return a.toLowerCase();
}

function decimal(n) {
  const b = typeof n === "bigint" ? n : BigInt(n);
  if (b < 0n) throw new Error("subject: negative integer");
  return b.toString(10);
}

export function canonicalAddress(chainId, address) {
  return `eip155-address:${decimal(chainId)}:${lowerAddress(address)}`;
}

export function canonicalERC8004(chainId, registry, agentId) {
  return `erc8004:${decimal(chainId)}:${lowerAddress(registry)}:${decimal(agentId)}`;
}

export function canonicalDID(method, methodSpecificId) {
  if (!/^[a-z0-9]+$/.test(method)) throw new Error(`subject: DID method must be lowercase alphanumeric: ${method}`);
  if (!methodSpecificId) throw new Error("subject: empty DID method-specific id");
  return `did:${method}:${methodSpecificId}`;
}

export function canonicalExt(namespace, identifier) {
  if (!/^[a-z0-9][a-z0-9.-]*$/.test(namespace)) throw new Error(`subject: ext namespace must be lowercase: ${namespace}`);
  if (!identifier) throw new Error("subject: empty ext identifier");
  return `ext:${namespace}:${identifier}`;
}

export function refOf(canonical) {
  return keccak256(toUtf8Bytes(canonical));
}

/** Parses a canonical string back into its parts (scheme and domain never contain ':'). */
export function parseCanonical(canonical) {
  const first = canonical.indexOf(":");
  if (first < 0) throw new Error("subject: missing scheme");
  const scheme = canonical.slice(0, first);
  const rest = canonical.slice(first + 1);
  if (scheme === "erc8004") {
    const m = /^([0-9]+):(0x[0-9a-f]{40}):([0-9]+)$/.exec(rest);
    if (!m) throw new Error("subject: malformed erc8004 reference");
    return { scheme, chainId: m[1], registry: m[2], agentId: m[3] };
  }
  const second = rest.indexOf(":");
  if (second < 0) throw new Error("subject: missing identifier");
  const domain = rest.slice(0, second);
  const identifier = rest.slice(second + 1);
  if (scheme === "eip155-address") {
    if (!/^[0-9]+$/.test(domain) || !/^0x[0-9a-f]{40}$/.test(identifier)) throw new Error("subject: malformed eip155-address reference");
  } else if (scheme === "did") {
    if (!/^[a-z0-9]+$/.test(domain)) throw new Error("subject: malformed did reference");
  } else if (scheme === "ext") {
    if (!/^[a-z0-9][a-z0-9.-]*$/.test(domain)) throw new Error("subject: malformed ext reference");
  } else {
    throw new Error(`subject: unknown scheme ${scheme}`);
  }
  return { scheme, domain, identifier };
}
