// JSON Canonicalization Scheme (RFC 8785) for AIFP descriptors.
//
// Descriptors use only objects, arrays, strings, booleans, null and integers, so the number
// serialization reduces to the integer case of the ES Number::toString algorithm.
// paradigmId = keccak256(utf8(canonical)).

import { keccak256, toUtf8Bytes, hexlify } from "ethers";

function serializeString(s) {
  let out = '"';
  for (const ch of s) {
    const code = ch.codePointAt(0);
    switch (ch) {
      case "\b":
        out += "\\b";
        continue;
      case "\t":
        out += "\\t";
        continue;
      case "\n":
        out += "\\n";
        continue;
      case "\f":
        out += "\\f";
        continue;
      case "\r":
        out += "\\r";
        continue;
      case '"':
        out += '\\"';
        continue;
      case "\\":
        out += "\\\\";
        continue;
      default:
        break;
    }
    if (code < 0x20) {
      out += "\\u" + code.toString(16).padStart(4, "0");
    } else {
      out += ch;
    }
  }
  return out + '"';
}

function serializeNumber(n) {
  if (!Number.isFinite(n)) throw new Error("JCS: non-finite number");
  if (!Number.isInteger(n)) throw new Error("JCS: AIFP descriptors allow integers only, got " + n);
  if (Math.abs(n) >= 2 ** 53) throw new Error("JCS: integer outside the safe range: " + n);
  if (Object.is(n, -0)) return "0";
  return String(n);
}

// RFC 8785 sorts property names by their UTF-16 code units.
function compareKeys(a, b) {
  const la = a.length;
  const lb = b.length;
  const n = Math.min(la, lb);
  for (let i = 0; i < n; i++) {
    const ca = a.charCodeAt(i);
    const cb = b.charCodeAt(i);
    if (ca !== cb) return ca - cb;
  }
  return la - lb;
}

export function canonicalize(value) {
  if (value === null) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return serializeNumber(value);
  if (typeof value === "string") return serializeString(value);
  if (Array.isArray(value)) return "[" + value.map(canonicalize).join(",") + "]";
  if (typeof value === "object") {
    const keys = Object.keys(value).filter((k) => value[k] !== undefined).sort(compareKeys);
    return "{" + keys.map((k) => serializeString(k) + ":" + canonicalize(value[k])).join(",") + "}";
  }
  throw new Error("JCS: unsupported value of type " + typeof value);
}

export function canonicalBytes(value) {
  return toUtf8Bytes(canonicalize(value));
}

export function canonicalHex(value) {
  return hexlify(canonicalBytes(value));
}

export function paradigmIdOf(value) {
  return keccak256(canonicalBytes(value));
}

export function idOfString(s) {
  return keccak256(toUtf8Bytes(s));
}
