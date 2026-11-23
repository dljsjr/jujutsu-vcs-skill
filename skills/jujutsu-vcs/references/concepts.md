# Concepts and data model

Definitions of the objects jj works with and the rules that govern them. For command flags, run `jj <command> --help`.

## Identifiers

| Identifier | Form | Stability | Notes |
| --- | --- | --- | --- |
| Change ID | 12 letters `k`–`z` in log output (16 random bytes, hex written with the digits `z`…`k`) | Stable across rewrites | Identifies a *change*: a commit as it evolves. `ChangeId.normal_hex()` gives 0–9a–f. |
| Commit ID | 12 hex digits in log output (20 bytes with the Git backend) | Changes on every rewrite | The Git commit ID when using the Git backend. |
| Change offset | `<change-id>/<n>` | Per evolution step | `xyz/0` is the most recent commit with change ID `xyz`, `xyz/1` the one before. Required for hidden and divergent commits. |
| Operation ID | 12 hex digits in `jj op log` | Permanent | Identifies one entry in the operation log. Any unambiguous prefix works. |

Change IDs and commit IDs use disjoint alphabets, so a prefix is never ambiguous between the two kinds. Both are case-insensitive.

A commit created by `git` (not by jj) has no recorded change ID. jj uses its bit-reversed commit ID as its change ID.

## Commits and changes

- A **commit** (synonym: **revision**) is a snapshot of the tree plus metadata: author, committer, author date, committer date, description, and parents.
- A commit's **changes** are the difference between its tree and the auto-merge of its parents' trees. A single-parent commit's changes are its diff from the parent. A clean merge commit has no changes and is shown as `(empty)`. `jj diff -r`, `jj log -p`, `empty()`, `files()`, and rebase all use this definition.
- A **change** is a commit as it evolves over time. Only the change ID exists in the data model; it is a property of commits.
- **Rewriting** a commit creates a new commit with a new commit ID and, usually, the same change ID. Describing, rebasing, squashing into, and editing working-copy files all rewrite. The author date normally survives; the committer date is updated.
- The **root commit** is a virtual commit with commit ID `00000000…` and change ID `zzzzzzzz…`. It is the ancestor of every commit and is always immutable. Git's "root commits" are `root()+` in jj.
- **Descendants are rebased automatically** when a commit is rewritten. Bookmarks on the rewritten commits move with them, and the working copy follows if it pointed at one of them.

## The working-copy commit

- Each workspace has one **working-copy commit**, written `@` (or `<workspace-name>@` from elsewhere).
- Almost every command **snapshots** the working copy first: changes to files since the last snapshot amend `@`. This changes `@`'s commit ID but not its change ID.
- At the end of a command, jj **updates** the working copy on disk to match `@`.
- New files are tracked automatically if they match `snapshot.auto-track` (default `all()`) and are not ignored. Deleted files are untracked automatically.
- New files larger than `snapshot.max-new-file-size` (default 1 MiB) are refused with a warning (`Refused to snapshot some files`); they stay untracked until the limit is raised or they are tracked with `jj file track --include-ignored`.
- There is no staging area. Partial commits are made by splitting or squashing commits.
- If the working-copy commit becomes immutable (for example after it is pushed), jj creates a new working-copy commit on top.
- If `@` is abandoned, jj creates a new empty working-copy commit in its place. This applies to every command that abandons commits.

## Visibility

- **Visible commits** are those reachable from the view's heads; `jj log -r 'all()'` shows them. Ancestors of visible commits are visible.
- A rewritten or abandoned commit becomes **hidden**. It is not deleted. It can still be addressed by commit ID or by change ID plus offset, and commands work on it.
- A hidden commit becomes visible again when something is placed on it: `jj new <hidden>`, `jj edit <hidden>`, a bookmark, or fetched descendants.
- **Anonymous branches** (heads with no bookmark) are kept until abandoned. No commit is lost for lack of a branch name.

## Divergence

- A change is **divergent** when it has more than one visible commit. The log labels each one `divergent` and shows its change offset.
- Causes include rewriting the same change from two workspaces, two processes rewriting it concurrently (for example an editor left open by `jj describe` while another command snapshots), making a hidden predecessor visible again, and fetching a commit whose `change-id` header matches a local change.
- A divergent change ID resolves to several commits, so commands that need one revision reject it. Use the commit ID or `<change>/<offset>`.
- Divergence is not an error. Ways to resolve it are listed in [Divergence resolution](#divergence-resolution).

### Divergence resolution

| Goal | Command |
| --- | --- |
| Let jj combine them | `jj converge` (`--no-interactive` to fail instead of prompting; experimental) |
| Keep one | `jj abandon <unwanted>` |
| Keep both as separate changes | `jj metaedit --update-change-id <commit>` |
| Combine the contents | `jj squash --from <a> --into <b>` |
| Leave it | Nothing; it stays addressable by commit ID or offset |

## Immutability

- The immutable set is `::(immutable_heads() | root())`, exposed as `immutable()`. `mutable()` is its complement.
- `immutable_heads()` defaults to `builtin_immutable_heads()` = `trunk() | tags() | untracked_remote_bookmarks() | untracked_remote_tags()`.
- To change what is immutable, redefine `revset-aliases."immutable_heads()"`. Redefining `immutable()` or `mutable()` does not change behavior.
- Commands refuse to rewrite immutable commits. The global flag `--ignore-immutable` disables the check for one command.

## Operations and views

- Every command that changes the repo records an **operation** in the **operation log**. An operation points to a **view** and to its parent operation(s), and records time, user, host, workspace, and a description.
- A **view** records the visible heads, every bookmark and tag, the Git refs, and each workspace's working-copy commit.
- The op log is a DAG. Concurrent commands produce several op heads, which the next command merges. See [operation-log.md](operation-log.md).

## Workspaces

- A **workspace** is a working copy plus a `.jj/` directory linked to one repo. All commits and operations are stored with the repo, in the initial workspace; other workspaces point to it. Git calls this a worktree.
- Each workspace has its own working-copy commit and its own sparse patterns.
- A workspace becomes **stale** when its working-copy commit is rewritten from elsewhere, or when a command was interrupted before updating the files. See [workspaces.md](workspaces.md).

## Conflicts

- Conflicts are recorded in commits instead of blocking the operation that created them. A rebase or merge with conflicts succeeds.
- The commit stores the conflict as a list of trees, not as markers. Conflicts can be rebased, merged, and reverted again without nesting.
- Markers appear only when a conflict is materialized: in the working copy and in diff output. See [conflicts.md](conflicts.md).
- Bookmarks can also be conflicted (`name??` in the log), and changes can be divergent. These are separate from file conflicts.

## Bookmarks and tags

- A **bookmark** is a named pointer to a commit, like a Git branch. Bookmarks follow rewrites of their commit and are deleted when it is abandoned. They do **not** move when a new commit is created on top: there is no current bookmark.
- A **tag** is a named pointer that does not follow rewrites. jj creates lightweight tags only.
- `name@remote` refers to the last-seen position of a remote bookmark or tag. See [bookmarks-and-remotes.md](bookmarks-and-remotes.md).

## Storage layout

| Path | Contents |
| --- | --- |
| `.jj/repo/` | The repository: commit store, op store, op heads, index, and in-repo config ID |
| `.jj/repo/store/type`, `.jj/repo/op_store/type`, `.jj/repo/op_heads/type`, `.jj/repo/index/type` | Backend selection |
| `.jj/repo/store/git` or `.jj/repo/store/git_target` | The backing Git repository, or the path to it (colocated: `../../../.git`) |
| `.jj/repo/store/extra/` | jj-only commit data (change IDs, predecessors) for the Git backend |
| `.jj/repo/op_heads/heads/` | One empty file per current op head, named by operation ID |
| `.jj/working_copy/` | Working-copy state, including the operation it was last updated to |

Repo and workspace config files are stored outside the repo. See [config.md](config.md#locations).
