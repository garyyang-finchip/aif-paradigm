#!/usr/bin/env python3
"""Build the ethereum/ERCs filing package for AIFP.

Reads   ERCS/erc-aifp.md and assets/erc-aifp/{README.md,contracts,schemas,examples,vectors}
Writes  ercs-pr-package/ERCS/erc-<N>.md and ercs-pr-package/assets/erc-<N>/...

    python3 tools/make-filing-package.py [--number N] [--discussions-to URL] [--out DIR] [--source FILE]

N defaults to 9999 (the placeholder used before an editor assigns a number). Inside the markdown the
asset links are rewritten from ../assets/eip-aifp/ to ../assets/eip-<N>/ because the ERCs site serves the
erc-* asset directories under eip-* URLs. The script then lints the result the way the ERCs CI does:

  * title at most 44 characters and without the word "standard"
  * required front-matter keys present
  * no eip-<N> (or eip-9999) text inside inline backticks (eipw markdown-no-backticks)
  * every ERC/EIP number mentioned in the body appears first as a markdown link [ERC-N](./eip-N.md)
  * asset links use ../assets/eip-<N>/
  * RFC links point to rfc-editor.org
  * non-ASCII characters outside code blocks are reported as warnings

Exit status 1 on any lint error.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REQUIRED_KEYS = ["eip", "title", "description", "author", "discussions-to", "status", "type", "category", "created", "requires"]
ASSET_DIRS = ["contracts", "schemas", "examples", "vectors"]
EXCLUDED_PARTS = {"out", "invalid", "node_modules", "cache"}


def split_front_matter(text: str) -> tuple[list[str], str]:
    if not text.startswith("---\n"):
        raise SystemExit("ERC text must start with a '---' front-matter block")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise SystemExit("front-matter block is not closed")
    return text[4:end].split("\n"), text[end + 5 :]


def strip_code(body: str) -> tuple[str, str]:
    """Returns (body without fenced code blocks, body without fenced and inline code)."""
    no_fenced = re.sub(r"```.*?```", "\n", body, flags=re.S)
    no_inline = re.sub(r"`[^`\n]*`", "`x`", no_fenced)
    return no_fenced, no_inline


def lint(front: list[str], body: str, number: str) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    fm = {}
    for line in front:
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    for k in REQUIRED_KEYS:
        if k not in fm:
            errors.append(f"front matter: missing key '{k}'")
    title = fm.get("title", "")
    if len(title) > 44:
        errors.append(f"title: {len(title)} characters, limit is 44")
    if re.search(r"\bstandard\b", title, flags=re.I):
        errors.append("title: must not contain the word 'standard'")
    if fm.get("eip", "") != number:
        errors.append(f"front matter: eip is '{fm.get('eip')}', expected '{number}'")
    if fm.get("status", "") != "Draft":
        warnings.append(f"front matter: status is '{fm.get('status')}'")
    if fm.get("discussions-to", "").startswith("<") or not fm.get("discussions-to", ""):
        warnings.append("front matter: discussions-to is still a placeholder")

    no_fenced, no_inline = strip_code(body)

    # eipw markdown-no-backticks: an EIP/ERC reference inside inline code
    for m in re.finditer(r"`[^`\n]*`", no_fenced):
        span = m.group(0)
        if re.search(rf"eip-{number}\b|eip-9999\b|erc-{number}\b|erc-9999\b", span, flags=re.I):
            errors.append(f"inline code contains an EIP/ERC reference (eipw markdown-no-backticks): {span}")

    # first mention of every ERC/EIP number must be a markdown link
    seen_link: set[str] = set()
    for m in re.finditer(r"\[(ERC|EIP)-(\d+)\]\(\./eip-(\d+)\.md\)|\b(ERC|EIP)-(\d+)\b", no_inline):
        if m.group(1):
            if m.group(2) != m.group(3):
                errors.append(f"link text {m.group(1)}-{m.group(2)} points to eip-{m.group(3)}.md")
            seen_link.add(m.group(2))
        else:
            n = m.group(5)
            if n == number:
                continue  # self references are fine as plain text
            if n not in seen_link:
                errors.append(f"{m.group(4)}-{n} is mentioned before its first markdown link [{m.group(4)}-{n}](./eip-{n}.md)")
                seen_link.add(n)  # report once

    # asset links
    for m in re.finditer(r"\]\(([^)]+)\)", no_fenced):
        target = m.group(1)
        if "assets/" in target and not target.startswith(f"../assets/eip-{number}/"):
            errors.append(f"asset link must start with ../assets/eip-{number}/: {target}")
        if "rfc" in target.lower() and "ietf.org" in target:
            errors.append(f"RFC link must point to rfc-editor.org: {target}")
        if target.startswith("http") and "eips.ethereum.org" in target:
            errors.append(f"link to eips.ethereum.org must be relative: {target}")

    # non-ASCII outside code
    for i, line in enumerate(no_fenced.split("\n"), 1):
        bad = [c for c in line if ord(c) > 127]
        if bad:
            warnings.append(f"non-ASCII character(s) outside code blocks: {''.join(sorted(set(bad)))!r}")
            break
    return errors, warnings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--number", default="9999", help="ERC number (default 9999 placeholder)")
    ap.add_argument("--discussions-to", dest="discussions", default=None, help="Ethereum Magicians thread URL")
    ap.add_argument("--out", default=str(REPO / "ercs-pr-package"), help="output directory")
    ap.add_argument("--source", default=str(REPO / "ERCS" / "erc-aifp.md"), help="source ERC markdown")
    ap.add_argument("--assets", default=str(REPO / "assets" / "erc-aifp"), help="source assets directory")
    ap.add_argument("--lint-only", action="store_true", help="lint the source without writing the package")
    args = ap.parse_args()

    number = str(args.number)
    if not number.isdigit():
        print("--number must be an integer", file=sys.stderr)
        return 2
    src = Path(args.source)
    if not src.exists():
        print(f"ERC text not found: {src} (write ERCS/erc-aifp.md first)", file=sys.stderr)
        return 1
    assets = Path(args.assets)
    if not assets.exists():
        print(f"assets directory not found: {assets}", file=sys.stderr)
        return 1

    text = src.read_text(encoding="utf-8")
    front, body = split_front_matter(text)

    # front-matter rewrites
    new_front = []
    for line in front:
        if line.startswith("eip:"):
            line = f"eip: {number}"
        if args.discussions and line.startswith("discussions-to:"):
            line = f"discussions-to: {args.discussions}"
        new_front.append(line)
    body = body.replace("../assets/eip-aifp/", f"../assets/eip-{number}/")
    body = body.replace("../assets/eip-9999/", f"../assets/eip-{number}/")

    errors, warnings = lint(new_front, body, number)
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors:
        print(f"{len(errors)} lint error(s)", file=sys.stderr)
        return 1
    if args.lint_only:
        print("lint ok")
        return 0

    out = Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    (out / "ERCS").mkdir(parents=True)
    (out / "ERCS" / f"erc-{number}.md").write_text("---\n" + "\n".join(new_front) + "\n---\n" + body, encoding="utf-8")

    dest_assets = out / "assets" / f"erc-{number}"
    copied = 0
    # Top-level asset files (the assets index linked from the ERC text) travel with the package.
    for path in sorted(assets.glob("*")):
        if path.is_file():
            target = dest_assets / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            copied += 1
    for sub in ASSET_DIRS:
        sdir = assets / sub
        if not sdir.exists():
            continue
        for path in sorted(sdir.rglob("*")):
            if path.is_dir():
                continue
            if EXCLUDED_PARTS & set(path.relative_to(assets).parts):
                continue
            rel = path.relative_to(assets)
            target = dest_assets / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            copied += 1
    total = copied + 1
    print(f"wrote {out} : ERCS/erc-{number}.md + {copied} asset files ({total} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
