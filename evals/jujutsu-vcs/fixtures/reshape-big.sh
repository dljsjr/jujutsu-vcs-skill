#!/bin/sh
# Builds a colocated jj repo with one large described commit on main that
# mixes a parser, its tests, a CLI change, and docs.
#
# Usage: reshape-big.sh DEST   (DEST may exist; DEST/app must not)
set -eu
if [ $# -ne 1 ]; then
  echo "usage: $0 DEST" >&2
  exit 2
fi
if [ -e "$1/app" ]; then
  echo "error: $1/app already exists" >&2
  exit 1
fi
mkdir -p "$1"
dest=$(cd "$1" && pwd)
export JJ_CONFIG='' JJ_USER="Fixture Author" JJ_EMAIL="author@example.com" JJ_EDITOR=false

jj git init --quiet --colocate "$dest/app"
cd "$dest/app"
mkdir src tests
cat >src/cli.py <<'PY'
import sys


def main(argv):
    print("args:", argv)


if __name__ == "__main__":
    main(sys.argv[1:])
PY
printf '# tool\n\nA small command-line tool.\n' >README.md
jj commit --quiet -m "Initial tool"
jj bookmark create --quiet main -r @-

cat >src/config.py <<'PY'
def load(text):
    """Parse KEY=VALUE lines into a dict, skipping blanks and # comments."""
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        result[key.strip()] = value.strip()
    return result
PY
cat >tests/test_config.py <<'PY'
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import config  # noqa: E402


class LoadTest(unittest.TestCase):
    def test_skips_comments(self):
        self.assertEqual(config.load("# c\nA=1\n"), {"A": "1"})
PY
cat >src/cli.py <<'PY'
import sys

from config import load


def main(argv):
    if argv and argv[0] == "--config":
        with open(argv[1]) as f:
            print(load(f.read()))
        return
    print("args:", argv)


if __name__ == "__main__":
    main(sys.argv[1:])
PY
# shellcheck disable=SC2016  # literal backticks in Markdown
printf '# tool\n\nA small command-line tool.\n\n## Configuration\n\nPass `--config FILE` with KEY=VALUE lines. Lines starting with `#` are comments.\n' >README.md
jj commit --quiet -m "WIP: config support"
