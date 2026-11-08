// Decidable identification conditions of the named paradigms (aifp:paradigm/<name>/v1).
//
// A label is a declaration made by the registrant; the canonical validator rejects a label whose
// condition is decidable from the descriptor and false. Names outside this table are rejected because
// the aifp:paradigm/ namespace is reserved; aifp:ext/ labels pass through unchecked.

const has = (arr, v) => Array.isArray(arr) && arr.includes(v);
const oneOf = (v, list) => list.includes(v);

export const CONDITIONS = Object.freeze({
  source: (d) => d.cardinality.contributors === "single" && has(d.operators, "fan-out"),
  intake: (d) => has(d.operators, "fan-in") && d.dimensions.observation.submissionVisibility === "collector-only",
  direct: (d) => d.cardinality.pairwise === true && has(d.operators, "feedback"),
  panel: (d) =>
    d.cardinality.contributors === "roster" &&
    has(d.operators, "n-party") &&
    oneOf(d.dimensions.observation.readScope, ["open", "predicate"]) &&
    oneOf(d.dimensions.contribution.acquisition, ["manager", "closed"]),
  club: (d) =>
    oneOf(d.cardinality.contributors, ["qualified", "open"]) &&
    has(d.operators, "n-party") &&
    oneOf(d.dimensions.contribution.acquisition, ["open", "predicate"]),
  meeting: (d) =>
    d.cardinality.contributors === "roster" &&
    has(d.operators, "n-party") &&
    d.dimensions.observation.readScope === "members" &&
    oneOf(d.dimensions.contribution.acquisition, ["manager", "closed"]),
  archive: (d) => has(d.carriers, "shared-object") && has(d.dimensions.time.delivery, "pull") && d.dimensions.history.mutable === false,
  blackboard: (d) => has(d.carriers, "shared-object") && d.dimensions.history.mutable === true && has(d.operators, "n-party"),
  dispatch: (d) => has(d.operators, "select"),
  forward: (d) => has(d.operators, "forward") && d.dimensions.redistribution.forward === true,
  derive: (d) => (has(d.operators, "derive") || has(d.operators, "merge")) && d.dimensions.redistribution.derive === true,
});

export const CONDITION_TEXT = Object.freeze({
  source: 'cardinality.contributors == "single" and operators contain "fan-out"',
  intake: 'operators contain "fan-in" and observation.submissionVisibility == "collector-only"',
  direct: 'cardinality.pairwise == true and operators contain "feedback"',
  panel: 'contributors == "roster", operators contain "n-party", observation.readScope in {open, predicate}, contribution.acquisition in {manager, closed}',
  club: 'contributors in {qualified, open}, operators contain "n-party", contribution.acquisition in {open, predicate}',
  meeting: 'contributors == "roster", operators contain "n-party", observation.readScope == "members", contribution.acquisition in {manager, closed}',
  archive: 'carriers contain "shared-object", time.delivery contains "pull", history.mutable == false',
  blackboard: 'carriers contain "shared-object", history.mutable == true, operators contain "n-party"',
  dispatch: 'operators contain "select"',
  forward: 'operators contain "forward" and redistribution.forward == true',
  derive: 'operators contain "derive" or "merge", and redistribution.derive == true',
});

const LABEL_RE = /^aifp:(paradigm|ext)\/([a-z0-9][a-z0-9.-]*)(?:\/([a-z0-9][a-z0-9.-]*))?\/v([0-9]+)$/;

/** Returns an array of error strings (empty when all labels are acceptable). */
export function checkLabels(descriptor) {
  const errors = [];
  for (const label of descriptor.labels || []) {
    const m = LABEL_RE.exec(label);
    if (!m) {
      errors.push(`label ${label}: malformed`);
      continue;
    }
    const [, ns, name, sub, version] = m;
    if (ns === "ext") continue; // vendor labels are not checked here
    if (sub !== undefined) {
      errors.push(`label ${label}: aifp:paradigm labels take a single name segment`);
      continue;
    }
    if (version !== "1") {
      errors.push(`label ${label}: only v1 named paradigms are defined`);
      continue;
    }
    const cond = CONDITIONS[name];
    if (!cond) {
      errors.push(`label ${label}: "${name}" is not a defined named paradigm (reserved namespace)`);
      continue;
    }
    let ok = false;
    try {
      ok = cond(descriptor);
    } catch (e) {
      errors.push(`label ${label}: condition could not be evaluated (${e.message})`);
      continue;
    }
    if (!ok) errors.push(`label ${label}: identification condition does not hold (${CONDITION_TEXT[name]})`);
  }
  return errors;
}

/** Names whose conditions hold for the descriptor, whether or not they were declared. */
export function matchingNames(descriptor) {
  return Object.keys(CONDITIONS).filter((n) => {
    try {
      return CONDITIONS[n](descriptor);
    } catch {
      return false;
    }
  });
}
