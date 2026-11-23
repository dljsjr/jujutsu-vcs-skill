# Stacked changes

A stack is a line of small changes on trunk, each reviewable on its own, usually one bookmark and one pull request per change. jj keeps a stack easy to maintain: editing a lower change rebases everything above it automatically, review fixes route to the right change in one command, and a single push updates every bookmark.

Use it when a task is bigger than one reviewable commit. For one change, commit and push it directly.

Commands below use `trunk()`. In a repo with no remote it resolves to `root()`; use the trunk bookmark's name instead, such as `main`.

## Contents

- [Plan the stack](#plan-the-stack) and [fill it in](#fill-it-in)
- [Revise a lower change](#revise-a-lower-change) and [reshape the stack](#reshape-the-stack)
- [Check every change](#check-every-change), [push](#push), [land the bottom change](#land-the-bottom-change)

## Plan the stack

When the steps are known up front, record them as empty, described changes before writing code. The commits then line up with the plan, and each description states its step's intent:

```sh
jj new 'trunk()' -m "Add the config parser"
jj new -m "Use the parser in the CLI"
jj new -m "Document the config file"
```

To add a step later, insert it without moving `@`: `jj new -A STEP --no-edit -m "msg"` puts a new change right after `STEP`, and everything above it moves up.

The same idea works for work that is not scheduled yet: keep empty, described to-do changes off to the side, on trunk or on a parked base change. When one comes up, move it onto the real work with `jj rebase -s TODO -o REV`, which brings along any to-dos stacked on it, and fill it in. Empty changes never conflict, so moving them costs nothing. To keep them local, give their descriptions a common prefix and cover it with `git.private-commits`.

## Fill it in

Work through the steps from the bottom. For a planned empty change, edit it in place:

```sh
jj edit FIRST_STEP          # @ is now the step itself
# ...edit files...
jj next --edit              # move @ to the next step up
```

Files edited while `@` is a step belong to that step, and the steps above are rebased on each command. Steps with no plan yet can be built the ordinary way: work in `@` at the top and `jj commit` each finished step.

## Revise a lower change

Make the edits in a new change at the top of the stack, then route them down:

| Edits | Command |
| --- | --- |
| Fixes to lines a lower change introduced, such as review feedback | `jj absorb`. Each hunk moves into the change that last touched those lines; ambiguous hunks stay in `@`. |
| New files, or lines no change touched | `jj squash --into STEP PATHS` |
| A new message for a step | `jj describe STEP -m "msg"` |

Everything above the revised change is rebased automatically. If a rebase conflicts, the conflict is recorded in the affected changes and work continues; resolve it with the conflict procedure in [SKILL.md](../SKILL.md#conflicts) before pushing those changes.

## Reshape the stack

| Goal | Command |
| --- | --- |
| Reorder: put C before B | `jj rebase -r C -B B` |
| Combine two steps | `jj squash --from UPPER --into LOWER -u` (keeps the lower step's message) |
| Split a step | `jj split -r STEP PATHS -m "msg for the PATHS part"` |
| Drop a step | `jj abandon STEP` |
| Make independent steps separate pull requests | See [reshape-history.md](reshape-history.md#make-changes-independent) |

## Check every change

- Run a test command on every change without altering any of them: `jj run --ignore-changes -r 'trunk()..@ ~ empty()' -- TEST_COMMAND`. It stops with the first failing revision named in the error. Each revision runs in its own checkout under `.jj/run/`, which holds only tracked files: ignored files such as installed dependencies or build caches are absent, so the command must work from a clean checkout.
- Apply the formatters configured in `fix.tools` to every change in the stack: `jj fix`. It never creates conflicts.

## Push

- First push, one generated bookmark per change: `jj git push -c 'trunk()..@ ~ empty()'`. Each bookmark is named `push-<change-id>`. To choose names instead, run `jj bookmark create NAME -r STEP` for each step and push with `-b NAME`.
- Later pushes, after any rewrite: a bare `jj git push` updates every tracked bookmark below `@`, force-pushing the rewritten ones safely. Preview with `--dry-run`.
- A bookmark stays on its change through rewrites. If a new change is added on top of a step that has a pull request, move that step's bookmark: `jj bookmark move NAME --to NEW`.

## Land the bottom change

After the bottom pull request merges on the forge:

```sh
jj git fetch
jj rebase -s 'roots(trunk()..@)' -o 'trunk()' --skip-emptied
```

If the forge kept the commit, it is now part of trunk. If it squashed or rebased it, the local copy becomes empty and `--skip-emptied` abandons it. The rest of the stack sits on the new trunk; push again to update the remaining pull requests.

Before reporting, check with `jj log -r 'trunk()..@' --summary` that each step holds only its own edits and no step is conflicted.
