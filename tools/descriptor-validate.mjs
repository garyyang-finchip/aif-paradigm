#!/usr/bin/env node
// Canonical validator for AIFP paradigm descriptors.
//
//   node tools/descriptor-validate.mjs <descriptor.json> [--quiet] [--brief]
//
// Checks the descriptor against the schemas, the decidable label identification conditions and the
// absence-rule consistency; derives the per-role predicate encodings and prints the registration bundle
// (canonical bytes, paradigmId, familyId, labelIds, rolePredicates) as JSON on stdout.
// Exit code 1 on any failure, 2 on usage error.

import { validateFile } from "./lib/validate.mjs";

const args = process.argv.slice(2);
const files = args.filter((a) => !a.startsWith("--"));
const quiet = args.includes("--quiet");
const brief = args.includes("--brief");

if (files.length === 0) {
  console.error("usage: node tools/descriptor-validate.mjs <descriptor.json> [--quiet] [--brief]");
  process.exit(2);
}

let failed = false;
const bundles = [];
for (const file of files) {
  const result = validateFile(file);
  if (!result.ok) {
    failed = true;
    console.error(`INVALID ${file}`);
    for (const e of result.errors) console.error(`  - ${e}`);
    continue;
  }
  for (const w of result.warnings) console.error(`  warning (${file}): ${w}`);
  const b = result.bundle;
  bundles.push(
    brief
      ? { file: b.file, paradigmId: b.paradigmId, familyId: b.familyId, labels: b.labels, roles: b.rolePredicates.map((r) => `${r.role}=${r.predicateHash}`) }
      : b,
  );
}
if (!quiet && bundles.length) console.log(JSON.stringify(bundles.length === 1 ? bundles[0] : bundles, null, 2));
process.exit(failed ? 1 : 0);
