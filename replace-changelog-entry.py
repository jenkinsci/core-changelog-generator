#!/usr/bin/env python3

import sys
from io import StringIO

import ruamel.yaml


def usage():
    print("usage: ./replace-changelog-entry.py version_replacing path_to_changelog_file path_to_new_changelog_entry", file=sys.stderr)
    sys.exit(1)


def make_yaml(allow_duplicate_keys=False):
    yaml = ruamel.yaml.YAML()
    yaml.indent(sequence=4, offset=2)
    yaml.preserve_quotes = True
    yaml.allow_duplicate_keys = allow_duplicate_keys
    return yaml


if len(sys.argv) != 4:
    usage()

version_drafting = sys.argv[1]
changelog_path = sys.argv[2]
new_changelog_entry_path = sys.argv[3]


with open(changelog_path, 'r') as file:
    changelog = file.read()

if not changelog.strip():
    print(f"ERROR: changelog file is empty: {changelog_path}", file=sys.stderr)
    sys.exit(1)

# Historical weekly.yml may contain a duplicate key from a hand edit.
# Allow those on load so one bad entry cannot wipe the whole file.
historical_yaml = make_yaml(allow_duplicate_keys=True)
parsed = historical_yaml.load(changelog)

if parsed is None:
    print(f"ERROR: failed to parse changelog file: {changelog_path}", file=sys.stderr)
    sys.exit(1)

last = next(reversed(parsed))

if last.get('version') == version_drafting:
    parsed.pop()

with open(new_changelog_entry_path, 'r') as file:
    new_changelog_entry = file.read()

if not new_changelog_entry.strip():
    print(f"ERROR: new changelog entry is empty: {new_changelog_entry_path}", file=sys.stderr)
    sys.exit(1)

strict_yaml = make_yaml(allow_duplicate_keys=False)
new_changelog_yaml_entry = strict_yaml.load(new_changelog_entry)

if not new_changelog_yaml_entry:
    print("ERROR: new changelog entry did not parse as a YAML sequence", file=sys.stderr)
    sys.exit(1)

try:
    new_entry = new_changelog_yaml_entry[0]
except (TypeError, IndexError, KeyError):
    print("ERROR: new changelog entry must be a YAML sequence of one mapping", file=sys.stderr)
    sys.exit(1)

parsed.insert(len(parsed), new_entry)

# Dump only after a successful merge so a failure cannot produce empty stdout.
buf = StringIO()
historical_yaml.dump(parsed, buf)
output = buf.getvalue()
if not output.strip():
    print("ERROR: merged changelog dump was empty", file=sys.stderr)
    sys.exit(1)
sys.stdout.write(output)
