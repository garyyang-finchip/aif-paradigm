#!/usr/bin/env node
// Verify a recorded deployment against the local build and the chain it lives on.
//
//   forge build
//   node tools/verify-deployment.mjs --rpc https://ethereum-sepolia-rpc.publicnode.com [--chain 11155111]
//
// For every contract in deployments/<chain>.json the script
//   1. fetches the runtime code with eth_getCode and compares it, byte for byte, with the local
//      `deployedBytecode` of the forge artifact after zeroing the ranges listed in the artifact's
//      `immutableReferences` on both sides (the tail CBOR metadata is part of the comparison);
//   2. decodes the immutable values that the constructor baked into the deployed code and reads the
//      corresponding getters back from chain (`verifier()`, `channelRegistry()`, `paradigmRegistry()`,
//      `participationRegistry()`, `deployer()`, `owner()`), comparing both with the address table of the record;
//   3. recomputes keccak256 of the deployed runtime and compares it with `runtimeKeccak256` in the record.
// Exit status 0 means every check passed. No dependencies beyond Node 18.
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a, i, all) => (a.startsWith("--") ? [a.slice(2), all[i + 1] ?? true] : [])).filter((p) => p.length));
const RPC = args.rpc || process.env.RPC || "https://ethereum-sepolia-rpc.publicnode.com";
const CHAIN = String(args.chain || 11155111);
const ROOT = args.root || process.cwd();
const record = JSON.parse(readFileSync(resolve(ROOT, args.record || `deployments/${CHAIN}.json`), "utf8"));

// ---------------------------------------------------------------- keccak256 (FIPS 202 permutation, 0x01 padding)
const RC = ["0x1", "0x8082", "0x800000000000808a", "0x8000000080008000", "0x808b", "0x80000001", "0x8000000080008081", "0x8000000000008009", "0x8a", "0x88", "0x80008009", "0x8000000a", "0x8000808b", "0x800000000000008b", "0x8000000000008089", "0x8000000000008003", "0x8000000000008002", "0x8000000000000080", "0x800a", "0x800000008000000a", "0x8000000080008081", "0x8000000000008080", "0x80000001", "0x8000000080008008"].map(BigInt);
const ROT = [0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14];
const M64 = (1n << 64n) - 1n;
const rotl = (x, n) => n === 0 ? x : ((x << BigInt(n)) | (x >> BigInt(64 - n))) & M64;
function keccakF(s) {
  for (let r = 0; r < 24; r++) {
    const c = [0n, 0n, 0n, 0n, 0n];
    for (let x = 0; x < 5; x++) c[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];
    for (let x = 0; x < 5; x++) {
      const d = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1);
      for (let y = 0; y < 25; y += 5) s[x + y] ^= d;
    }
    const b = new Array(25);
    for (let x = 0; x < 5; x++) for (let y = 0; y < 5; y++) b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(s[x + 5 * y], ROT[x + 5 * y]);
    for (let x = 0; x < 5; x++) for (let y = 0; y < 5; y++) s[x + 5 * y] = b[x + 5 * y] ^ (~b[(x + 1) % 5 + 5 * y] & M64 & b[(x + 2) % 5 + 5 * y]);
    s[0] ^= RC[r];
  }
}
export function keccak256(bytes) {
  const rate = 136, s = new Array(25).fill(0n);
  const padded = new Uint8Array(Math.ceil((bytes.length + 1) / rate) * rate);
  padded.set(bytes); padded[bytes.length] ^= 0x01; padded[padded.length - 1] ^= 0x80;
  for (let off = 0; off < padded.length; off += rate) {
    for (let i = 0; i < rate / 8; i++) {
      let lane = 0n;
      for (let j = 7; j >= 0; j--) lane = (lane << 8n) | BigInt(padded[off + 8 * i + j]);
      s[i] ^= lane;
    }
    keccakF(s);
  }
  let out = "0x";
  for (let i = 0; i < 4; i++) for (let j = 0; j < 8; j++) out += Number((s[i] >> BigInt(8 * j)) & 0xffn).toString(16).padStart(2, "0");
  return out;
}

// ---------------------------------------------------------------- helpers
const hexToBytes = (h) => Uint8Array.from(Buffer.from(h.replace(/^0x/, ""), "hex"));
const selector = (sig) => keccak256(new TextEncoder().encode(sig)).slice(0, 10);
const addr = (word) => "0x" + word.slice(-40).toLowerCase();
async function rpc(method, params) {
  const res = await fetch(RPC, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }) });
  const j = await res.json();
  if (j.error) throw new Error(`${method}: ${JSON.stringify(j.error)}`);
  return j.result;
}
const call = (to, sig) => rpc("eth_call", [{ to, data: selector(sig) }, "latest"]);

// which getters each contract exposes for its constructor arguments, and what the record says they must return
const DEPLOYER = (record.deployer || "").toLowerCase();
const EXPECT = {
  AIFPChannelRegistry: { "paradigmRegistry()": "AIFPParadigmRegistry", "deployer()": "@deployer", "participationRegistry()": "AIFPParticipationRegistry" },
  AIFPParticipationRegistry: { "channelRegistry()": "AIFPChannelRegistry", "paradigmRegistry()": "AIFPParadigmRegistry", "verifier()": "AIFPCompositeVerifier" },
  AIFPEventAnchor: { "channelRegistry()": "AIFPChannelRegistry", "participationRegistry()": "AIFPParticipationRegistry" },
  AIFPObjectionWindow: { "channelRegistry()": "AIFPChannelRegistry", "participationRegistry()": "AIFPParticipationRegistry" },
  AIFPSubjectSet: { "owner()": "@deployer" },
};
const expected = (name) => (name === "@deployer" ? DEPLOYER : String(record[name] || "").toLowerCase());

const contracts = Object.keys(record).filter((k) => /^AIFP[A-Za-z]+$/.test(k)).sort();
let failures = 0;
const fail = (msg) => { failures++; console.log(`  FAIL ${msg}`); };
const chainId = parseInt(await rpc("eth_chainId", []), 16);
console.log(`chain ${chainId} via ${RPC}; record deployments/${CHAIN}.json (${contracts.length} contracts, deployer ${DEPLOYER})`);
if (String(chainId) !== CHAIN) fail(`RPC chain id ${chainId} is not ${CHAIN}`);
const txByContract = Object.fromEntries((record.transactions || []).filter((t) => t.contract).map((t) => [t.contract, t]));

for (const name of contracts) {
  const address = record[name].toLowerCase();
  const artifact = JSON.parse(readFileSync(join(ROOT, "out", `${name}.sol`, `${name}.json`), "utf8"));
  const local = hexToBytes(artifact.deployedBytecode.object);
  const ranges = Object.values(artifact.deployedBytecode.immutableReferences || {}).flat();
  const onchain = hexToBytes(await rpc("eth_getCode", [address, "latest"]));
  console.log(`\n${name} ${address}: ${onchain.length} bytes on chain, ${local.length} local, ${ranges.length} immutable range(s)`);
  if (onchain.length !== local.length) { fail(`length differs`); continue; }

  // 1. full comparison with the immutable ranges zeroed on both sides
  const a = Uint8Array.from(onchain), b = Uint8Array.from(local);
  for (const { start, length } of ranges) { a.fill(0, start, start + length); b.fill(0, start, start + length); }
  let diff = -1;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) { diff = i; break; }
  if (diff >= 0) fail(`code differs at byte ${diff} outside the immutable ranges`);
  else console.log(`  code equal to the local build outside the immutable ranges (keccak256 of the zeroed code ${keccak256(a)})`);
  const tail = Buffer.from(onchain.slice(-53)).toString("hex"), tailLocal = Buffer.from(local.slice(-53)).toString("hex");
  console.log(`  metadata tail ${tail === tailLocal ? "equal" : "DIFFERENT"} (${tail.slice(0, 16)}...)`);

  // 2. immutables baked into the code, and the getters that expose them
  const baked = {};
  for (const { start, length } of ranges) {
    const word = Buffer.from(onchain.slice(start, start + length)).toString("hex");
    baked[addr(word)] = (baked[addr(word)] || 0) + 1;
  }
  if (ranges.length) console.log(`  immutable words in the deployed code: ${Object.entries(baked).map(([v, n]) => `${v} x${n}`).join(", ")}`);
  for (const [sig, want] of Object.entries(EXPECT[name] || {})) {
    const got = addr(await call(address, sig));
    const exp = expected(want);
    if (got !== exp) fail(`${sig} returned ${got}, record says ${exp} (${want})`);
    else console.log(`  ${sig} = ${got} (${want === "@deployer" ? "deployer" : want}) ok`);
  }
  const bakedUnknown = Object.keys(baked).filter((v) => !Object.values(EXPECT[name] || {}).some((w) => expected(w) === v));
  if (bakedUnknown.length) fail(`immutable value(s) not accounted for by the record: ${bakedUnknown.join(", ")}`);

  // 3. runtime hash against the record
  const h = keccak256(onchain), rec = txByContract[name]?.runtimeKeccak256;
  if (rec && rec.toLowerCase() !== h) fail(`runtimeKeccak256 ${h} differs from the record ${rec}`);
  else console.log(`  keccak256 of the deployed runtime ${h}${rec ? " matches the record" : ""}`);
}
console.log(failures ? `\n${failures} check(s) failed` : "\nall checks passed");
process.exit(failures ? 1 : 0);
