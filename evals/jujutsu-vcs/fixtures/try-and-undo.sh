#!/bin/sh
# Builds a colocated jj repo where `feature` (three commits) sits on an old
# main. Rebasing it onto the current main succeeds without conflicts, but a
# test then fails because main renamed slugify() to make_slug().
#
# Usage: try-and-undo.sh DEST   (DEST may exist; DEST/app must not)
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
cat >src/textutil.py <<'EOF'
import re


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
EOF
cat >tests/test_textutil.py <<'EOF'
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import textutil  # noqa: E402


class TextutilTest(unittest.TestCase):
    def test_slug(self):
        self.assertEqual(textutil.slugify("Hello, World"), "hello-world")
EOF
printf '# textutil\n\nSmall text helpers.\n' >README.md
jj commit --quiet -m "Initial textutil"
jj bookmark create --quiet base -r @-

# The feature stack, on the initial commit.
cat >>src/textutil.py <<'EOF'


def title_case(text):
    return " ".join(word.capitalize() for word in text.split())
EOF
jj commit --quiet -m "Add title_case()"
cat >src/headline.py <<'EOF'
from textutil import slugify


def headline(text):
    return slugify(text).upper()
EOF
cat >tests/test_headline.py <<'EOF'
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import headline  # noqa: E402


class HeadlineTest(unittest.TestCase):
    def test_headline(self):
        self.assertEqual(headline.headline("Big News"), "BIG-NEWS")
EOF
jj commit --quiet -m "Add headline() built on slugify()"
# shellcheck disable=SC2016  # literal backticks in Markdown
printf '# textutil\n\nSmall text helpers.\n\n`headline()` turns a title into an upper-case slug.\n' >README.md
jj commit --quiet -m "Document headline()"
jj bookmark create --quiet feature -r @-

# Main moves on separately: slugify() is renamed.
jj new --quiet base
cat >src/textutil.py <<'EOF'
import re


def make_slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
EOF
sed 's/slugify/make_slug/' tests/test_textutil.py >tests/test_textutil.py.new
mv tests/test_textutil.py.new tests/test_textutil.py
jj commit --quiet -m "Rename slugify() to make_slug()"
jj bookmark create --quiet main -r @-
jj bookmark delete --quiet base

# The working copy goes back on top of feature, as the user left it.
jj new --quiet feature
