# Megamerge

A megamerge is a merge commit whose parents are several lines of work in progress, called arms; each arm usually carries a bookmark. Work happens in a change on top of the merge, so every arm can be built and tested together, and each edit is then moved into the arm it belongs to. The merge commit itself is never pushed.

Use it when two or more lines of work are in flight and need to run together or be worked on in turn. For a single line of work, work on it directly.

In the commands below, `MM` is the merge commit's change ID, and `TRUNK` is the trunk bookmark, such as `main`.

Commands below use `trunk()`. In a repo with no remote it resolves to `root()`; use the trunk bookmark's name instead, such as `main`.

## Contents

- [Set up](#set-up) and [route edits into arms](#route-edits-into-arms)
- [Add an arm](#add-an-arm), [drop an arm](#drop-an-arm), [keep it current](#keep-it-current)
- [Integrate an arm into trunk](#integrate-an-arm-into-trunk) and [simplify the merge's parents](#simplify-the-merges-parents)
- [Conflicts](#conflicts), [push](#push), [finish](#finish)

## Set up

```sh
jj new ARM_A ARM_B ARM_C -m megamerge
jj new
```

Parents can be bookmarks or change IDs. Keep the merge commit empty and do all work in the change on top, `@`.

The merge commit should never be pushed. It is a good idea to enforce that with `git.private-commits`, the revset of commits `jj git push` refuses to send, for example `subject(glob:"megamerge*")`. A repository setting replaces the user's, so keep any existing value: `subject(glob:"megamerge*") | EXISTING`.

## Route edits into arms

Edit in `@`, then move each edit to the arm it belongs to:

| Change | Command |
| --- | --- |
| Edits to lines an arm already changed | `jj absorb`. Each hunk moves into the arm commit that last changed those lines; ambiguous hunks stay in `@`. |
| New files, or lines no arm touched | `jj squash --into ARM PATHS` |
| A new commit on top of an arm | `jj new -A ARM_TIP -B MM --no-edit -m "msg"`, then `jj squash --into NEW PATHS` and `jj bookmark move NAME --to NEW` |

`NEW` is the change ID that `jj log` shows for the commit just created. When routing is done, `jj diff` in `@` is empty.

## Add an arm

- **A new arm:** `jj new -A 'trunk()' -B MM --no-edit -m "msg"` creates an empty commit on trunk and makes it another parent of the merge, without moving `@`. Move work into it with `jj squash --into NEW PATHS`, then name it with `jj bookmark create NAME -r NEW`.
- **An existing line of work:** `jj rebase -s MM -o 'MM- | NAME'` adds `NAME` to the merge's parents. If `NAME` builds on another arm, [simplify the parents](#simplify-the-merges-parents) afterwards.

## Drop an arm

`jj rebase -s MM -o 'MM- ~ NAME'` removes `NAME` from the merge's parents. The arm stays in the repo as its own head.

## Keep it current

```sh
jj git fetch
jj rebase -s 'roots(trunk()..@)' -o 'trunk()' --skip-emptied
jj simplify-parents -r MM
```

The rebase moves every arm, the merge, and `@` onto the new trunk at once. `--skip-emptied` abandons commits whose edits already landed upstream. `jj simplify-parents` drops merge parents that trunk now contains.

## Integrate an arm into trunk

**Through a pull request**, or any merge done on the remote: once it lands, run [Keep it current](#keep-it-current). If the forge kept the arm's commits (a merge commit), they become part of trunk. If it squashed or rebased them, `--skip-emptied` abandons the local copies once they are empty. Either way, `jj simplify-parents` then drops the arm from the merge.

**Locally, by moving the trunk bookmark** onto the arm, when the arm already sits on the current trunk (run [Keep it current](#keep-it-current) first if it does not):

```sh
jj bookmark move TRUNK --to ARM_TIP
jj rebase -s 'roots(TRUNK..@)' -o TRUNK
jj simplify-parents -r MM
```

The bookmark moves forward, the other arms are rebased onto the new trunk, and the integrated arm's tip leaves the merge's parents because the other arms now descend from it. Use the bookmark name here, not `trunk()`: `trunk()` follows the remote bookmark, which does not move until `jj git push -b TRUNK` publishes the change.

## Simplify the merge's parents

`jj simplify-parents -r MM` removes merge parents that are ancestors of other parents. The merge's contents stay the same. Run it:

- after an arm lands in trunk and the other arms are rebased onto it, because the landed arm is now an ancestor of theirs;
- after stacking one arm on another, because the lower arm is then an ancestor of the upper one;
- after adding a line of work that builds on an existing arm.

## Conflicts

Conflicts do not stop the megamerge. After a rebase, a conflicted arm can wait while work continues on the others: edits still route into them with `jj absorb` or `jj squash --into`, and they still push. In `@`, conflict markers appear only in the conflicted arm's files. Resolve an arm before pushing it, which jj refuses while it is conflicted, or before building or testing code that depends on it.

- **An arm conflicts with trunk** after the rebase: the conflict is in that arm's commits. Resolve it there with the conflict procedure in [SKILL.md](../SKILL.md#conflicts). The merge and `@` inherit it and clear once the arm is fixed.
- **Only the merge commit is conflicted**: two arms change the same lines, and neither is wrong on its own. Resolve the markers in `@` and `jj squash` the resolution into the merge. The merge then holds that resolution, which is acceptable because it is never pushed. If one arm really depends on the other, stack it instead with `jj rebase -s ROOT_OF_B -o TIP_OF_A`, then simplify the parents.

## Push

The merge carries no bookmark, so pushing bookmarks never sends it. From `@`, a bare `jj git push` updates every tracked arm bookmark under the merge at once; `jj git push -b NAME` sends one arm, and is how a new, untracked arm goes up the first time.

Do not use `jj git push -c @-` here. `@-` is the merge commit, so it would create a bookmark on the merge and push the merge along with every arm beneath it.

## Finish

When only one arm is left, the merge has a single parent. If it is empty, `jj abandon MM`; `@` moves onto the arm.

Before reporting, check with `jj log -r 'trunk()..@' --summary` that each arm holds only its own edits, the merge is empty unless it holds a cross-arm resolution, and `@` is an empty change on top of the merge.
