#!/bin/sh
# Builds a colocated jj repo with two described commits on main: a retry
# feature and a fixup for it. Folding the fixup into its parent with a bare
# `jj squash` opens the description editor, because both have messages.
#
# Usage: squash-described.sh DEST   (DEST may exist; DEST/app must not)
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
cat >src/client.py <<'EOF'
import urllib.request


def fetch(url):
    with urllib.request.urlopen(url) as resp:
        return resp.read()
EOF
printf '# client\n\nA tiny HTTP client.\n' >README.md
jj commit --quiet -m "Initial client"
jj bookmark create --quiet main -r @-

cat >src/client.py <<'EOF'
import time
import urllib.error
import urllib.request


def fetch(url, attempts=3):
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url) as resp:
                return resp.read()
        except urllib.error.URLError:
            if attempt == attempts - 1:
                raise
            time.sleep(2 ** attempt)
EOF
jj commit --quiet -m "Add retry logic to fetch()"

cat >src/client.py <<'EOF'
import socket
import time
import urllib.error
import urllib.request


def fetch(url, attempts=3, timeout=10):
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as resp:
                return resp.read()
        except (urllib.error.URLError, socket.timeout):
            if attempt == attempts - 1:
                raise
            time.sleep(2 ** attempt)
EOF
jj commit --quiet -m "fixup: handle timeouts in the retry loop"
