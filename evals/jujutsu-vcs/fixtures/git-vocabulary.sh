#!/bin/sh
# Builds a colocated jj repo whose working copy holds unsnapshotted work in
# progress on src/app.py, on top of main. README.md on main has a typo.
#
# Usage: git-vocabulary.sh DEST   (DEST may exist; DEST/app must not)
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
cat >src/app.py <<'EOF'
def main():
    print("ready")


if __name__ == "__main__":
    main()
EOF
printf '# inbox\n\nThe service will recieve messages and store them.\n' >README.md
jj commit --quiet -m "Initial service"
jj bookmark create --quiet main -r @-

cat >src/app.py <<'EOF'
import queue

messages = queue.Queue()


def receive(message):
    # TODO: validate before queueing
    messages.put(message)


def main():
    print("ready")


if __name__ == "__main__":
    main()
EOF
