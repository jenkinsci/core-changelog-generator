#!/usr/bin/env python3

import sys
import ruamel.yaml


def usage():
    print("usage: ./replace-changelog-entry.py version_replacing path_to_changelog_file path_to_new_changelog_entry")
    exit(1)


if len(sys.argv) != 4:
    usage()

version_drafting = sys.argv[1]
changelog_path = sys.argv[2]
new_changelog_entry_path = sys.argv[3]


with open(changelog_path, 'r') as file:
    changelog = file.read()

yaml = ruamel.yaml.YAML()
yaml.indent(sequence=4, offset=2)
yaml.preserve_quotes = True
parsed = yaml.load(changelog)
prev = None

last = next(reversed(parsed))

if last.get('version') == version_drafting:
    parsed.pop()

with open(new_changelog_entry_path, 'r') as file:
    new_changelog_entry = file.read()

new_changelog_yaml_entry = yaml.load(new_changelog_entry)

parsed.insert(len(parsed), new_changelog_yaml_entry[0])

yaml.dump(parsed, sys.stdout)
