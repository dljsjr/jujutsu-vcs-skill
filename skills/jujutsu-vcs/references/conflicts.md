# Conflicts

This reference covers how jj stores, shows, and resolves file conflicts. Bookmark conflicts are covered in [bookmarks-and-remotes.md](bookmarks-and-remotes.md#conflicted-bookmarks); divergent changes in [concepts.md](concepts.md#divergence).

## Model

- An operation that produces conflicts (rebase, merge, squash, restore) **succeeds** and records the conflict in the resulting commit. Descendants are rebased on top as usual.
- A conflicted commit stores an odd-length list of trees, read as `A + (C − B) + (E − D) …`. A 3-way conflict between A and C with base B is `A + (C − B)`.
- Nested conflicts simplify. Rebasing an unresolved conflict `C + (B − A)` from C to D gives `D + (B − A)`, not a conflict of conflicts. Reverting a conflicted commit returns the clean state.
- **Same-change rule:** if every side made the same change, the result is that change (`merge.same-change = "accept"`, the default). Rebasing onto a commit containing the same change and back again can lose that change. Set `merge.same-change = "keep"` to keep such conflicts.
- Conflicts can be rebased, merged, reverted, and shared like any other content.

## Where markers appear

Markers are written only when a conflict is materialized:

- in the working copy, when `@` contains a conflict (after `jj new <conflicted>` or `jj edit <conflicted>`)
- in diff output for commits that add or resolve conflicts

On the next snapshot, jj parses the markers back into a conflict. Editing part of the markers resolves part of the conflict; removing all markers resolves it.

## Marker styles

Set with `ui.conflict-marker-style`, or per tool with `merge-tools.<name>.conflict-marker-style`.

### `diff` (default)

One snapshot and one diff per additional side. Labels identify each term by change ID, commit ID, description, and role.

```text
<<<<<<< conflict 1 of 1
%%%%%%% diff from: vpxusssl 38d49363 "merge base"
\\\\\\\        to: rtsqusxu 2768b0b9 "commit A"
 apple
-grape
+grapefruit
 orange
+++++++ ysrnknol 7a20f389 "commit B"
APPLE
GRAPE
ORANGE
>>>>>>> conflict 1 of 1 ends
```

| Marker | Meaning |
| --- | --- |
| `<<<<<<<` / `>>>>>>>` | Start and end of a conflict |
| `+++++++` | A snapshot: one side's content |
| `%%%%%%%` | A diff to apply to the snapshot |
| `\\\\\\\` | Continuation of a label onto a second line |

To resolve, apply each diff to the snapshot. The example resolves to `APPLE`, `GRAPEFRUIT`, `ORANGE`. Roles in labels include `merge base`, `parents of rebased revision`, `rebase destination`, and `rebased revision`.

### `snapshot`

Each side as a `+++++++` snapshot and the base as a `-------` snapshot.

### `git`

Git's diff3 style: `<<<<<<<` side 1, `|||||||` base, `=======`, side 2, `>>>>>>>`. Labels are change ID, commit ID, and description. Only 2-sided conflicts use this style; others fall back to `snapshot`.

### Marker length

- Markers are normally 7 characters. If the file contains lines that look like markers, jj uses longer markers (for example 15 characters) so parsing stays unambiguous. Parse markers by character and position, not by a fixed length. Merge tools receive the length as `$marker_length`.
- If a term lacks a terminating newline, jj adds one to each term, omits it after the `>>>>>>>` line, and labels the term `(no terminating newline)`.

## Finding conflicts

| Command | Shows |
| --- | --- |
| `jj status` | Conflicts in `@` |
| `jj log -r 'conflicts()'` | Conflicted commits (bound large searches: `trunk()..@ & conflicts()`) |
| `jj resolve --list [-r REV]` | Conflicted paths in a revision and the number of sides |
| `jj next --conflict`, `jj prev --conflict` | Move to the next or previous conflicted commit |
| Template | `Commit.conflict()`, `Commit.conflicted_files()`, `TreeEntry.conflict_side_count()` |

Log output marks conflicted commits with `×` and the label `(conflict)`.

## Resolving

### By editing files

1. `jj new <conflicted>`: a new commit on top inherits the conflict.
2. Edit the markers in the working copy. jj prints `Hint: Conflict in parent commit has been resolved in working copy` once resolved.
3. `jj diff` shows the resolution.
4. `jj squash` moves the resolution into the conflicted commit. Descendants whose conflicts came from it are resolved too.

`jj edit <conflicted>` and editing in place also work, but the resolution is harder to review and the markers are easy to damage.

Resolve the earliest conflicted commit first; conflicts in descendants are often inherited from it.

### With `jj resolve`

`jj resolve [-r REV] [FILESETS]` runs a 3-way merge tool on each conflicted file in turn. Only conflicts with two sides and a base are supported.

| Tool | Behavior |
| --- | --- |
| `--tool :ours` | Take side 1 |
| `--tool :theirs` | Take side 2 |
| `--tool mergiraf` | Syntax-aware automatic merge (if installed) |
| `--tool <name>` / `ui.merge-editor` | External tool via `merge-tools.<name>.merge-args` |

A tool's exit code decides the outcome: 0 with output means resolved; non-zero cancels; codes listed in `merge-conflict-exit-codes` mean the output still contains markers (a partial resolution). Git-style diff3 markers in the output are parsed too.

### Other ways

| Situation | Command |
| --- | --- |
| Take one side's whole file | `jj restore --from <side-commit> <path>` |
| Conflicts between a file, directory, and symlink | `jj restore` (no tool support) |
| A multi-way conflict | Apply each diff section to the snapshot |

## Conflicts and Git

Git cannot represent conflicts. A conflicted jj commit is stored in Git with `.jjconflict-base-*/` and `.jjconflict-side-*/` directories at the root of its tree; the real conflict data is in a `jj:trees` commit header. Git tools show those directories. If a Git command checks one of these commits out, the next jj snapshot records the first side plus the `.jjconflict-*` directories; `jj abandon` restores the conflicted state. See [git-interop.md](git-interop.md).
