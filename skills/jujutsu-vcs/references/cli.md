# CLI reference

Common command conventions, global options, and a command map. For the complete help on your installed version:

- `jj <command> --help` (long help) or `-h` (summary)
- `jj util markdown-help` (the whole CLI in Markdown)
- `jj help -k <keyword>` for `bookmarks`, `config`, `filesets`, `glossary`, `revsets`, `templates`, `tutorial`

## Conventions

### Revision arguments

| Flag | Meaning |
| --- | --- |
| `-r`, `--revision` / `--revisions` | Exactly the revisions in the revset. On content commands (`diff`, `restore -c`), "compared with the parent". |
| `-s`, `--source` | The revisions and all their descendants (`-s X` ≈ `-r X::`). |
| `-b`, `--branch` | The whole branch relative to the destination: `(dst..X)::`. |
| `-f`, `--from` | The source of contents, or the bookmarks on a revision. |
| `-t`, `--to`, `--into` | The destination of contents or bookmarks, or the "after" side of a comparison. Every command that accepts `--into` also accepts `--to`. |

Positional revsets (with `-r` as an alias for the positional) are accepted by `abandon`, `arrange`, `describe`, `duplicate`, `edit`, `metaedit`, `new`, `parallelize`, and `show`.

### Destinations

| Flag | Places the revisions... |
| --- | --- |
| `-o`, `--onto` (aliases `-d`, `--destination`) | as children of the targets. Repeat it to create a merge. |
| `-A`, `--insert-after` (alias `--after`) | between the targets and their children; the children are rebased onto the moved revisions. |
| `-B`, `--insert-before` (alias `--before`) | between the targets and their parents; the targets and descendants are rebased onto the moved revisions. |

`-A` and `-B` can be combined to insert between two specific commits, including inside an existing merge. These flags are shared by `rebase`, `duplicate`, `revert`, `split`, `new` (`-A`/`-B` only; parents are positional), and `squash` (experimental there).

### Patterns

- Name arguments for bookmarks, tags, and remotes are **glob** patterns by default and accept other string pattern kinds (`exact:`, `regex:`, `substring:`, `-i` suffix). See [revsets.md](revsets.md#string-patterns).
- `jj git fetch -b/-t` and `jj git clone -b/-t` use a restricted dialect: only `*` is expanded, and only union (`|`) and negative intersection (`~`) are allowed.
- Path arguments are filesets. A bare path is a cwd-relative `prefix-glob:`. See [filesets.md](filesets.md).

### Repeated flags

Single-valued flags may be given more than once; the last value wins. Repeatable flags (`--config`, `-r` on most commands) collect every value.

## Global options

| Option | Effect |
| --- | --- |
| `-R`, `--repository <PATH>` | Operate on this repo. Default: the nearest ancestor `.jj/`. |
| `--ignore-working-copy` | Do not snapshot at the start or update the working copy at the end. Reads possibly stale state. |
| `--at-operation <OP>` (`--at-op`) | Load the repo at an operation. Implies `--ignore-working-copy`. `--at-op=@` is the latest operation without merging divergent op heads. Mutating commands are allowed and behave as if run concurrently from that operation. |
| `--no-integrate-operation` | Create operations but do not add them to the op log or update the working copy. Prints the new operation ID for use with `--at-op`, `jj op restore`, or `jj op integrate`. External effects (pushes) still happen. |
| `--ignore-immutable` | Allow rewriting immutable commits (not the root). Affects only the check. |
| `--quiet` | Suppress secondary output (snapshot notices, rebase counts). Warnings and errors still print. |
| `--no-pager` | Disable the pager. |
| `--color <always\|never\|debug\|auto>` | `debug` shows template labels. |
| `--config <NAME=VALUE>` | Override a config key (TOML value; repeatable; no spaces around `=`). |
| `--config-file <PATH>` | Load an extra config file (repeatable). |
| `--debug` | Debug logging. |

## Commands by task

Default aliases: `b` (bookmark), `ci` (commit), `desc` (describe), `st` (status), `op` (operation). Bookmark subcommands: `a`, `c`, `d`, `f`, `l`, `m`, `r`, `s`, `t`. Tag subcommands: `d`, `l`, `s`.

### Inspecting

| Command | Notes |
| --- | --- |
| `jj status [FILESETS]` | `@`, its parents, a summary of `@`'s changes, conflicts in `@`, conflicted bookmarks. |
| `jj log [-r REVSETS] [FILESETS]` | Default revset `revsets.log` = `builtin_log()`. `-n` limit, `--reversed`, `-G/--no-graph`, `-T`, `-p`, `--count`. `jj log -T` with no value lists built-in templates. |
| `jj show [REVSETS]` | Metadata plus diff for each revision. `--no-patch`, `-T`, `--reversed`. |
| `jj diff [-r REVSETS \| --from R --to R] [FILESETS]` | Default `-r @`. A multi-revision `-r` shows the combined diff (no gaps allowed). |
| `jj interdiff --from R --to R` | Compares the two revisions' patches, ignoring differences in their parents. |
| `jj evolog [-r REVSETS]` | Previous versions of a change. `-p` diffs each version against its predecessor. |
| `jj file show/list/annotate/search` | Contents, file lists, blame, and line search (`--pattern`, regex by default; `--name-only`, `-n`) for any revision. |
| `jj op log/show/diff` | The operation log. See [operation-log.md](operation-log.md). |
| `jj root`, `jj workspace root [--name N]`, `jj git root` | Paths. |

Diff formatting options shared by `diff`, `show`, `log -p`, `evolog -p`, `interdiff`, and `op` commands: `-s/--summary`, `--stat`, `--types`, `--name-only`, `--git`, `--color-words`, `--tool <TOOL>` (`:git` etc. select built-ins), `--context N`, and whitespace options. The short forms `-w`/`-b` exist on `diff`, `interdiff`, `show`, and `util diff`; elsewhere use `--ignore-all-space`/`--ignore-space-change`.

### Creating and describing

| Command | Notes |
| --- | --- |
| `jj new [REVSETS]` | New empty change on the given parents (default `@`); several parents make a merge. `-m`, `--no-edit` (do not move `@`), `-A`, `-B`. |
| `jj describe [REVSETS]` | Opens the editor unless `-m` or `--stdin`. The same message is applied to every revision given. `--editor` forces the editor. |
| `jj commit [FILESETS]` | `describe` + `new` on `@`. With FILESETS or `-i`, the selected changes stay in `@` and the rest move to a new child. `-m`; no `--stdin`. Does not move bookmarks. |
| `jj metaedit [REVSETS]` | Metadata without content: `-m`, `--author "Name <email>"`, `--author-timestamp`, `--update-author`, `--update-author-timestamp`, `--update-change-id`, `--force-rewrite`. |
| `jj edit <REVSET>` | Make a revision the working-copy commit. |
| `jj next [N]` / `jj prev [N]` | Move `@` along the graph. `--edit`/`--no-edit` (default from `ui.movement.edit`), `--conflict`. |

### Moving changes between commits

| Command | Notes |
| --- | --- |
| `jj squash [FILESETS]` | Move changes from `@` (or `-r`, or `--from`) into the parent (or `--into`). The emptied source is abandoned unless `-k`. If both source and destination have descriptions, it prompts for a combined one unless `-m` or `-u/--use-destination-message`. `-i`/`--tool` select hunks. Experimental `-o/-A/-B` create a new commit. |
| `jj split [FILESETS]` | Split a revision (`-r`, default `@`) in two. FILESETS select the first commit's contents without an editor; with no FILESETS, the diff editor opens. `-m` describes the selected commit; the other keeps the original description. `-p/--parallel` makes siblings. `-o/-A/-B` move the selected part elsewhere. Without `-o/-A/-B`, bookmarks move to the second commit. |
| `jj absorb [FILESETS]` | Move each hunk of `--from` (default `@`) into the closest mutable ancestor that last changed those lines (`--into`, default `mutable()`). Ambiguous hunks stay. |
| `jj restore [FILESETS]` | Copy contents `--from` → `--into` (each defaults to `@`). No flags: reset `@` to its parents. `-c/--changes-in R` undoes a revision's changes. |
| `jj diffedit` | Edit a revision's changes in a diff editor. |
| `jj file chmod`, `jj file delete`, `jj file edit` | Change files in any revision (`-r`, default `@`) without checking it out. `file edit` opens the editor. |
| `jj file track` / `jj file untrack` | Track files outside `snapshot.auto-track`; untrack files that are already ignored. |

`--restore-descendants` (on `abandon`, `diffedit`, `restore`, `file delete/edit`, `run`) keeps descendants' contents instead of their diffs.

### Rearranging history

| Command | Notes |
| --- | --- |
| `jj rebase` | Source: `-b` (default `-b @`), `-s`, or `-r`. Destination: `-o`, `-A`, or `-B` (one required). `--skip-emptied`, `--keep-divergent`, `--simplify-parents`. `-r` may move a revision onto its own descendant. |
| `jj duplicate [REVSETS]` | Copy revisions (default onto their own parents, or `-o/-A/-B`). |
| `jj revert -r REVSETS -o/-A/-B` | Apply the inverse of revisions. Git's `git revert R` is `jj revert -r R -B @`. |
| `jj abandon [REVSETS]` | Drop revisions, rebasing descendants onto their parents. `--retain-bookmarks`. |
| `jj parallelize [REVSETS]` | Make revisions siblings, keeping outside ancestors and descendants. |
| `jj simplify-parents` | Remove parents that are ancestors of other parents. Default `revsets.simplify-parents`. |
| `jj arrange [REVSETS]` | TUI for reordering and abandoning. |
| `jj converge [-r REVSETS]` | Resolve divergence. See [concepts.md](concepts.md#divergence-resolution). |

### Running tools over revisions

| Command | Notes |
| --- | --- |
| `jj fix [-s REVSETS] [FILESETS]` | Pipe changed files through configured `fix.tools` (stdin → stdout) in each revision and its descendants. Default `revsets.fix` = `reachable(@, mutable())`. Never creates conflicts. `--include-unchanged-files`, `-a/--all-lines`. |
| `jj run [-r REVSETS] -- CMD…` | Run a command in an isolated working copy per revision and amend each with the result. Default `revsets.run` = `reachable(@, mutable())`. Revisions start oldest first. `-j` jobs, `--ignore-changes` (read-only; allowed on immutable commits), `--ignore-errors`, `--restore-descendants`, `--clean`, `--root`, `--passthrough`, `--sparse-patterns`. Sets `JJ_CHANGE_ID`, `JJ_COMMIT_ID`, `JJ_WORKSPACE_ROOT`. `jj` commands work inside the command. |
| `jj bisect run --range REVSETS -- CMD…` | Find the first bad revision. Exit 0 = good, 125 = skip, 127 = abort, other = bad. Each candidate becomes `@`. Pre-checks the endpoints unless `--trust-endpoints`. `--find-good` inverts. Target ID in `$JJ_BISECT_TARGET`. |

### Bookmarks, tags, remotes, Git

See [bookmarks-and-remotes.md](bookmarks-and-remotes.md) and [git-interop.md](git-interop.md).

### Operations, workspaces, sparse, signing, config

| Command | See |
| --- | --- |
| `jj undo`, `jj redo`, `jj op …` | [operation-log.md](operation-log.md) |
| `jj workspace …` | [workspaces.md](workspaces.md) |
| `jj sparse set --add P --remove P --clear`, `list`, `reset`, `edit` | Each workspace's materialized paths (prefix patterns; `.` = everything). |
| `jj sign [-r]`, `jj unsign [-r]` | Needs a signing backend. `sign` always re-signs. Default `revsets.sign`. |
| `jj config list/get/set/unset/edit/path/gc` | [config.md](config.md) |

### Utilities

| Command | Notes |
| --- | --- |
| `jj util snapshot` | Snapshot the working copy now. Prints no operation ID. |
| `jj util exec -- CMD…` | Run an external command with `JJ_WORKSPACE_ROOT` set; used for multi-command aliases. |
| `jj util diff PATH1 PATH2` | Diff two files on disk. |
| `jj util gc [--expire now]` | Garbage-collect objects and operations no longer referenced (default: older than 2 weeks). |
| `jj util completion <shell>` | Static completions. Dynamic: `COMPLETE=<shell> jj` (fish ≥ 4.0.2 loads them automatically). |
| `jj util config-schema`, `jj util markdown-help`, `jj util install-man-pages`, `jj util backend name` | Schema, help, man pages, backend name. |

## Commands that open an editor or a UI

| Command | Opens | Non-interactive form |
| --- | --- | --- |
| `describe` | Editor | `-m MSG`, `--stdin` |
| `commit` | Editor | `-m MSG` |
| `split` | Diff editor (no FILESETS); never an editor when `-m` is given | `split FILESETS -m MSG` |
| `squash` | Editor when both descriptions are non-empty; diff editor with `-i` | `-m MSG` or `-u` |
| `commit -i`, `restore -i`, `absorb -i`, `squash -i`, `diffedit` | Diff editor | FILESETS where available, or a scripted `--tool` (see [automation.md](automation.md#scripted-diff-editor)) |
| `resolve` | Merge tool | `--tool :ours`, `--tool :theirs`, `--list` |
| `converge` | Prompts and merge tool | `--no-interactive` |
| `file edit`, `config edit`, `sparse edit` | Editor | A scripted `JJ_EDITOR`; `config set`; `sparse set` |
| `arrange` | TUI | None |

## Removed and renamed

| Removed | Replacement |
| --- | --- |
| `commit --author/--reset-author`, `describe --author/--reset-author/--edit/--no-edit` (0.42) | `jj metaedit --author/--update-author`; `describe --editor` |
| `git push --allow-new` (0.42), `git.push-new-bookmarks`, `git.auto-local-bookmark` | Push auto-tracks new bookmarks; `remotes.<name>.auto-track-bookmarks` |
| `metaedit --update-committer-timestamp` (0.42) | `metaedit --force-rewrite` |
| `git clone --fetch-tags` (0.44) | `--tag PATTERN` |
| `git_head()`, `git_refs()` revset/template functions; Git-style symbols like `refs/heads/main` (0.43) | `name` or `name@remote` |
| `bookmark track <kind>:<name>@<remote>` (0.43) | `name@remote`, or `NAME --remote R` |
| `ui.revsets-use-glob-by-default` (0.43) | Glob is always the default |
| `Operation.tags()` template method (deprecated 0.41) | `.attributes()` |
| `jj file search` defaulting to `glob:` (changed 0.41) | Default is `regex:` |
