#!/bin/sh
# Builds a colocated jj repo with a local bare origin and a three-change stack
# on main, each change with a pushed, tracked bookmark: config-parser,
# config-cli, config-docs.
#
# Usage: stacked-feedback.sh DEST   (DEST may exist; DEST/app and DEST/origin.git must not)
set -eu
if [ $# -ne 1 ]; then
  echo "usage: $0 DEST" >&2
  exit 2
fi
if [ -e "$1/app" ] || [ -e "$1/origin.git" ]; then
  echo "error: $1 already holds a fixture" >&2
  exit 1
fi
mkdir -p "$1"
dest=$(cd "$1" && pwd)
export JJ_CONFIG='' JJ_USER="Fixture Author" JJ_EMAIL="author@example.com" JJ_EDITOR=false

git init --quiet --bare "$dest/origin.git"
jj git init --quiet --colocate "$dest/app"
cd "$dest/app"
jj git remote add origin "$dest/origin.git"
mkdir src
cat >src/cli.py <<'PY'
import sys


def main(argv):
    print("args:", argv)
PY
printf '# tool\n\nA small command-line tool.\n' >README.md
jj commit --quiet -m "Initial tool"
jj bookmark create --quiet main -r @-
jj git push --quiet -b main

cat >src/config.py <<'PY'
def load(text):
    result = {}
    for line in text.splitlines():
        key, _, value = line.partition("=")
        if key.strip():
            result[key.strip()] = value.strip()
    return result
PY
jj commit --quiet -m "Add a config parser"
jj bookmark create --quiet config-parser -r @-
cat >src/cli.py <<'PY'
import sys

from config import load


def main(argv):
    if argv and argv[0] == "--config":
        with open(argv[1]) as f:
            print(load(f.read()))
        return
    print("args:", argv)
PY
jj commit --quiet -m "Read a config file from the CLI"
jj bookmark create --quiet config-cli -r @-
# shellcheck disable=SC2016  # literal backticks in Markdown
printf '# tool\n\nA small command-line tool.\n\n## Configuraton\n\nPass `--config FILE` with KEY=VALUE lines.\n' >README.md
jj commit --quiet -m "Document the config file"
jj bookmark create --quiet config-docs -r @-
jj git push --quiet -b config-parser -b config-cli -b config-docs
