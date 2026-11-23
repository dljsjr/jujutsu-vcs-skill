#!/bin/sh
# Builds a colocated jj repo whose `feature` stack is behind main on a local
# bare origin, with a one-line conflict and an unrelated README edit left
# unsnapshotted in the working copy.
#
# Usage: rebase-conflict.sh DEST   (DEST may exist; DEST/app and DEST/origin.git must not)
# Creates DEST/origin.git (bare) and DEST/app (the repo under test).
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
cat >src/greet.py <<'EOF'
def greet(name):
    return "Hello, " + name + "!"
EOF
cat >src/cli.py <<'EOF'
import sys
from greet import greet

if __name__ == "__main__":
    print(greet(sys.argv[1]))
EOF
printf '# greeter\n\nPrints a greeting.\n' >README.md
jj commit --quiet -m "Initial greeter"
jj bookmark create --quiet main -r @-
jj git push --quiet -b main

jj new --quiet main
cat >src/greet.py <<'EOF'
def greet(name):
    return f"Hello, {name}!"


def farewell(name):
    return f"Goodbye, {name}!"
EOF
jj commit --quiet -m "Add farewell() and use f-strings in greet.py"
cat >src/cli.py <<'EOF'
import sys
from greet import farewell, greet

if __name__ == "__main__":
    name = sys.argv[1]
    print(greet(name))
    print(farewell(name))
EOF
jj commit --quiet -m "Print a farewell from the CLI"
jj bookmark create --quiet feature -r @-

jj git clone --quiet "$dest/origin.git" "$dest/teammate"
cd "$dest/teammate"
cat >src/greet.py <<'EOF'
def greet(name):
    return "Hi, " + name + "!"
EOF
jj commit --quiet -m "Use a friendlier greeting"
jj bookmark move --quiet main --to @-
jj git push --quiet -b main
cd "$dest/app"
rm -rf "$dest/teammate"

printf '# greeter\n\nPrints a greeting and a farewell.\n\nTODO: document the CLI arguments.\n' >README.md
