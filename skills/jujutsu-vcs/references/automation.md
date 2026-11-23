# Automation and scripting

Interfaces for driving jj without a terminal user: editors, diff editors, merge tools, output formats, and isolation. Behaviors marked *verified* were tested on jj 0.46.0.

## Non-interactive forms

| Command | Non-interactive form |
| --- | --- |
| `describe` | `-m MSG`, or `--stdin` (reads the message from standard input; the safe form for messages containing shell metacharacters) |
| `commit` | `-m MSG` (`commit` has no `--stdin`; use `describe --stdin` then `new`) |
| `new` | `-m MSG` |
| `split` | `split FILESETS -m MSG` opens no editor (*verified*); the selected part gets MSG, the remainder keeps the original description |
| `squash` | `-m MSG` or `-u/--use-destination-message` when both commits have descriptions |
| `resolve` | `--tool :ours`, `--tool :theirs`, or an automatic tool such as `mergiraf` |
| `converge` | `--no-interactive` (exits without changes if it would prompt) |
| `config edit`, `sparse edit` | `config set` / `config unset`; `sparse set` |
| `-i` on `commit`, `squash`, `restore`, `absorb`; `split` without FILESETS; `diffedit` | A [scripted diff editor](#scripted-diff-editor) |
| `file edit` | A [scripted editor](#editor) |
| `arrange` | None (TUI only) |

## Editor

- Selection order: `JJ_EDITOR` > `ui.editor` > `VISUAL` > `EDITOR` > nano (Notepad on Windows).
- jj writes the text to a temporary file (for descriptions, a `*.jjdescription` file) and runs the editor with its path as the last argument, or substituted for `$path` (and `$line`) when those appear in `ui.editor`.
- After the editor exits with status 0, jj reads the file back. Lines starting with `JJ:` are removed, and so is everything after a `JJ: ignore-rest` line (*verified*). A non-zero exit fails the command (`Error: Failed to edit description`, *verified*).
- An unchanged file keeps the pre-filled text. `JJ_EDITOR=true jj describe` leaves the description unchanged (*verified*: "Nothing changed."). When `jj squash` prompts for a combined description, an unchanged file keeps jj's combination of both descriptions (*verified*).
- A script that writes the file works as a non-interactive editor, for example for `jj file edit` or for supplying a description computed from the pre-filled text.

## Scripted diff editor

Commands that select hunks (`split`, `squash -i`, `commit -i`, `restore -i`, `absorb -i`, `diffedit`) run the diff editor from `ui.diff-editor` or `--tool NAME`. The tool interface:

- `merge-tools.<name>.program`: the executable.
- `merge-tools.<name>.edit-args`: its arguments (default `["$left", "$right"]`).
- `$left`: a directory with the original contents of the files involved.
- `$right`: a directory with the proposed result. **jj reads the result back from `$right` after the tool exits.** Only the files involved in the diff are present.
- `$output` (optional, 3-pane tools): a directory initialized as a copy of `$right`; when given, the result is read from it.
- `$right` also contains `JJ-INSTRUCTIONS` (*verified*); changes to it are ignored. `ui.diff-instructions = false` omits it.
- `edit-invocation-mode = "file-by-file"` runs the tool once per file instead of once per directory pair.

For `split`, the content left in `$right` becomes the first commit; for `squash -i`, it is what moves into the destination. Restoring a file in `$right` from `$left` excludes that file's changes from the selection.

Example (*verified* with `jj split --tool keep-a -m MSG` and `jj squash -i --tool keep-a`): select everything except changes to `b.txt`.

```sh
#!/bin/sh
# keep-a: $1 = left, $2 = right
rm -f "$2/b.txt"
cp "$1/b.txt" "$2/b.txt" 2>/dev/null || true
```

```toml
[merge-tools.keep-a]
program = "/path/to/keep-a"
edit-args = ["$left", "$right"]
```

The same tool can be given for one command with `--config`:

```sh
jj --config 'merge-tools.keep-a.program="/path/to/keep-a"' split --tool keep-a -m "msg"
```

## Scripted merge tool

`jj resolve --tool NAME` runs `merge-tools.<name>.program` with `merge-args` (required; no default):

| Variable | Value |
| --- | --- |
| `$left`, `$right` | Files with each side's content |
| `$base` | File with the base content |
| `$output` | File jj reads after the tool exits (required) |
| `$marker_length` | Conflict marker length to use |
| `$path` | Repo-relative path (`/` separators) |

Exit status 0 with content in `$output` resolves the file. A non-zero status cancels, unless it is listed in `merge-conflict-exit-codes`, in which case `$output` is parsed as a partial resolution (jj or Git diff3 markers). `merge-tool-edits-conflict-markers = true` pre-fills `$output` with the conflict.

## Output for programs

| Need | Form |
| --- | --- |
| No pager | `--no-pager`, `ui.paginate = "never"`, or `JJ_PAGER=cat` |
| No color | `--color=never` (output is uncolored when not a terminal anyway) |
| No graph | `-G`/`--no-graph` on `log`, `evolog`, `op log`, `op show`, `op diff` |
| Fields per line | `-T` with explicit `"\n"` separators |
| JSON | `-T 'json(self) ++ "\n"'` or `-T 'json({"k" => v, …}) ++ "\n"'`; `String.escape_json()` for hand-built JSON |
| Stable diffs | `--git`, or `ui.diff-formatter = ":git"` |
| File lists | `jj diff --name-only`, `jj diff --summary`, `jj file list` |
| A raw config value | `jj config get NAME` |
| Full CLI help | `jj util markdown-help` |
| Less secondary output | `--quiet` |

JSON field names and types are usually stable across versions but not guaranteed.

## Resolving revisions in scripts

- Pass IDs through `commit_id(…)` or `change_id(…)` so a bookmark or tag with the same name cannot take priority.
- Use `exactly(x, 1)` to make a revset fail unless it resolves to one commit.
- Use `present(x)` for names that may not exist.
- Hidden or divergent commits need a commit ID or `<change>/<offset>`.
- Change IDs are stable across rewrites; commit IDs change on every rewrite, including the working copy's on every snapshot.

## Snapshots and side effects

| Need | Form |
| --- | --- |
| Read without snapshotting or updating files | `--ignore-working-copy` |
| Read the op log without merging divergent heads | `jj --at-op=@ --ignore-working-copy op log` |
| Snapshot explicitly (separate a script's operations from earlier edits) | `jj util snapshot` (prints no operation ID) |
| Current operation ID | `jj op log -G -n 1 -T 'id'` (full 128-hex-digit ID; `id.short()` for 12 digits; snapshots first) |
| Detect whether a command changed anything | Compare operation IDs before and after |
| Try a change without committing to it | `--no-integrate-operation`, then inspect with `--at-op OP` and adopt with `jj op integrate OP` |
| Monitor the log | `jj --ignore-working-copy log` on a timer, or watch `.jj/repo/op_heads/heads/` |

Background tools that run jj while a user works should pass `--ignore-working-copy`, so their snapshots do not race the user's commands.

## Isolation and identity

| Need | Form |
| --- | --- |
| Ignore user and system config | `JJ_CONFIG=` (empty); repo and workspace config still load |
| Use a specific config | `JJ_CONFIG=/path/to/config.toml` or `--config-file PATH` |
| One-off settings | `--config NAME=VALUE` (repeatable) |
| Settings only for automated sessions | A `[[--scope]]` with `--when.environments = ["SOME_VAR"]` in user config |
| Commit identity | `JJ_USER`, `JJ_EMAIL` (override `user.name`, `user.email`) |
| Label operations | `JJ_OP_USERNAME`, `JJ_OP_HOSTNAME` (recorded in each operation; shown in `jj op log`) |

## Variables jj sets for child processes

| Variable | Set by |
| --- | --- |
| `JJ_CHANGE_ID`, `JJ_COMMIT_ID`, `JJ_WORKSPACE_ROOT` | `jj run` (per revision; `jj` commands work inside) |
| `JJ_BISECT_TARGET` | `jj bisect run` |
| `JJ_WORKSPACE_ROOT` | `jj util exec` |

`jj fix` tools receive file content on standard input, write the result to standard output, and get `$root` and `$path` substituted into their arguments.

## Exit codes

`jj bisect run` interprets the command's status: 0 good, 125 skip, 127 abort, other values bad. Other commands exit non-zero on error. `jj run --ignore-errors` ignores failed commands' statuses.

## Things that block or prompt

- Any command that opens an editor or diff editor waits for it to exit. With no terminal, set `JJ_EDITOR` (or `ui.editor`) and pass `--tool` or FILESETS.
- `jj converge` without `--no-interactive` and `jj config gc` prompt.
- The pager waits on a terminal; disable it as above.
- New files over `snapshot.max-new-file-size` (1 MiB) are not tracked; jj prints `Warning: Refused to snapshot some files` (*verified*) and continues.
