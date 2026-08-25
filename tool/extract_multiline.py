"""
Second extraction pass: the sentences Dart splits across lines.

    Text(
      'Pull down to try again. If it keeps happening, check the group is '
      'still selected under Cloud Account.',
    )

Dart concatenates adjacent literals, so that is one sentence wearing two pairs
of quotes. The first pass skipped every one of them — replacing only the first
piece leaves the second dangling and the file stops parsing — and they are
precisely the strings that matter most: the long explanations a user reads when
something has gone wrong, in the language they chose.

Joining them is the whole job. The rule for the seam is Dart's own: the pieces
are concatenated exactly as written, so the result is the pieces joined with
nothing between them. Any spacing already lives at the end of a piece.

    python tool/extract_multiline.py --dry-run
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
ARB = LIB / "l10n" / "app_en.arb"

# Files with no BuildContext: PDF builders and static catalogues are localised
# by having strings passed in, not by a lookup.
# Only the UI layer. `core/database` holds SQL, `core/network` holds diagnostic
# messages for a log, and neither has a BuildContext to read a translation
# from — the first pass skipped them for the same reason and this one must
# too. PDF builders and static catalogues take their strings as arguments.
SKIP = (
    "/l10n/",
    "/core/database/",
    "/core/network/",
    "/data/models/",
    "/data/repositories/",
    "/data/services/",
    "/providers/",
    "/reports/pdf_report",
    "/reports/member_pdf",
    "mentorship_catalogue",
)

# Two or more adjacent single-quoted literals, optionally preceded by `const`.
#
# Interpolated pieces are matched too, even though none of them can ever be
# extracted. Excluding them was the bug: the pattern then began its chain AFTER
# an interpolated piece, cutting one logical run in half and joining the tail
# as though it stood alone — which silently corrupted the expression it came
# from. Match the whole run; `replace` then refuses the whole run if any piece
# interpolates.
CHAIN = re.compile(
    r"(?P<pre>\bconst\s+)?"
    r"(?P<head>(?:Text|Tooltip|SnackBar)?\(?\s*)?"
    r"(?P<chain>'(?:[^'\\]|\\.)*'(?:\s*\n\s*'(?:[^'\\]|\\.)*')+)"
)


def pieces_of(chain: str) -> list[str]:
    return re.findall(r"'((?:[^'\\]|\\.)*)'", chain)


def key_for(text: str, prefix: str, taken: dict[str, str]) -> str:
    for existing, value in taken.items():
        if value == text:
            return existing
    words = re.findall(r"[A-Za-z0-9]+", text)[:6]
    slug = words[0].lower() + "".join(w.capitalize() for w in words[1:])
    base = f"{prefix}{slug[0].upper()}{slug[1:]}"
    key, n = base, 2
    while key in taken:
        key, n = f"{base}{n}", n + 1
    return key


def prefix_for(path: Path) -> str:
    name = path.stem
    for tail in ("_screen", "_sheet", "_dialog", "_card", "_view", "_section"):
        name = name.removesuffix(tail)
    parts = name.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def drop_const_around_l10n(src: str) -> str:
    doomed = []
    for m in re.finditer(r"\bconst\s+(?=[A-Z_])", src):
        open_paren = src.find("(", m.end())
        if open_paren == -1:
            continue
        depth, i = 1, open_paren + 1
        while i < len(src) and depth:
            depth += (src[i] == "(") - (src[i] == ")")
            i += 1
        if "l10n." in src[open_paren:i]:
            doomed.append((m.start(), m.end()))
    for m in re.finditer(r"\bconst\s+(?=[\[{])", src):
        opener = src[m.end()]
        closer = "]" if opener == "[" else "}"
        depth, i = 1, m.end() + 1
        while i < len(src) and depth:
            depth += (src[i] == opener) - (src[i] == closer)
            i += 1
        if "l10n." in src[m.end() : i]:
            doomed.append((m.start(), m.end()))
    for start, end in sorted(set(doomed), reverse=True):
        src = src[:start] + src[end:]
    return src


METHOD = re.compile(
    r"^(?P<indent>[ ]{2,})(?:@override[ \t]*\n[ \t]*)?"
    r"(?P<sig>[\w<>,\[\]?\s]+?\s+_?\w+\s*\([^;{]*\)\s*(?:async\s*)?)\{",
    re.M,
)


def declare_l10n(src: str) -> str:
    inserts = []
    for m in METHOD.finditer(src):
        start = m.end()
        depth, i = 1, start
        while i < len(src) and depth:
            depth += (src[i] == "{") - (src[i] == "}")
            i += 1
        body = src[start:i]
        if "l10n." not in body or "L10n.of(context)" in body:
            continue
        inserts.append((start, f"\n{m.group('indent')}  final l10n = L10n.of(context);"))
    for at, text in sorted(inserts, reverse=True):
        src = src[:at] + text + src[at:]
    return src


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    arb = json.load(io.open(ARB, encoding="utf-8"), object_pairs_hook=OrderedDict)
    taken = OrderedDict((k, v) for k, v in arb.items() if not k.startswith("@"))

    added = touched = 0
    for f in sorted(LIB.rglob("*.dart")):
        p = str(f).replace("\\", "/")
        if any(s in p for s in SKIP):
            continue

        src = original = f.read_text(encoding="utf-8")
        prefix = prefix_for(f)

        def replace(m: re.Match) -> str:
            nonlocal added
            parts = pieces_of(m.group("chain"))
            # One interpolated piece anywhere in the run disqualifies all of
            # it: the run is a single expression and half of it cannot move.
            if any("$" in part for part in parts):
                return m.group(0)
            joined = "".join(parts)
            # Only real prose. Anything short, or without a space, is a code.
            if len(joined) < 12 or " " not in joined or "$" in joined:
                return m.group(0)
            # Braces mean the joiner has straddled a `${...}` interpolation:
            #     'sent${x ? ' to $phone' : ' to your phone'}'
            #     '. Type it below.'
            # where the last two literals only LOOK adjacent — one of them
            # lives inside the interpolation. Joining those corrupts the
            # source, so anything carrying a brace is left for a human.
            if "{" in joined or "}" in joined:
                return m.group(0)
            # …and the same shape without a brace surviving into the text:
            # an unclosed `${` anywhere before the chain on its own line.
            line_start = src_now.rfind(chr(10), 0, m.start()) + 1
            before = src_now[line_start : m.start()]
            if before.count("${") > before.count("}"):
                return m.group(0)
            key = key_for(joined, prefix, taken)
            if key not in taken:
                taken[key] = joined
                added += 1
            head = m.group("head") or ""
            return f"{head}l10n.{key}"

        src_now = src
        src = CHAIN.sub(replace, src)
        if src == original:
            continue

        src = drop_const_around_l10n(src)

        if "app_localizations.dart" not in src:
            rel = "../" * (len(f.relative_to(LIB).parts) - 1)
            line = f"import '{rel}l10n/app_localizations.dart';\n"
            relative = list(re.finditer(r"^import\s+'(?!package:)[^']+';\n", src, re.M))
            if relative:
                at = relative[-1].end()
                src = src[:at] + line + src[at:]
            else:
                anchor = re.search(r"^(?:import\s+'package:[^']+';\n)+", src, re.M)
                src = src[: anchor.end()] + "\n" + line + src[anchor.end() :]

        src = declare_l10n(src)

        if not args.dry_run:
            f.write_text(src, encoding="utf-8", newline="\n")
        touched += 1

    print(f"files rewritten : {touched}")
    print(f"keys added      : {added}")

    if not args.dry_run:
        out = OrderedDict()
        out["@@locale"] = "en"
        for k, v in taken.items():
            if k == "@@locale":
                continue
            out[k] = v
            if f"@{k}" in arb:
                out[f"@{k}"] = arb[f"@{k}"]
        io.open(ARB, "w", encoding="utf-8", newline="\n").write(
            json.dumps(out, ensure_ascii=False, indent=2) + "\n"
        )
        print(f"template now    : {len([k for k in out if not k.startswith('@')])} keys")

    return 0


if __name__ == "__main__":
    sys.exit(main())
