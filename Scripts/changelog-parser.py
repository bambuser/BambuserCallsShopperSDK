"""
Script: Parse a versioned CHANGELOG entry into release notes

Description:
Extracts the entry for a specific version from CHANGELOG.md and writes
it to build/release-notes.md in a format suitable for the GitHub
Release body.

Usage:
    python3 changelog-parser.py <version>

Output:
    ../build/release-notes.md

The parser looks for the section header:
    ## [X.Y.Z] - YYYY-MM-DD
and copies every line up to (but not including) the next `## [`
header.

Each entry in the source is expected to follow the project's
tag+title convention:
    [Added]\\
    [Title](https://asana.com/...)
The parser reshapes those into a grouped list by tag:
    **[Added]**
    - Title
"""

import os
import re
import sys

VALID_TAGS = ("Added", "Changed", "Deprecated", "Removed", "Fixed")


def parse_version_section(file_path, version):
    """Return the raw lines for `version`'s section, header excluded."""
    section = []
    in_section = False
    header_pattern = re.compile(r"^##\s+\[" + re.escape(version) + r"\]")

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if in_section:
                if line.startswith("## ["):
                    break
                section.append(line.rstrip("\n"))
            elif header_pattern.match(line):
                in_section = True

    return section


def group_by_tag(lines):
    """Group `[Tag]` + `[Title](url)` pairs by tag."""
    grouped = {tag: [] for tag in VALID_TAGS}

    tag_pattern = re.compile(r"^\[(" + "|".join(VALID_TAGS) + r")\]\\?$")
    title_pattern = re.compile(r"^\[([^\]]+)\]\(([^)]+)\)")

    current_tag = None
    for raw in lines:
        line = raw.strip()
        if not line:
            current_tag = None
            continue

        tag_match = tag_pattern.match(line)
        if tag_match:
            current_tag = tag_match.group(1)
            continue

        if current_tag:
            title_match = title_pattern.match(line)
            if title_match:
                title, url = title_match.group(1), title_match.group(2)
                grouped[current_tag].append((title, url))
                current_tag = None

    return grouped


def render(grouped, version):
    lines = [f"## Release v{version}", ""]
    for tag in VALID_TAGS:
        entries = grouped[tag]
        if not entries:
            continue
        lines.append(f"**[{tag}]**")
        for title, url in entries:
            lines.append(f"- [{title}]({url})")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 changelog-parser.py <version>", file=sys.stderr)
        sys.exit(1)

    version = sys.argv[1]
    script_dir = os.path.dirname(os.path.abspath(__file__))
    changelog_path = os.path.join(script_dir, "..", "CHANGELOG.md")
    output_dir = os.path.join(script_dir, "..", "build")
    output_path = os.path.join(output_dir, "release-notes.md")

    section_lines = parse_version_section(changelog_path, version)
    if not section_lines:
        print(f"Error: no [{version}] section found in CHANGELOG.md", file=sys.stderr)
        sys.exit(1)

    grouped = group_by_tag(section_lines)
    body = render(grouped, version)

    os.makedirs(output_dir, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(body)

    print(f"Wrote release notes for v{version} to {output_path}")


if __name__ == "__main__":
    main()
