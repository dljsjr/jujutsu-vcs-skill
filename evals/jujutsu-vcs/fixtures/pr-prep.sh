#!/bin/sh
# Builds a colocated jj repo with a local bare origin and an undescribed
# working-copy change that mixes a parser fix, its new test, and a stray
# debug.log, left unsnapshotted.
#
# Usage: pr-prep.sh DEST   (DEST must not exist)
# Creates DEST/origin.git (bare) and DEST/app (the repo under test).
set -eu

if [ $# -ne 1 ]; then
  echo "usage: $0 DEST" >&2
  exit 2
fi
if [ -e "$1" ]; then
  echo "error: $1 already exists" >&2
  exit 1
fi
mkdir -p "$1"
dest=$(cd "$1" && pwd)

export JJ_CONFIG='' JJ_USER="Fixture Author" JJ_EMAIL="author@example.com" JJ_EDITOR=false

git init --quiet --bare "$dest/origin.git"
jj git init --quiet --colocate "$dest/app"
cd "$dest/app"
jj git remote add origin "$dest/origin.git"

mkdir src tests
cat >src/parser.py <<'EOF'
import os


def parse(line):
    """Split a KEY=VALUE line into a (key, value) pair."""
    key, _, value = line.partition("=")
    return key.strip(), os.path.expandvars(value.strip())
EOF
cat >tests/test_basic.py <<'EOF'
from parser import parse


def test_parse_splits_on_first_equals():
    assert parse("A=b=c") == ("A", "b=c")
EOF
printf '# envparse\n\nParses KEY=VALUE lines.\n' >README.md
jj commit --quiet -m "Initial parser"
jj bookmark create --quiet main -r @-
jj git push --quiet -b main

cat >src/parser.py <<'EOF'
def parse(line):
    """Split a KEY=VALUE line into a (key, value) pair.

    Values are returned literally; environment variables are not expanded.
    """
    key, _, value = line.partition("=")
    return key.strip(), value.strip()
EOF
cat >tests/test_literal_values.py <<'EOF'
from parser import parse


def test_parse_keeps_dollar_signs_literal():
    assert parse("HOME=$HOME") == ("HOME", "$HOME")
EOF
cat >debug.log <<'EOF'
DEBUG parse('HOME=$HOME') -> ('HOME', '/Users/me')
DEBUG parse('PATH=$PATH:/opt/bin') -> ('PATH', '/usr/bin:/bin:/opt/bin')
DEBUG after fix: parse('HOME=$HOME') -> ('HOME', '$HOME')
EOF
