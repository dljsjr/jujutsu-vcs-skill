#!/bin/sh
# Builds a colocated jj repo whose working copy already holds someone else's
# unsnapshotted edits to README.md and src/config.py, on top of main.
#
# Usage: others-changes.sh DEST   (DEST may exist; DEST/app must not)
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

mkdir src
cat >src/cli.py <<'EOF'
import argparse

from config import DEFAULT_GREETING


def main(argv=None):
    parser = argparse.ArgumentParser(prog="greeter")
    parser.add_argument("--name", default="world")
    args = parser.parse_args(argv)
    print(f"{DEFAULT_GREETING}, {args.name}!")


if __name__ == "__main__":
    main()
EOF
cat >src/config.py <<'EOF'
DEFAULT_GREETING = "Hello"
DEFAULT_TIMEOUT = 30
EOF
printf '# greeter\n\nPrints a greeting.\n' >README.md
jj commit --quiet -m "Initial greeter"
jj bookmark create --quiet main -r @-

# shellcheck disable=SC2016  # literal backticks in Markdown
printf '# greeter\n\nPrints a greeting.\n\n## Installation\n\nCopy `src/` somewhere on your PYTHONPATH.\n' >README.md
cat >src/config.py <<'EOF'
DEFAULT_GREETING = "Hello"
DEFAULT_TIMEOUT = 60
EOF
