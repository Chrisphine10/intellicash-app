"""
Removes Dart string escapes that the extraction pass carried into the ARB.

`'The group\\'s own enterprise'` in Dart is a single-quoted literal, so the
apostrophe has to be escaped. The extractor lifted the SOURCE text rather than
the value, so the backslash travelled into `app_en.arb` — where JSON needs no
such escape — and rendered on screen as a visible backslash: "The group\\'s own
enterprise, not a member\\'s."

Caught by looking at the Group business screen on the phone. No test would
have found it: the string is present, non-empty, correctly keyed, and
translated. It is simply wrong by one character in fourteen places.
"""

from __future__ import annotations

import io
import json
import re
from collections import OrderedDict
from pathlib import Path

ARB_DIR = Path(__file__).resolve().parent.parent / "lib" / "l10n"

# One or more backslashes immediately before a quote character.
STRAY = re.compile(r"\\+(?=['\"])")


def main() -> int:
    total = 0
    for path in sorted(ARB_DIR.glob("app_*.arb")):
        data = json.load(io.open(path, encoding="utf-8"), object_pairs_hook=OrderedDict)
        changed = 0
        for key, value in data.items():
            if not isinstance(value, str):
                continue
            cleaned = STRAY.sub("", value)
            if cleaned != value:
                data[key] = cleaned
                changed += 1
        if changed:
            io.open(path, "w", encoding="utf-8", newline="\n").write(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n"
            )
        print(f"{path.name}: {changed} cleaned")
        total += changed
    print(f"total {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
