"""
Loads a finished translation CSV back into its `.arb`.

The counterpart to the files in `docs/translation/`. A native speaker fills in
the last column and this puts the result where Flutter reads it, in the same
key order as the English template so the files stay diffable.

    python tool/import_translations.py docs/translation/luo-to-translate.csv

Blank rows are skipped rather than written as empty strings: blank means "I was
not sure", and an empty string would render as nothing on screen where a
missing key correctly falls back to English.
"""

from __future__ import annotations

import csv
import io
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB_DIR = ROOT / "lib" / "l10n"

PLACEHOLDER = re.compile(r"\{(\w+)\}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2

    path = Path(argv[1])
    code = path.stem.split("-")[0]
    arb_path = ARB_DIR / f"app_{code}.arb"
    if not arb_path.exists():
        print(f"no such language file: {arb_path}", file=sys.stderr)
        return 1

    english = json.load(io.open(ARB_DIR / "app_en.arb", encoding="utf-8"))
    keys = [k for k in english if not k.startswith("@")]
    current = json.load(io.open(arb_path, encoding="utf-8"), object_pairs_hook=OrderedDict)

    added = skipped = 0
    problems: list[str] = []

    with io.open(path, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            key = (row.get("key") or "").strip()
            value = next(
                (v.strip() for k, v in row.items() if k and k.endswith("_translation")),
                "",
            )
            if not key or not value:
                skipped += 1
                continue
            if key not in english:
                problems.append(f"{key}: not a key in the English template")
                continue

            # The app substitutes a value at each placeholder. Losing one
            # renders a sentence with a hole in it, so this is refused rather
            # than imported and discovered on a phone.
            want = set(PLACEHOLDER.findall(english[key]))
            got = set(PLACEHOLDER.findall(value))
            if want != got:
                problems.append(
                    f"{key}: placeholders {sorted(want)} expected, {sorted(got)} found"
                )
                continue

            current[key] = value
            added += 1

    out = OrderedDict([("@@locale", code)])
    if "_comment" in current:
        out["_comment"] = current["_comment"]
    for key in keys:
        if key in current:
            out[key] = current[key]

    io.open(arb_path, "w", encoding="utf-8", newline="\n").write(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n"
    )

    total = len([k for k in out if not k.startswith("@") and k != "_comment"])
    print(f"imported {added}, left blank {skipped}")
    print(f"{code}: {total}/{len(keys)} ({round(100 * total / len(keys))}%)")
    for problem in problems:
        print(f"  ! {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
