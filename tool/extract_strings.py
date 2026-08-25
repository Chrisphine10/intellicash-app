"""
Moves hard-coded user-visible strings out of the Dart UI and into `app_en.arb`.

Why this exists: the language picker offers five languages and the plumbing
around it is sound, but only 83 strings were ever routed through `L10n`. Every
other label in the app — 400-odd of them — was an English literal in a widget,
so choosing Gikuyu changed almost nothing on screen. Translating harder would
not have helped; the words were not reachable.

The rewrite is mechanical and therefore scripted rather than done by hand
across 58 files. What it does NOT do is guess: anything it is not confident
about is left alone and reported, and `flutter analyze` is the acceptance test
afterwards. A string it cannot place is a string a human should look at.

    python tool/extract_strings.py --dry-run     # report only
    python tool/extract_strings.py               # rewrite
"""

from __future__ import annotations

import argparse
import json
import io
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
ARB = LIB / "l10n" / "app_en.arb"

# Files whose strings are not UI copy, or where `context` is genuinely absent.
SKIP_PARTS = (
    "/l10n/",
    "/core/network/",
    "/core/database/",
    "/data/models/",
    "/data/repositories/",
    "/data/services/",
    "/providers/",
    "/reports/pdf_report",
    "/reports/member_pdf",
)

# Strings that are not words: codes, symbols, single letters, format patterns.
NOT_COPY = re.compile(
    r"""^(?:
        [\s\W\d]*            # punctuation / digits only
        |[A-Za-z]            # a single letter
        |[a-z0-9_]+          # an identifier-looking token
        |(?:[A-Z]{2,}_?)+    # SCREAMING_CASE enum values
        |https?:.*
        |\d{1,2}:\d{2}.*
    )$""",
    re.X,
)

# The literal forms that reach a user's eye.
PATTERNS = [
    # const Text('…') / Text('…')
    (re.compile(r"(?P<pre>\bconst\s+)?(?P<head>Text\(\s*)(?P<q>['\"])(?P<body>[^'\"\\$]{2,}?)(?P=q)"), "text"),
    # label:/title:/hintText:… 'literal'
    (
        re.compile(
            r"(?P<head>\b(?:label|labelText|hintText|helperText|tooltip|message|semanticLabel|title|subtitle)\s*:\s*)"
            r"(?P<q>['\"])(?P<body>[^'\"\\$]{2,}?)(?P=q)"
        ),
        "named",
    ),
]


def is_copy(text: str) -> bool:
    """True when a literal reads like something written for a person."""
    t = text.strip()
    if len(t) < 2 or NOT_COPY.match(t):
        return False
    # Needs a letter, and either a space or a capital — "Loans" yes, "kes" no.
    if not re.search(r"[A-Za-z]", t):
        return False
    return " " in t or t[0].isupper()


def key_for(text: str, prefix: str, taken: dict[str, str]) -> str:
    """
    A stable camelCase key: the screen's prefix plus a slug of the words.

    Identical copy anywhere in the app reuses one key — "Try again" should not
    become eleven keys that a translator has to answer eleven times.
    """
    for existing, value in taken.items():
        if value == text:
            return existing

    words = re.findall(r"[A-Za-z0-9]+", text)[:5]
    if not words:
        words = ["label"]
    slug = words[0].lower() + "".join(w.capitalize() for w in words[1:])
    base = f"{prefix}{slug[0].upper()}{slug[1:]}" if prefix else slug

    key, n = base, 2
    while key in taken:
        key, n = f"{base}{n}", n + 1
    return key


def prefix_for(path: Path) -> str:
    """`features/meetings/meeting_hub_screen.dart` -> `meetingHub`."""
    name = path.stem
    for tail in ("_screen", "_sheet", "_dialog", "_card", "_view", "_section"):
        name = name.removesuffix(tail)
    parts = re.split(r"[_]+", name)
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def drop_const_around_l10n(src: str) -> str:
    """
    Remove every `const` whose constructor now contains an `l10n.` lookup.

    One pass, applied back to front so earlier offsets stay valid. Nesting
    needs no second pass: an outer `const` whose body contains the lookup
    matches on the same scan as the inner one.
    """
    doomed = []

    # const Constructor(…)
    for m in re.finditer(r"\bconst\s+(?=[A-Z_])", src):
        open_paren = src.find("(", m.end())
        if open_paren == -1:
            continue
        depth, i = 1, open_paren + 1
        while i < len(src) and depth:
            if src[i] == "(":
                depth += 1
            elif src[i] == ")":
                depth -= 1
            i += 1
        if "l10n." in src[open_paren:i]:
            doomed.append((m.start(), m.end()))

    # const [...] and const {...} collection literals
    for m in re.finditer(r"\bconst\s+(?=[\[{])", src):
        opener = src[m.end()]
        closer = "]" if opener == "[" else "}"
        depth, i = 1, m.end() + 1
        while i < len(src) and depth:
            if src[i] == opener:
                depth += 1
            elif src[i] == closer:
                depth -= 1
            i += 1
        if "l10n." in src[m.end() : i]:
            doomed.append((m.start(), m.end()))

    for start, end in sorted(set(doomed), reverse=True):
        src = src[:start] + src[end:]
    return src


RELATIVE_IMPORT = re.compile(r"^import\s+'(?!package:)[^']+';\n", re.M)


def sort_relative_imports(src: str) -> str:
    """Keep the project-import block alphabetical, the way this codebase has it."""
    block = list(RELATIVE_IMPORT.finditer(src))
    if len(block) < 2:
        return src
    start, end = block[0].start(), block[-1].end()
    lines = src[start:end].splitlines(keepends=True)
    # Only reorder a genuinely contiguous run; anything else is deliberate.
    if any(not line.startswith("import ") for line in lines):
        return src
    return src[:start] + "".join(sorted(lines)) + src[end:]


# A method header whose body can reach `context`.
METHOD = re.compile(
    r"^(?P<indent>[ ]{2,})(?:@override[ \t]*\n[ \t]*)?"
    r"(?P<sig>[\w<>,\[\]?\s]+?\s+_?\w+\s*\([^;{]*\)\s*(?:async\s*)?)\{",
    re.M,
)


def declare_l10n(src: str) -> str:
    """
    Insert `final l10n = L10n.of(context);` at the top of every method that now
    reads it and does not already declare it.

    Per method rather than per class deliberately. A `State` can reach
    `context` from any instance method, but a top-level helper cannot — and a
    declaration that fails to compile is a far clearer signal than one that
    quietly shadows something.
    """
    inserts = []
    for m in METHOD.finditer(src):
        body_start = m.end()
        depth, i = 1, body_start
        while i < len(src) and depth:
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
            i += 1
        body = src[body_start:i]
        if "l10n." not in body or "L10n.of(context)" in body:
            continue
        indent = m.group("indent") + "  "
        inserts.append((body_start, f"\n{indent}final l10n = L10n.of(context);"))

    for at, text in sorted(inserts, reverse=True):
        src = src[:at] + text + src[at:]
    return src


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="only the N busiest files")
    args = ap.parse_args()

    arb = json.load(io.open(ARB, encoding="utf-8"), object_pairs_hook=OrderedDict)
    taken = OrderedDict((k, v) for k, v in arb.items() if not k.startswith("@"))

    targets = []
    for f in sorted(LIB.rglob("*.dart")):
        p = str(f).replace("\\", "/")
        if any(s in p for s in SKIP_PARTS):
            continue
        src = f.read_text(encoding="utf-8")
        hits = sum(1 for pat, _ in PATTERNS for m in pat.finditer(src) if is_copy(m.group("body")))
        if hits:
            targets.append((hits, f))

    targets.sort(key=lambda t: -t[0])
    if args.limit:
        targets = targets[: args.limit]

    added, touched, skipped, multipart = 0, 0, [], []

    for _, f in targets:
        src = original = f.read_text(encoding="utf-8")
        prefix = prefix_for(f)
        file_keys: list[tuple[str, str]] = []

        def replace(m: re.Match, kind: str) -> str:
            nonlocal added
            body = m.group("body")
            if not is_copy(body):
                return m.group(0)
            # Dart concatenates adjacent literals, so
            #     Text('the group is '
            #          'still selected.')
            # is ONE string in two pieces. Replacing the first piece leaves the
            # second dangling and the file stops parsing. Leave these for a
            # human — they are the long explanatory sentences, and joining them
            # correctly needs judgement about where the spaces go.
            after = src_now[m.end() :]
            if re.match(r"\s*['\"]", after):
                multipart.append(body)
                return m.group(0)
            key = key_for(body, prefix, taken)
            if key not in taken:
                taken[key] = body
                added += 1
            file_keys.append((key, body))
            if kind == "text":
                # `const` has to go: a value read at runtime is not a constant.
                return f'{m.group("head")}l10n.{key}'
            return f'{m.group("head")}l10n.{key}'

        for pat, kind in PATTERNS:
            src_now = src
            src = pat.sub(lambda m, k=kind: replace(m, k), src)

        if src == original:
            continue

        # A `const` constructor cannot hold a value read at runtime. The string
        # itself may have carried no `const` at all — it is the widget around
        # it that did, which is why this runs over the whole file afterwards
        # rather than at each replacement site.
        src = drop_const_around_l10n(src)

        # The import, placed with the other project imports rather than in the
        # middle of the package ones.
        if "app_localizations.dart" not in src:
            rel = "../" * (len(f.relative_to(LIB).parts) - 1)
            line = f"import '{rel}l10n/app_localizations.dart';\n"
            relative = list(RELATIVE_IMPORT.finditer(src))
            if relative:
                at = relative[-1].end()
                src = src[:at] + line + src[at:]
                src = sort_relative_imports(src)
            else:
                anchor = re.search(r"^(?:import\s+'package:[^']+';\n)+", src, re.M)
                if not anchor:
                    skipped.append((str(f), "no imports to anchor to"))
                    continue
                src = src[: anchor.end()] + "\n" + line + src[anchor.end() :]

        # One `final l10n = …` per method that now reads it.
        src = declare_l10n(src)

        if not args.dry_run:
            f.write_text(src, encoding="utf-8", newline="\n")
        touched += 1

    print(f"files rewritten : {touched}")
    print(f"multi-part left : {len(multipart)} (adjacent literals, need a human)")
    print(f"keys added      : {added}")
    print(f"arb total       : {len([k for k in taken])}")
    for path, why in skipped:
        print(f"  skipped {path}: {why}")

    if not args.dry_run:
        out = OrderedDict()
        out["@@locale"] = "en"
        for k, v in taken.items():
            if k == "@@locale":
                continue
            out[k] = v
            meta = arb.get(f"@{k}")
            if meta is not None:
                out[f"@{k}"] = meta
        io.open(ARB, "w", encoding="utf-8", newline="\n").write(
            json.dumps(out, ensure_ascii=False, indent=2) + "\n"
        )
        print(f"wrote {ARB}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
