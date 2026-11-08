#!/usr/bin/env node
// `npm run check`: every example descriptor validates, every invalid example fails for its declared
// reason, the schemas themselves compile, and the vectors are reproducible from the sources.
//
//   node tools/check.mjs [--no-interfaces]   (--no-interfaces skips interface-ids.json when out/ is absent)

import { readdirSync, readFileSync, existsSync, mkdtempSync, cpSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";
import { REPO_ROOT, validateFile, loadSchemas } from "./lib/validate.mjs";

const EX = join(REPO_ROOT, "assets", "erc-aifp", "examples");
const VEC = join(REPO_ROOT, "assets", "erc-aifp", "vectors");
const skipInterfaces = process.argv.includes("--no-interfaces") || !existsSync(join(REPO_ROOT, "out"));

let failures = 0;
const fail = (msg) => {
  failures++;
  console.error("FAIL " + msg);
};

// 1. schemas compile
try {
  loadSchemas();
  console.log("ok   schemas compile");
} catch (e) {
  fail("schemas: " + e.message);
}

// 2. valid examples
for (const dir of ["paradigms", "composites"]) {
  for (const f of readdirSync(join(EX, dir)).filter((n) => n.endsWith(".json")).sort()) {
    const r = validateFile(join(EX, dir, f));
    if (r.ok) console.log(`ok   examples/${dir}/${f}  ${r.bundle.paradigmId}`);
    else fail(`examples/${dir}/${f}: ${r.errors.join("; ")}`);
  }
}

// 3. invalid examples must fail for their declared reason
const expectedReasons = {
  "schema-violation.json": /^schema:/,
  "false-label-condition.json": /identification condition does not hold/,
  "empty-allof.json": /allOf must NOT have fewer than 1 items|non-empty array/,
  "reserved-namespace-label.json": /reserved namespace/,
};
for (const f of readdirSync(join(EX, "invalid")).filter((n) => n.endsWith(".json")).sort()) {
  const r = validateFile(join(EX, "invalid", f));
  const re = expectedReasons[f];
  if (r.ok) fail(`examples/invalid/${f} validated but must fail`);
  else if (!re) fail(`examples/invalid/${f}: no expected reason registered in tools/check.mjs`);
  else if (!r.errors.some((e) => re.test(e))) fail(`examples/invalid/${f}: failed for an unexpected reason: ${r.errors.join("; ")}`);
  else console.log(`ok   examples/invalid/${f} rejected (${r.errors[0]})`);
}

// 4. vectors reproducible: regenerate into a temp copy and compare byte for byte
const tmp = mkdtempSync(join(tmpdir(), "aifp-vectors-"));
try {
  const args = [join(REPO_ROOT, "tools", "make-vectors.mjs")];
  if (skipInterfaces) args.push("--skip-interfaces");
  const before = {};
  for (const f of readdirSync(VEC).filter((n) => n.endsWith(".json"))) before[f] = readFileSync(join(VEC, f), "utf8");
  execFileSync(process.execPath, args, { stdio: ["ignore", "ignore", "inherit"] });
  const after = {};
  for (const f of readdirSync(VEC).filter((n) => n.endsWith(".json"))) after[f] = readFileSync(join(VEC, f), "utf8");
  for (const f of Object.keys(after)) {
    if (skipInterfaces && f === "interface-ids.json") continue;
    if (before[f] !== after[f]) fail(`vectors/${f} is not up to date (regenerate with npm run vectors and commit)`);
    else console.log(`ok   vectors/${f} reproducible`);
  }
  if (skipInterfaces) console.log("skip vectors/interface-ids.json (no out/ directory; run forge build first)");
} finally {
  rmSync(tmp, { recursive: true, force: true });
}

if (failures) {
  console.error(`\n${failures} check(s) failed`);
  process.exit(1);
}
console.log("\nall checks passed");
