#!/bin/sh
# Builds a colocated jj repo with two independent bookmarks on main, feat-a
# and feat-b. feat-a's src/a.py contains the typo "teh".
#
# Usage: megamerge-setup.sh DEST   (DEST may exist; DEST/app must not)
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
printf '# app\n' >README.md
jj commit --quiet -m "Initial app"
jj bookmark create --quiet main -r @-
jj new --quiet main -m "Add greeting helper"
cat >src/a.py <<'PY'
def greet(name):
    # Return teh greeting for name.
    return "Hello, " + name
PY
jj bookmark create --quiet feat-a -r @
jj new --quiet main -m "Add farewell helper"
mkdir -p src
cat >src/b.py <<'PY'
def farewell(name):
    return "Goodbye, " + name
PY
jj bookmark create --quiet feat-b -r @
jj new --quiet main
