---
name: jujutsu-vcs
description: Operates Jujutsu (jj) version control as a coding agent, including inspecting state, committing, splitting and squashing changes, rebasing, resolving conflicts, undoing through the operation log, managing bookmarks, and pushing to Git remotes. Use for any version-control step in a directory that contains `.jj/` or where `jj root` succeeds, including colocated repos that also contain `.git/`; there, jj replaces git entirely, read-only checks included. Also use when the user mentions jj or Jujutsu, or when writing jj revsets, filesets, templates, or configuration. Not for plain Git repositories that have no `.jj/` directory.
---

# Jujutsu (jj)

jj is not git with different spellings. It can store history in Git's format, but its model is different, and commands chosen from git habits go wrong here.

These workflows assume `jj` 0.46.0 or later. Run `jj --version` once. Check unfamiliar flags with `jj <command> --help` on the installed version.

A directory is a jj repo when `.jj/` exists or `jj root` succeeds.

## jj is not git

| Git habit | In jj |
| --- | --- |
| Work is uncommitted until you commit it. | Edits are already in `@`, the working-copy commit: every jj command records them first. Nothing is uncommitted, and there is no staging area. |
| A rebase or merge can stop on a conflict. | Nothing stops. Conflicts are recorded in commits, and work continues. See [Conflicts](#conflicts). |
| Rewriting history is dangerous. | Local rewrites are routine and undoable ([Rule 1](#rule-1-change-things-freely-and-undo-instead-of-asking)). Only `jj git push` leaves your machine. |
| Re-pushing rewritten commits is a risky force push. | Every `jj git push` first checks that the remote bookmark is where jj last saw it, like `--force-with-lease`, so updating a rewritten bookmark is routine. jj also refuses to rewrite immutable commits (trunk, tags, untracked remote bookmarks) without `--ignore-immutable`, and never pushes commits matched by `git.private-commits`. |
| The current branch moves with each commit. | There is no current branch. Bookmarks stay where they are until you move them. |
| Work without a branch name can get lost. | Every visible commit stays until you abandon it, named or not. Bookmarks exist for pushing and sharing, not for keeping work alive. |
| A commit records work after it is done. | A change can be described before it has any edits. Empty, described changes work as plans or to-do items, and they rebase anywhere without conflicts. |
| To change an older commit, check it out or run an interactive rebase. | Commands act on any commit in place: `jj describe REV`, `jj squash -r REV`, `jj split -r REV PATHS`, `jj abandon REV`. Descendants follow automatically. |
| HEAD, detached HEAD. | `@` is the working-copy commit and `@-` its parent. Git sees a detached HEAD at `@-`; that is normal. |

Use jj's words, because git's words lead to git's commands:

- **Commit**, or **revision**: one snapshot with its metadata, named by a commit ID (12 hex digits). The two words mean the same thing. Rewriting a commit creates a new commit.
- **Change**: a commit as it evolves. Every rewrite (describe, squash, rebase, editing files in `@`) produces a new commit with the same change ID (12 letters `k`–`z`), and descendants are rebased onto it automatically. Refer to work by change ID; use a commit ID only to name one specific version, such as a hidden or divergent commit. That stable identity is what a Git commit lacks, and it is why a change can be described before it has edits, carry a conflict while work continues, and be rewritten or moved anywhere with its descendants following.
- **Bookmark**: a named pointer to a commit, which Git calls a branch. In jj, "branch" means only a line of commits in the graph, named or not.
- **Edits**: the file differences a commit holds, shown by `jj diff`.

When a git word comes to mind (stash, checkout, amend, HEAD, staged, branch, pull), translate it with the table in [Rule 2](#rule-2-use-jj-never-git) before running anything.

A few more facts that git does not prepare you for:

- **New files are tracked automatically.** Any stray file in the working copy lands in `@` on the next command. Delete stray files you created. Keep files you found out of your commits by committing only the paths you mean (`jj commit PATHS`); the rest stays in `@`. `jj file untrack` works only on ignored files. New files over 1 MiB are refused with `Warning: Refused to snapshot some files` and stay untracked.
- **After `jj commit`, your commit is `@-`.** `jj commit -m MSG` describes `@` and starts a new empty `@` on top.
- **No Git hooks run.** Pre-commit and commit-msg hooks are skipped.

## Rule 1: Change things freely, and undo instead of asking

In jj, local history is cheap to reverse. Every command records an operation, `jj undo` reverses the latest one, and `jj op restore` returns the whole repo to any earlier state. Abandoned and rewritten commits are hidden, not deleted, and file edits are saved in `@` by the snapshot each command takes first.

So when the task calls for committing, describing, squashing, splitting, rebasing, abandoning, restoring, resolving, or moving bookmarks, run the command. Do not:

- ask the user for permission to rewrite local history;
- copy the repository or a directory to try something out;
- create backup bookmarks or duplicate commits before a rebase;
- save patches or stash work before moving `@`.

To experiment, use jj itself:

| Experiment | Do | Discard it |
| --- | --- | --- |
| Try a code change | `jj new -m "experiment"`, then edit and test | `jj abandon @` (files return to the parent's state) |
| Try a history rewrite | Note the ID from `jj op log -n 1`, then run the commands | `jj op restore ID` (or `jj undo` for a single command) |
| Run a tool that rewrites many files | `jj new` first, so its edits land in their own commit | `jj abandon @` |

What jj cannot take back:

- **`jj git push`.** It changes a remote that other people see. Push only when the user asks.
- **`jj workspace remove`.** It deletes the directory, including untracked and ignored files.
- **`jj op abandon` and `jj util gc`.** They discard the history that undo relies on.
- **Non-jj commands that overwrite or delete files.** jj can restore only what it has snapshotted. Run `jj status` first to snapshot current edits.

## Rule 2: Use jj, never git

Run no git commands in a jj repo, even when `.git/` exists, and even read-only ones such as `git status`, `git log`, and `git diff`. Repository state comes only from `jj status`, `jj log`, and `jj diff`, including inside longer shell commands.

- Git sees a detached HEAD at `@-`, so it reports your work in `@` as uncommitted and misreads the state.
- Mutating git commands, interleaved with jj, produce conflicted bookmarks and divergent changes.
- A git command that overwrites files, such as `git checkout -- FILE` or `git reset --hard`, destroys edits jj has not snapshotted yet. It is one of the few ways to lose work in a jj repo, and a very easy one.

| Instead of | Run |
| --- | --- |
| `git status`, `git status --short` | `jj status`, `jj diff --summary` |
| `git diff`, `git diff --staged`, `git show R` | `jj diff`, `jj show R` |
| `git log` | `jj log` (`-r ::@` for all ancestors) |
| `git add` + `git commit -m` | `jj commit -m` (there is nothing to add) |
| `git commit --amend` | `jj squash` (edits) or `jj describe @- -m` (message) |
| `git stash` | `jj new @-` (the old change stays as a sibling; return with `jj edit`) |
| `git checkout B`, `git switch B` | `jj new B` |
| `git branch`, `git checkout -b N` | `jj bookmark list`, `jj bookmark create N` |
| `git reset --hard`, `git checkout -- FILE` | `jj restore [PATHS]` or `jj abandon` |
| `git pull` | `jj git fetch`, then `jj rebase -o 'trunk()'` |
| `git push` | `jj git push` (only when asked) |
| `git rev-parse HEAD` | `jj log -G -r @- -T commit_id` |
| `git show REV:PATH` | `jj file show -r REV PATH` |
| `git blame`, `git grep`, `git ls-files` | `jj file annotate`, `jj file search --pattern`, `jj file list` |
| `git config` | `jj config list`, `jj config get KEY` |
| `git reflog` | `jj op log` (repo) or `jj evolog -r REV` (one change) |

For anything else, see the equivalents table in [git-interop.md](references/git-interop.md#equivalent-commands). Tools that run git internally, such as `gh`, are fine.

## Rule 3: Ask jj precise questions instead of parsing its output

jj answers most questions about the repo directly. Choose the commits with a revset (`-r`), the fields with a template (`-T`), and the paths with a fileset. Do not pipe jj output through `head`, `tail`, `grep`, `awk`, `sed`, `cut`, or `wc`: default output is written for people, with graph lines, wrapping, and formats that change, and a pipe can silently drop or misread what it filters.

| Instead of piping | Ask jj |
| --- | --- |
| `jj log`, then `head -n 20` | `jj log -n 20`, or the exact range: `jj log -r 'trunk()..@'` |
| `jj log`, then `grep fix` | `jj log -r 'subject(substring:fix)'` (`description(...)` searches the whole message) |
| `jj log`, then `wc -l` | `jj log --count -r REVSET` |
| `jj log -r X`, then `head -1` to get an ID | `jj log -G -r 'exactly(X, 1)' -T commit_id` (or `change_id`) |
| `jj log`, then `awk` for a column | `jj log -G -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'` |
| `jj status` or `jj log`, then `grep conflict` or `grep empty` | `jj log -r 'trunk()..@ & conflicts()'`, `jj log -r 'trunk()..@ & empty()'`, `jj resolve --list` |
| `jj diff`, then `grep TEXT` | `jj log -r 'trunk()..@ & diff_lines(regex:TEXT)'` finds the commits; `jj file search --pattern TEXT -r REV` searches a commit's files |
| `jj file list` or `jj diff --name-only`, then `grep` | `jj file list 'glob:"**/*.py"'`, `jj diff --name-only src` |
| `jj show REV`, then `tail` | `jj diff -r REV --git PATHS` |
| `jj bookmark list`, then `grep` | `jj bookmark list 'feat-*'` |

Templates to copy. Add `-G` to drop the graph, and end each record with `"\n"`:

```sh
jj log -G -r REVS -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'                      # one line per commit
jj log -G -r REVS -T 'change_id.short() ++ " " ++ diff.files().map(|f| f.path()).join(",") ++ "\n"'      # files each commit changes
jj log -G -r REVS -T 'json({"change" => change_id.short(), "subject" => description.first_line(), "empty" => empty, "conflict" => conflict}) ++ "\n"'   # JSON Lines
```

`json(self)` serializes every field of a commit.

Revsets worth knowing: `trunk()..@` (the current stack), `remote_bookmarks()..@` (not yet pushed), `files(PATH)`, `mine()`, `conflicts()`, `empty()`, `heads(X)`, `roots(X)`. Full syntax: [revsets.md](references/revsets.md), [templates.md](references/templates.md), [filesets.md](references/filesets.md).

Built-in aliases expand to the definitions below: the output of `jj config list --include-defaults revset-aliases` in a fresh repo with no user config. Run the same command to see the current repo's definitions, including the user's overrides; `jj git clone` usually also sets a repo-level `trunk()`.

```console
$ jj config list --include-defaults revset-aliases
revset-aliases."trunk()" = '''
latest(
  remote_bookmarks(exact:"main", exact:"origin") |
  remote_bookmarks(exact:"master", exact:"origin") |
  remote_bookmarks(exact:"trunk", exact:"origin") |
  remote_bookmarks(exact:"main", exact:"upstream") |
  remote_bookmarks(exact:"master", exact:"upstream") |
  remote_bookmarks(exact:"trunk", exact:"upstream") |
  root()
)
'''
revset-aliases."builtin_log()" = 'present(@) | ancestors(immutable_heads().., 2) | trunk()'
revset-aliases."builtin_immutable_heads()" = '''
trunk() | tags() | untracked_remote_bookmarks() | untracked_remote_tags()
'''
revset-aliases."immutable_heads()" = 'builtin_immutable_heads()'
revset-aliases."immutable()" = '::(immutable_heads() | root())'
revset-aliases."mutable()" = '~immutable()'
revset-aliases."visible()" = '::visible_heads()'
revset-aliases."hidden()" = '~visible()'
```

Traps:

- A bare string pattern is a glob over the whole string: `description(fix)` matches only a description that is exactly `fix`. Use `description(substring:fix)`.
- Descriptions end with a newline, so `description(exact:"Add parser")` never matches. Use `subject("Add parser")`.
- A name resolves as a tag, then a bookmark, then an ID. In scripts, wrap IDs: `change_id(x)`, `commit_id(x)`.
- Content filters such as `conflicts()`, `files()`, and `description()` scan every commit. Bound them with a range: `trunk()..@ & files(src)`.
- Revset and template operators such as `|`, `&`, `~`, and `()` are also shell metacharacters, so single-quote the whole expression. Add `--ignore-working-copy` to read without snapshotting, for example from a background process.

## Before the first jj command

1. jj opens an editor whenever a command needs a message it was not given: `describe` or `commit` without `-m`, `split` without `-m`, and `squash` when both commits have descriptions. An editor waits for a person, so begin every shell command that runs jj with this line, comment included:

   ```sh
   export JJ_EDITOR=false  # jj repo: no git; ask jj with -r/-T, not grep
   ```

   An accidental editor then fails fast with `Error: Failed to edit description`; rerun with a [non-interactive form](#non-interactive-forms). Repeat the line in each command; the comment keeps Rules 2 and 3 in view.
2. Read the state with `jj status` and `jj log`.

## A typical task

```sh
export JJ_EDITOR=false  # jj repo: no git; ask jj with -r/-T, not grep
jj status && jj log -r 'trunk()..@'    # what @ holds, and the work since trunk
# ...edit files; the edits land in @ by themselves...
jj diff --git                           # review @
jj commit -m "Add retry to fetch()"     # describe @ and start a new empty @
jj log -r 'trunk()..@' --summary        # each commit holds what you meant
```


## Non-interactive forms

| Task | Command |
| --- | --- |
| Commit everything in `@` | `jj commit -m "msg"` |
| Commit only some paths; the rest stays in the new `@` | `jj commit PATHS -m "msg"` |
| Reword any commit | `jj describe REV -m "msg"` |
| Start a change on another commit | `jj new REV -m "msg"` |
| Split `@`; PATHS go into the first commit | `jj split PATHS -m "msg for the PATHS part"` |
| Squash `@` into its parent | `jj squash`; add `-u` (keep the destination's message) or `-m "msg"` when both commits have descriptions |
| Move edits into a specific commit | `jj squash --into REV [PATHS]` (`--from REV` for a source other than `@`) |
| Take one side of a conflicted file | `jj resolve --tool :ours PATH` or `--tool :theirs` |

Without a terminal, these fail with `failed to set up terminal`; with one, they block: `jj split` without PATHS, any `-i` flag, `jj diffedit`, `jj resolve` without `--tool`, and `jj arrange`. To choose hunks rather than whole files, script a diff editor as described in [automation.md](references/automation.md#scripted-diff-editor).

## Common tasks

### Inspect

| Need | Command |
| --- | --- |
| Changes in `@` or REV as a patch or a path list | `jj diff [-r REV]` with `--git`, `--name-only`, or `--summary` |
| Your stack since trunk | `jj log -r 'trunk()..@'` |
| Unpushed work | `jj log -r 'remote_bookmarks()..@'` |

### Start and update work

- New work on trunk: `jj git fetch`, then `jj new 'trunk()' -m "msg"`.
- After updating with `jj git fetch && jj rebase -o 'trunk()'`, check `jj log` for conflicts.

### Rewrite history

| Goal | Command |
| --- | --- |
| Fold fixes from `@` into the commits that last touched those lines | `jj absorb` |
| Change an older commit | `jj new REV`, edit, then `jj squash` |
| Move your line of work onto another base | `jj rebase -b @ -o DEST` (`-s REV` moves REV and its descendants) |
| Reorder: put C before B | `jj rebase -r C -B B` |
| Drop a commit | `jj abandon REV` |
| Copy a commit elsewhere (cherry-pick) | `jj duplicate REV -o DEST` |
| Revert a commit | `jj revert -r REV -B @` |

`jj edit REV` also works for changing an older commit, but every later edit keeps landing in REV until you move `@` away. Prefer `jj new REV` plus `jj squash`. To split or rearrange several commits, follow [reshape-history.md](workflows/reshape-history.md).

If jj reports that a commit is immutable, it is usually already shared: trunk, a tag, or an untracked remote bookmark. Rewriting it leads to force-pushing shared history, so do not add `--ignore-immutable` unless the user asks.

### Bookmarks and pushing

1. Pick the commit. After `jj commit`, `@` is empty, so push `@-`. jj refuses to push commits without descriptions.
2. Point a bookmark at it:
   - existing bookmark: `jj bookmark move NAME --to @-` (`--allow-backwards` for a backward or sideways move);
   - new bookmark: `jj bookmark create NAME -r @-`.
3. Preview, then push: `jj git push -b NAME --dry-run`, then without `--dry-run`. New bookmarks are tracked automatically.

`jj git push -c @-` creates and pushes a generated `push-<change-id>` bookmark in one step. After rewriting a pushed stack, `jj git push -r 'trunk()..@'` force-pushes every bookmark on it.

If a push is refused:

| Cause | Action |
| --- | --- |
| `unexpectedly moved on the remote (reason: stale info)` | `jj git fetch`. If the bookmark becomes conflicted (`NAME??`), resolve it as in [Recover](#recover), then push again |
| `has no description` | Describe the commit |
| Private commits | The user's `git.private-commits` excludes them. Ask before adding `--allow-private` |
| Conflicted commits | Resolve the conflicts first |

### Conflicts

In jj a conflict is part of a commit, not a stuck operation. The command that produced it finishes normally, records the conflict in the resulting commit, and rebases descendants on top, which inherit it. `jj log` marks those commits `(conflict)`. There is no rebase in progress, no `--continue` or `--abort`, and every command keeps working. The conflict is ordinary history: it can be rebased, squashed, or undone like any other content.

So a conflict is not a reason to stop the task:

- Keep working on anything that does not need the conflicted files: other files, other commits, other lines of work. The conflict waits in its commit.
- Resolve it once something needs that content: before building or testing those files, and before pushing, since jj refuses to push conflicted commits.
- Undo only if the rewrite itself was the mistake. A conflict alone is not a reason to `jj undo`.

To resolve:

1. Find the earliest conflicted commits: `jj log -r 'roots(trunk()..@ & conflicts())'`. Resolve those first; their descendants usually inherit the same conflicts, including an empty `@`.
2. Note `@`'s change ID. Run `jj new REV` on the conflicted commit, without `-m` so the later squash has only one description, then `jj resolve --list` to see the paths.
3. Edit the markers in each file. In the default style, apply each `%%%%%%%` diff to the `+++++++` snapshot, then delete every marker line. See [conflicts.md](references/conflicts.md) for the other styles and longer markers.
4. Review with `jj diff`, then `jj squash` to move the resolution into REV.
5. Confirm with `jj log` that `(conflict)` is gone from REV and its descendants.
6. Put `@` back. If the change you noted held edits, `jj edit` it. If it was empty, jj discarded it when `@` moved, so run `jj new` on the top of the stack.

### Recover

| Situation | Action |
| --- | --- |
| Last command was a mistake | Check `jj op log -n 5` first: the latest operation may be a working-copy snapshot, not the command you meant. Then `jj undo` (repeat to go further back); `jj redo` reverses it |
| See how the repo looked earlier, without changing anything | `jj op log`, then `jj --at-op OP log` (or `diff`, `show`, `status`) |
| Need an older repo state | `jj op log`, then `jj op restore OP` |
| Undo refused: operation from another workspace | `jj op revert OP` |
| A change's edits went missing | `jj evolog -r CHANGE` shows its earlier commits; `jj new COMMIT_ID` revives a hidden one |
| `divergent` in the log | Address each copy by commit ID; resolve with [concepts.md](references/concepts.md#divergence-resolution) |
| `The working copy is stale` | `jj workspace update-stale` |
| `NAME??` (bookmark moved both locally and on the remote) | Rebase your side onto the remote's: `jj rebase -s YOURS -o NAME@origin`. If `NAME??` remains, `jj bookmark move NAME --to YOURS` |
| `resolved to multiple revisions` | The name is conflicted or divergent; use a commit ID |

## Before you finish

Run this check after your last command that changes files.

- Each commit you made holds only the edits you meant: `jj log -r 'trunk()..@' --summary`. Auto-tracking adds every new file, including ones your own commands created.
- `@` is where the user's work continues: on the change that held their in-progress edits, or on a new empty change on top of yours.
- Conflicts still recorded in your commits: `jj log -r 'trunk()..@ & conflicts()'`.

## Several agents in one repo

- **Give concurrent work its own workspace:** `jj workspace add PATH --name NAME -r REV` (a harness that isolates subagents may already do this), and later `jj workspace forget NAME` (keeps the directory) or `jj workspace remove NAME` (deletes it, including untracked and ignored files). Another workspace's working copy is `NAME@`.
- **Do not rewrite commits a running workspace is building on.** Rebasing or squashing its base or its commits while it works makes its working copy stale or its change divergent. Wait until it reports done; if it happens anyway, see [Recover](#recover).
- **Combine results by change ID.** Every workspace's commits are already in the shared repo. Stack them with `jj rebase`, or put them side by side under a [megamerge](workflows/megamerge.md).

## Workflows

Read the workflow that matches the task before starting it:

| Situation | Read |
| --- | --- |
| A task bigger than one reviewable commit: plan a stack of changes, revise lower ones, push one bookmark per change, land them in order | [stacked-changes.md](workflows/stacked-changes.md) |
| Existing work in the wrong shape: split a large change, move edits between commits, reorder, or make changes independent for separate pull requests | [reshape-history.md](workflows/reshape-history.md) |
| Iterative work where only what proves right should be kept: describe the goal, work in a scratch change on top, squash in what works | [squash-workflow.md](workflows/squash-workflow.md) |
| Several lines of work in progress that need to be built, tested, or worked on together | [megamerge.md](workflows/megamerge.md) |

## References

Read a reference when the task goes beyond the procedures above.

| Need | Read |
| --- | --- |
| Identifiers, visibility, immutability, divergence | [concepts.md](references/concepts.md) |
| Command map, shared flags (`-r`/`-s`/`-b`, `-o`/`-A`/`-B`), Git-to-jj equivalents | [cli.md](references/cli.md), [git-interop.md](references/git-interop.md) |
| Scripted editors, diff editors, merge tools; isolation; environment variables | [automation.md](references/automation.md) |
| Revset, fileset, or template syntax | [revsets.md](references/revsets.md), [filesets.md](references/filesets.md), [templates.md](references/templates.md) |
| Tracking, fetch, push, forges, several remotes | [bookmarks-and-remotes.md](references/bookmarks-and-remotes.md) |
| Conflict marker styles and tools | [conflicts.md](references/conflicts.md) |
| Operation log, concurrency | [operation-log.md](references/operation-log.md) |
| Workspaces, stale working copies, sparse checkouts | [workspaces.md](references/workspaces.md) |
| Config keys, locations, conditional settings | [config.md](references/config.md) |

When a command behaves unexpectedly, user config may have changed a default (immutable heads, private commits, editor, pager). Check with `jj config list KEY`.
