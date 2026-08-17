"""
Script: Promote CHANGELOG [Unreleased] to a new versioned section

Description:
Moves the content under `## [Unreleased]` into a new section titled
`## [X.Y.Z] - YYYY-MM-DD`, and leaves an empty [Unreleased] header at
the top for future work.

Usage:
    python3 changelog-updater.py <new_version>

Input / Output:
    ../CHANGELOG.md  (modified in-place)
"""

import datetime
import os
import re
import sys


def promote_unreleased(path, new_version):
    date = datetime.datetime.now().strftime("%Y-%m-%d")

    with open(path, "r", encoding="utf-8") as f:
        contents = f.read()

    # Split by the [Unreleased] header. We keep the pre-`[Unreleased]`
    # text (Keep-a-Changelog header, tag legend) verbatim.
    match = re.search(r"(?m)^##\s+\[Unreleased\]\s*$", contents)
    if not match:
        print("Error: '## [Unreleased]' header not found.", file=sys.stderr)
        sys.exit(1)

    head = contents[: match.end()]
    tail = contents[match.end():]

    # Slice out the [Unreleased] body: everything up to the next `## [`.
    next_header = re.search(r"(?m)^##\s+\[", tail)
    if next_header:
        unreleased_body = tail[: next_header.start()]
        rest = tail[next_header.start():]
    else:
        unreleased_body = tail
        rest = ""

    unreleased_body = unreleased_body.strip("\n")

    if not unreleased_body.strip():
        print("Error: [Unreleased] section is empty.", file=sys.stderr)
        sys.exit(1)

    new_release_header = f"\n\n## [{new_version}] - {date}\n\n"

    # Reassemble: preserved head + empty [Unreleased] placeholder +
    # new release section (with the promoted body) + rest of file.
    new_contents = (
        head
        + "\n\n"
        + new_release_header
        + unreleased_body
        + "\n"
        + ("\n" + rest.lstrip("\n") if rest else "")
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_contents)

    print(f"CHANGELOG.md: promoted [Unreleased] → [{new_version}] - {date}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 changelog-updater.py <new_version>", file=sys.stderr)
        sys.exit(1)

    new_version = sys.argv[1]
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", new_version):
        print(f"Error: version '{new_version}' is not semver (X.Y.Z)", file=sys.stderr)
        sys.exit(1)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    changelog_path = os.path.join(script_dir, "..", "CHANGELOG.md")

    promote_unreleased(changelog_path, new_version)


if __name__ == "__main__":
    main()
