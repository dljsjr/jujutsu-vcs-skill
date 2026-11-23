# Operation log

The operation log records each change to the repository state. It supports undo, restores, and recovery from concurrent changes.

## Operations

- Every command that changes the repo creates an **operation**. Commands that only read still snapshot the working copy first, which creates a `snapshot working copy` operation when files changed.
- An operation records a **view** (visible heads, bookmarks, tags, Git refs, each workspace's `@`), its parent operation(s), and metadata: time, user (`operation.username`), host (`operation.hostname`), workspace, the command line, and a description.
- `@` in operation arguments is the current operation; `x-` and `x+` are parents and children. Any unambiguous prefix of an operation ID works.

## Commands

| Command | Effect |
| --- | --- |
| `jj op log` | List operations (`-n`, `--reversed`, `-G`, `-T`, `-d/--op-diff`, `-p`) |
| `jj op show [OP]` | Changes made by an operation (default `@`) |
| `jj op diff --from OP --to OP` | Changes between two operations (`--op OP` compares with its parent) |
| `jj undo` | Undo the most recent operation; repeat to go further back |
| `jj redo` | Redo the most recently undone operation |
| `jj op revert [OP]` | Create an operation applying the inverse of one operation (default `@`) |
| `jj op restore OP` | Create an operation that returns the repo to the state after `OP` |
| `jj op abandon OPS` | Discard operation history (`..OP` = that operation and its ancestors) |
| `jj op integrate OP` | Add an operation created with `--no-integrate-operation` (or left unintegrated by an error) |
| `jj --at-op OP <command>` | Run a command against the state at `OP` |

- `jj op show`, `jj op diff`, and `jj op log -p` list only "interesting" revisions, defined by `revsets.op-diff-changes-in` (default `mutable() | immutable_heads()`). `--show-changes-in REVSETS` overrides it.
- `jj op log` snapshots the working copy and merges divergent operations, like other commands. `jj --at-op=@ --ignore-working-copy op log` reads without changing anything.
- `jj op restore` and `jj op revert` accept `--what repo|remote-tracking` (repeatable, experimental; default both). Leave out `remote-tracking` to keep the remote-tracking bookmarks as they are, for example before pushing again.

## Undo across workspaces

`jj undo` and `jj redo` refuse to act on an operation performed in another workspace:

```text
Error: Refusing to undo operation 3938b68b2f34 because it was performed in workspace ws3
Hint: Use `--allow-cross-workspace` to undo it anyway, or use `jj op revert` to revert a specific operation
```

`jj op log` shows each operation's workspace. To undo your own earlier operation while another workspace has made later ones, use `jj op revert <op>`.

## Loading earlier states

- `--at-op OP` skips snapshotting. `@` resolves to the working-copy commit recorded in that operation's view.
- Read-only commands (`log`, `status`, `diff`, `show`) at an old operation inspect history safely.
- A mutating command at an old operation forks the op log, exactly as if it had run concurrently starting from that operation.
- The revset function `at_operation(op, x)` evaluates a revset at an operation inside another command.

## Unintegrated operations

`--no-integrate-operation` runs a command normally but does not add its operations to the op log and does not update the working copy. It prints the operation ID. The result can be inspected with `--at-op`, adopted with `jj op integrate OP`, or applied with `jj op restore OP`. Effects outside the repo, such as pushes, still happen.

## Garbage collection

- Abandoned and rewritten commits stay in storage while any operation references them. `jj op abandon ..OP` drops old history; predecessors that become unreachable are dropped with it.
- `jj util gc` then deletes unreferenced objects and operations older than two weeks (`--expire now` for all). After that they cannot be recovered.
- The Git backend keeps commits referenced by the op log alive with `refs/jj/keep/*`.

## Concurrency

- jj uses no lock files for the repo. A command loads the latest operation, works on that frozen view, and writes its operation with that operation as parent. Writing cannot fail except on storage errors.
- Concurrent commands, including commands from different machines on a shared filesystem, produce several op heads. The next command performs a 3-way merge of their views:
  - A bookmark moved differently by each becomes conflicted (`name??`).
  - A change rewritten by each becomes divergent.
  - Work continues; only commands that need the conflicted bookmark or divergent change ID fail ("resolved to multiple revisions").
- Op heads are stored as empty files named by operation ID in `.jj/repo/op_heads/heads/`. A new head file is written before the old one is removed, so updates are atomic.
- Known limitation: the Git backend is not entirely lock-free, and concurrent use from several machines can corrupt the index (jj issue #2193). `jj debug reindex` repairs it. Sharing a colocated repo through NFS or a sync service is not thoroughly tested; bookmark positions may be lost, commits are not.
