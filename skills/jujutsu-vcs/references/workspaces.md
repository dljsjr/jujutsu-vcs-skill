# Workspaces

A jj workspace is a working copy. Several workspaces can share one repo.

## Model

- A workspace is a working copy plus a `.jj/` directory linked to the repo. Commits and operations are stored in the initial workspace's `.jj/repo/`; other workspaces point to it. Git calls this a worktree.
- Each workspace has its own working-copy commit (`<name>@` in revsets and `jj log`) and its own sparse patterns.
- The initial workspace is named `default`.
- The revset `working_copies()` returns every workspace's working-copy commit. The template method `Commit.working_copies()` lists the workspaces whose `@` is a given commit.

## Commands

| Command | Effect |
| --- | --- |
| `jj workspace add DEST` | Create a workspace at `DEST`. `--name` (default: the basename of `DEST`), `-r REVSETS` (parents of its working-copy commit; default: the current `@`'s parents), `-m`, `--colocate`/`--no-colocate`, `--sparse-patterns copy\|full\|empty` (default `copy`). |
| `jj workspace list` | Names, working-copy commits, and roots. `-T` with `WorkspaceRef` keywords (`name`, `target`, `root`). |
| `jj workspace root [--name N]` | A workspace's root path (default: the current workspace). `jj root` is a shortcut. |
| `jj workspace rename NEW` | Rename the current workspace |
| `jj workspace forget [NAMES]` | Stop tracking workspaces (default: the current one). Files are left on disk. |
| `jj workspace remove NAMES` | Snapshot each workspace, then forget it and delete its directory |
| `jj workspace update-stale` | Update a stale working copy |

## Colocated workspaces

- When the current workspace is colocated and `git.colocate` is `true` (the default), `jj workspace add` also creates a Git worktree, so Git commands work in the new workspace. `--colocate` and `--no-colocate` override this. This requires git ≥ 2.42 (`git worktree add --orphan`).
- Git HEAD is tracked per worktree: each colocated workspace has its own detached Git HEAD at the parent of its `@`.
- `jj git colocation status`, `enable`, and `disable` work in child workspaces: `enable` creates a Git worktree, `disable` removes it.

## Forget and remove

| | `jj workspace forget` | `jj workspace remove` |
| --- | --- | --- |
| Working-copy commit | No longer tracked (it stays in the repo as an ordinary commit) | Snapshotted first, then no longer tracked |
| Workspace directory | Left on disk | Deleted, **including ignored and untracked files** |
| Git worktree (colocated) | Removed: the workspace's `.git` file and the main repo's `.git/worktrees/<name>` | Removed |
| Main workspace | Can be forgotten | Cannot be removed |
| Undo | `jj undo` restores the workspace record, including its path | The directory is not restored |

Removing the current workspace works on Unix. On Windows, run it from another directory with `jj -R`.

## Stale working copies

Each working copy records the operation it was last updated to (in `.jj/working_copy/`). A working copy is **stale** when its workspace's working-copy commit in the current view differs from what is on disk:

- another workspace rewrote this workspace's `@` with different content (for example by squashing into `<name>@` or rebasing a branch that contains it). In testing on 0.46, a metadata-only rewrite such as `jj describe -r <name>@` did not make the working copy stale.
- a command was interrupted after recording its operation but before updating the files
- the operation the working copy was updated to was lost (for example to `jj op abandon`)
- another jj process snapshotted the working copy while a command was running, for example one started by `fsmonitor.watchman.register-snapshot-trigger`. Observed on 0.46 with a single workspace: update-stale then reported `Concurrent modification detected` and made `@` divergent, and `jj converge` recombined it (*verified*).

Commands in a stale workspace stop with `Error: The working copy is stale (not updated since operation …)` and suggest `jj workspace update-stale`. That command updates the files on disk. If the recorded operation was lost, it creates a recovery commit containing the working-copy contents, parented on the current `@`. With `snapshot.auto-update-stale = true`, stale working copies are updated automatically.

## Undo and workspaces

`jj undo` and `jj redo` refuse to act on operations made in another workspace unless given `--allow-cross-workspace`. `jj op revert <op>` reverts a specific operation from any workspace. See [operation-log.md](operation-log.md#undo-across-workspaces).

## Sparse patterns

Each workspace materializes only the paths matching its sparse patterns (default `.`, everything).

| Command | Effect |
| --- | --- |
| `jj sparse list` | Current patterns |
| `jj sparse set --add P --remove P [--clear]` | Change patterns (path prefixes) |
| `jj sparse reset` | Back to everything |
| `jj sparse edit` | Edit patterns in the editor |

Ignore files are respected even when not materialized.

## Config

Each workspace can have its own config file, stored outside the workspace (`jj config path --workspace`). `--when.workspaces` in any config file matches workspace path prefixes; `--when.repositories` matches the main workspace's path.
