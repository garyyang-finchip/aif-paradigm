// Shared validation pipeline: schemas -> label conditions -> absence consistency -> registration bundle.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { keccak256, toUtf8Bytes } from "ethers";
import { canonicalize, canonicalHex, paradigmIdOf, idOfString } from "./jcs.mjs";
import { compile, describeNodes } from "./predicates.mjs";
import { checkLabels, matchingNames } from "./labels.mjs";

const here = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = join(here, "..", "..");
const SCHEMA_DIR = join(REPO_ROOT, "assets", "erc-aifp", "schemas");

export const ROLE_BITS = Object.freeze({
  discover: 1,
  observe: 2,
  submit: 4,
  respond: 8,
  modify: 16,
  manageAdmission: 32,
  manageOrder: 64,
  manageRemove: 128,
  manageRules: 256,
  redistribute: 512,
  manageDisclosure: 1024,
});

let compiled;

export function loadSchemas() {
  if (compiled) return compiled;
  const descriptorSchema = JSON.parse(readFileSync(join(SCHEMA_DIR, "paradigm-descriptor.schema.json"), "utf8"));
  const predicateSchema = JSON.parse(readFileSync(join(SCHEMA_DIR, "predicate.schema.json"), "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
  addFormats(ajv);
  ajv.addSchema(predicateSchema); // registered under its $id, referenced as "predicate.schema.json"
  const validateDescriptor = ajv.compile(descriptorSchema);
  const validatePredicate = ajv.getSchema(predicateSchema.$id);
  compiled = { ajv, validateDescriptor, validatePredicate };
  return compiled;
}

function formatAjvErrors(errors) {
  return (errors || []).map((e) => `${e.instancePath || "/"} ${e.message}${e.params && e.params.allowedValues ? " [" + e.params.allowedValues.join(", ") + "]" : ""}`);
}

/** Validates a parsed descriptor. Returns {ok, errors, warnings, bundle}. */
export function validateDescriptor(descriptor, fileLabel = "<inline>") {
  const { validateDescriptor: v } = loadSchemas();
  const errors = [];
  const warnings = [];

  if (!v(descriptor)) errors.push(...formatAjvErrors(v.errors).map((m) => `schema: ${m}`));
  if (errors.length) return { ok: false, errors, warnings, bundle: null };

  errors.push(...checkLabels(descriptor));

  const ruleDefined = descriptor.dimensions.time.absence === "rule-defined";
  const hasAbsenceExt = Boolean(descriptor.extensions && descriptor.extensions.absence);
  if (ruleDefined && !hasAbsenceExt) errors.push('absence: dimensions.time.absence is "rule-defined" but extensions.absence is missing');
  if (!ruleDefined && hasAbsenceExt) errors.push('absence: extensions.absence is present but dimensions.time.absence is not "rule-defined"');

  if (descriptor.extensions && descriptor.extensions.ext) {
    const ids = descriptor.extensions.ext.map((e) => e.id);
    if (new Set(ids).size !== ids.length) errors.push("extensions.ext: duplicate extension ids");
  }

  const undeclared = matchingNames(descriptor).filter((n) => !(descriptor.labels || []).includes(`aifp:paradigm/${n}/v1`));
  if (undeclared.length) warnings.push(`conditions also hold for undeclared names: ${undeclared.join(", ")}`);

  const rolePredicates = [];
  for (const [role, json] of Object.entries(descriptor.predicates || {})) {
    const bit = ROLE_BITS[role];
    if (!bit) {
      errors.push(`predicates: unknown role ${role}`);
      continue;
    }
    try {
      const { nodes, encoding, hash } = compile(json);
      rolePredicates.push({ role, roleBit: bit, nodeCount: nodes.length, nodes: describeNodes(nodes), predicateHex: encoding, predicateHash: hash });
    } catch (e) {
      errors.push(`predicates.${role}: ${e.message}`);
    }
  }
  rolePredicates.sort((a, b) => a.roleBit - b.roleBit);

  if (errors.length) return { ok: false, errors, warnings, bundle: null };

  const canonical = canonicalize(descriptor);
  const bundle = {
    file: fileLabel,
    family: descriptor.family,
    familyId: idOfString(descriptor.family),
    labels: descriptor.labels,
    labelIds: descriptor.labels.map((l) => ({ label: l, id: idOfString(l) })),
    canonical,
    canonicalHex: canonicalHex(descriptor),
    paradigmId: paradigmIdOf(descriptor),
    rolePredicates,
    warnings,
  };
  return { ok: true, errors, warnings, bundle };
}

export function validateFile(path) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    return { ok: false, errors: [`json: ${e.message}`], warnings: [], bundle: null };
  }
  return validateDescriptor(parsed, path);
}

export { keccak256, toUtf8Bytes };
