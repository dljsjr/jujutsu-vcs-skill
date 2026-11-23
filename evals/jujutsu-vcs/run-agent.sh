#!/bin/sh
# Runs one headless Sandpiper agent in a clean environment for the evals:
# no context files, no skill catalog except the run's own skill copy, no MCP,
# no user jj config, and a Sandpiper agent dir that loads only the model
# provider. Tattler runs in its own namespace so the operator's peers cannot
# reach it.
#
# Usage: run-agent.sh MODEL PROMPT
#   Run from the agent's working directory. When ./skills/jujutsu-vcs exists
#   (a candidate run), it is the whole skill catalog.
# Requires JJ_EVALS_AGENT_DIR: a Sandpiper agent dir with settings.json and auth.json.
set -eu

if [ $# -ne 2 ]; then
  echo "usage: $0 MODEL PROMPT" >&2
  exit 2
fi
model=$1
prompt=$2
: "${JJ_EVALS_AGENT_DIR:?set JJ_EVALS_AGENT_DIR to the clean Sandpiper agent dir}"

set -- --no-skills
if [ -d skills/jujutsu-vcs ]; then
  set -- --no-skills --skill skills/jujutsu-vcs
fi

SANDPIPER_CODING_AGENT_DIR=$JJ_EVALS_AGENT_DIR
TATTLER_RUNTIME_NAMESPACE=jj-evals
JJ_CONFIG=
JJ_USER="Eval User"
JJ_EMAIL=eval@example.com
export SANDPIPER_CODING_AGENT_DIR TATTLER_RUNTIME_NAMESPACE JJ_CONFIG JJ_USER JJ_EMAIL

exec sandpiper -p --mode json --no-session --no-context-files "$@" --no-mcp --no-approve \
  --model "$model" --thinking high "$prompt"
