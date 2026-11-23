# Configuration

`jj help -k config` and `jj util config-schema` are the version-exact sources; `jj config list --include-defaults` shows every effective value.

## Layers

Later layers override earlier ones.

| Order | Layer | Location | Edit with |
| --- | --- | --- | --- |
| 1 | Built-in | `cli/src/config/` in the jj source | — |
| 2 | System | `/etc/jj/config.toml`, then `/etc/jj/conf.d/*.toml` (Unix) | `jj config edit --file PATH` |
| 3 | User | See [Locations](#locations) | `jj config edit --user` |
| 4 | Repo | Outside the repo (see [Locations](#locations)) | `jj config edit --repo` |
| 5 | Workspace | Outside the repo | `jj config edit --workspace` |
| 6 | Environment | `JJ_USER`, `JJ_EMAIL`, `JJ_EDITOR`, `JJ_PAGER`, `JJ_OP_HOSTNAME`, `JJ_OP_USERNAME` | — |
| 7 | Command line | `--config NAME=VALUE`, `--config-file PATH` | — |

`[[--scope]]` tables with `--when` conditions apply within whichever file defines them (see [Conditional settings](#conditional-settings)).

## Locations

| Config | Path |
| --- | --- |
| User | `~/.jjconfig.toml`, then `<config-dir>/jj/config.toml` (preferred), then `<config-dir>/jj/conf.d/*.toml` in lexicographic order. `<config-dir>` is `$XDG_CONFIG_HOME` or `~/.config` on Linux and macOS, `%APPDATA%` on Windows. |
| Repo | `<config-dir>/jj/repos/<config-id>/config.toml`, where `.jj/repo/config-id` holds the ID |
| Workspace | `<config-dir>/jj/workspaces/<config-id>/config.toml`, where `.jj/workspace-config-id` holds the ID |

- `jj config path --user|--repo|--workspace` prints the path; for repo and workspace it creates the directory if needed.
- Repo and workspace config are kept outside the repo so that a repo received from someone else cannot run commands through settings such as `fix.tools`. A `metadata.binpb` beside each config records the repo path. If the repo is copied (not moved), the copy gets a new config ID and a copy of the config the next time jj runs in it.
- `jj config gc` lists, and on confirmation removes, config directories for repos that no longer exist.
- **`JJ_CONFIG`** replaces both user and system config when set, even to an empty string. It may name a file, a directory, or several paths separated by `:` (`;` on Windows). It does not affect repo or workspace config. `JJ_CONFIG= jj …` runs with no user config.
- Editors validate config files with `#:schema https://docs.jj-vcs.dev/latest/config-schema.json` as the first line.

## The `jj config` command

| Subcommand | Behavior |
| --- | --- |
| `list [NAME]` | Effective values. `--include-defaults`, `--include-overridden`, scope flags, `-T`. |
| `get NAME` | Raw value without formatting, for scripts |
| `set SCOPE NAME VALUE` | VALUE is TOML; bare strings may omit quotes |
| `unset SCOPE NAME` | Remove a key |
| `edit SCOPE` | Open the file in the editor (creates it) |
| `path SCOPE` | Print the file's path |
| `gc` | Remove repo config for deleted repos |

`SCOPE` is `--user`, `--repo`, `--workspace`, or `--file PATH` (`--file` must be a location jj loads). `--user` targets the primary user file, or the first file in `conf.d/`.

## TOML notes

- Dotted keys and tables are interchangeable; dotted keys must come before the first table heading in a file.
- Values are parsed first by TOML and then by jj's languages. Prefer TOML literal strings (`'…'`, `'''…'''`) for revsets and templates so TOML does not consume escapes such as `\n`.
- With `jj config set`, wrap values containing apostrophes in a TOML multi-line literal: `jj config set --user foo.bar "'''{don't}'''"`.
- With `--config`, no spaces around `=`: `jj --config ui.color=always log`.

## Conditional settings

```toml
[[--scope]]
--when.repositories = ["~/oss"]
[--scope.user]
email = "me@oss.example"
```

A `--when` key at the top level of a file applies to the whole file (useful in `conf.d/`). Several conditions in one scope must all hold; several values in one condition are alternatives.

| Condition | Matches |
| --- | --- |
| `--when.repositories` | Repo path prefixes (absolute or `~`; case-sensitive). With several workspaces, this is the main workspace's path. |
| `--when.workspaces` | Workspace path prefixes |
| `--when.hostnames` | `operation.hostname`, exactly |
| `--when.commands` | Subcommand prefixes, space-separated: `"file"` matches `jj file show`; `"file show"` does not match `jj file list` |
| `--when.platforms` | `windows`, `unix`, `linux`, `macos`, `freebsd`, … |
| `--when.environments` | `"NAME=VALUE"` (variable has that value) or `"NAME"` (variable is set) |

## Environment variables

| Variable | Effect |
| --- | --- |
| `JJ_CONFIG` | Replaces user and system config (see [Locations](#locations)) |
| `JJ_USER`, `JJ_EMAIL` | Override `user.name`, `user.email` |
| `JJ_EDITOR` | Overrides `ui.editor` |
| `JJ_PAGER` | Overrides `ui.pager` (`PAGER` is ignored) |
| `JJ_OP_HOSTNAME`, `JJ_OP_USERNAME` | Override `operation.hostname`, `operation.username` (recorded in each operation) |
| `VISUAL`, `EDITOR` | Editor fallbacks when `ui.editor` is unset |
| `NO_COLOR` | Color fallback; `ui.color` overrides it |
| `COMPLETE=<shell>` | Print dynamic completions |

Environment overrides beat config files but not `--config`/`--config-file`.

## Settings by area

### Identity and operations

| Key | Default | Meaning |
| --- | --- | --- |
| `user.name`, `user.email` | — | Author and committer identity; `mine()` uses `user.email` |
| `operation.hostname`, `operation.username` | system values | Recorded in each operation; `--when.hostnames` matches the hostname |

### UI

| Key | Default | Meaning |
| --- | --- | --- |
| `ui.color` | `auto` | `always`, `never`, `debug`, `auto` |
| `ui.default-command` | `"log"` | Command run by bare `jj` (string or array) |
| `ui.editor` | nano (Notepad on Windows) | Editor command; supports `$path` and `$line`. Priority: `JJ_EDITOR` > `ui.editor` > `VISUAL` > `EDITOR`. GUI editors need a wait flag (`code -w`). |
| `ui.pager` | `less -FRXK` (built-in `:builtin` on Windows) | Pager command; a pipeline needs `["sh", "-c", "…"]` |
| `ui.paginate` | `auto` | `never` disables paging |
| `ui.streampager.*` | — | Built-in pager: `wrapping`, `interface`, `show-ruler` |
| `ui.diff-formatter` | `:color-words` | `:git`, `:color-words`, `:summary`, `:stat`, `:types`, `:name-only`, a tool name, or an argv array |
| `ui.diff-editor` | `:builtin` | Tool for `split`, `squash -i`, `diffedit`, and other `-i` commands |
| `ui.diff-instructions` | `true` | Add the `JJ-INSTRUCTIONS` file to diff-editor sessions |
| `ui.merge-editor` | — | Tool for `jj resolve` |
| `ui.conflict-marker-style` | `diff` | `diff`, `snapshot`, `git` (see [conflicts.md](conflicts.md)) |
| `ui.graph.style` | `curved` | `curved`, `square`, `ascii`, `ascii-large` |
| `ui.log-word-wrap` | `false` | Wrap log, evolog, and op log content |
| `ui.movement.edit` | `false` | Default `--edit` for `next`/`prev` |
| `ui.bookmark-list-sort-keys`, `ui.tag-list-sort-keys` | `["name"]` | Same keys as `--sort` |
| `ui.show-cryptographic-signatures` | `false` | Verify and show signatures in templates (slow) |

### Diffs

| Key | Default | Meaning |
| --- | --- | --- |
| `diff.color-words.context` | `3` | Context lines |
| `diff.color-words.max-inline-alternation` | `3` | Inline alternations before switching to line form (`0` = like git, `-1` = always inline; experimental) |
| `diff.color-words.conflict` | `materialize` | `materialize` or `pair` (experimental) |
| `diff.git.context` | `3` | Context lines |
| `diff.git.show-path-prefix` | `true` | `a/` and `b/` prefixes |
| `diff.stat.max-bar-width` | unbounded | Maximum width of the `++--` bar |

### Tools (`merge-tools.<name>.*`)

| Key | Meaning |
| --- | --- |
| `program` | Executable (default: the tool name) |
| `diff-args` | Arguments for diff display (`$left`, `$right`, `$width`; default `["$left", "$right"]`; `[]` = not usable for diffs) |
| `diff-invocation-mode` | `dir` (default) or `file-by-file` |
| `diff-expected-exit-codes` | Exit codes that do not produce a warning |
| `edit-args` | Arguments for diff editing (`$left`, `$right`, `$output`; default `["$left", "$right"]`; `[]` = not usable for editing) |
| `edit-invocation-mode` | `dir` (default) or `file-by-file` |
| `merge-args` | Arguments for `jj resolve` (`$left`, `$base`, `$right`, `$output` required, `$marker_length`, `$path`); no default |
| `merge-conflict-exit-codes` | Exit codes meaning "output contains conflict markers" (partial resolution) |
| `merge-tool-edits-conflict-markers` | Pre-fill `$output` with markers |
| `conflict-marker-style` | Marker style for this tool |

Built-in merge tools usable without configuration when installed: `kdiff3`, `meld`, `mergiraf`, `smerge`, `vimdiff`, `vscode`, `vscodium`. Built-in diff-editor configurations: `meld`, `meld-3`, `diffedit3`, `diffedit3-ssh`. See [automation.md](automation.md#scripted-diff-editor) for scripting these interfaces.

### Snapshot and working copy

| Key | Default | Meaning |
| --- | --- | --- |
| `snapshot.auto-track` | `all()` | Fileset of new files tracked automatically |
| `snapshot.max-new-file-size` | `1MiB` | New files above this size are refused (`0` = no limit; accepts `"10MiB"` or bytes) |
| `snapshot.auto-update-stale` | `false` | Update stale working copies without asking |
| `working-copy.eol-conversion` | `none` | `none`, `input`, `input-output` (like `core.autocrlf`; `.gitattributes` is not read) |
| `working-copy.exec-bit-change` | `auto` | `respect`, `ignore`, `auto` (Unix only) |
| `fsmonitor.backend` | `none` | `none` or `watchman` |
| `fsmonitor.watchman.register-snapshot-trigger` | `false` | Snapshot automatically on file changes |

### Merging

| Key | Default | Meaning |
| --- | --- | --- |
| `merge.hunk-level` | `line` | `line` or `word` |
| `merge.same-change` | `accept` | `accept` resolves sides that made the same change; `keep` leaves them conflicted |

### Git and remotes

| Key | Default | Meaning |
| --- | --- | --- |
| `git.colocate` | `true` | Default for `jj git init`, `jj git clone`, and `jj workspace add` |
| `git.object-hash` | `sha1` | Hash for new repos (`sha256`); fixed at init |
| `git.fetch` | `origin` (or the only remote) | Remote name, list, or pattern for `jj git fetch` |
| `git.push` | `origin` (or the only remote) | Remote name, list, or pattern for `jj git push` |
| `git.private-commits` | `none()` | Revset of commits that cannot be pushed (descendants are blocked too) |
| `git.sign-on-push` | `false` | Sign your unsigned mutable commits at push time |
| `git.abandon-unreachable-commits` | `true` | Abandon commits no longer reachable from remote or Git refs |
| `git.track-default-bookmark-on-clone` | `true` | Create a local bookmark for the default branch on clone |
| `git.record-synthetic-predecessors` | `true` | Reconstruct evolution history from change IDs on import |
| `git.write-change-id-header` | `true` | Write the `change-id` header into Git commits |
| `git.executable-path` | `git` | Git binary for remote operations |
| `remotes.<name>.fetch-bookmarks` | Git refspecs | String pattern of bookmarks to fetch |
| `remotes.<name>.fetch-tags` | all | String pattern of tags to fetch (`'~*'` = none) |
| `remotes.<name>.auto-track-bookmarks` | — | Pattern of new bookmarks (fetched or created) to track |
| `remotes.<name>.auto-track-created-bookmarks` | — | Pattern of locally created bookmarks to track |

### Gerrit

| Key | Meaning |
| --- | --- |
| `gerrit.default-remote` | Remote for `jj gerrit upload` (fallback: a remote named `gerrit`) |
| `gerrit.default-remote-branch` | Target branch |
| `gerrit.review-url` | Use `Link:` trailers instead of `Change-Id:` |

### Signing

| Key | Meaning |
| --- | --- |
| `signing.backend` | `gpg`, `gpgsm`, `ssh`, `none` |
| `signing.key` | Key ID, SSH public key, or path (default: the key for `user.email`) |
| `signing.behavior` | `drop` (never; drop old signatures), `keep` (re-sign your previously signed commits), `own` (sign your commits when modified), `force` (sign every modified commit) |
| `signing.backends.<backend>.program` | Executable |
| `signing.backends.gpg.allow-expired-keys`, `signing.backends.gpgsm.allow-expired-keys` | Accept expired keys when verifying |
| `signing.backends.ssh.allowed-signers`, `signing.backends.ssh.revocation-list` | Verification files |

### Commands

| Key | Meaning |
| --- | --- |
| `fix.tools.<name>.command` | Argv; `$root` (workspace root) and `$path` (repo-relative path) are substituted. Reads stdin, writes stdout. |
| `fix.tools.<name>.patterns` | List of filesets (empty = no files) |
| `fix.tools.<name>.enabled` | Default `true` |
| `fix.tools.<name>.line-range-args` | Template args with `$first`/`$last`, repeated per modified range |
| `fix.tools.<name>.run-tool-if-zero-line-ranges` | Default `false` |
| `run.jobs` | Default parallelism for `jj run` (default 1) |
| `aliases.<name>` | Argv array, or `{ definition = […], doc = "…", enabled = true }` |
| `revset-aliases.*`, `fileset-aliases.*`, `template-aliases.*` | See the language references |
| `revsets.*`, `templates.*` | See [revsets.md](revsets.md#revset-settings) and [templates.md](templates.md#template-settings) |
| `colors.<labels>` | Color name, `#rrggbb`, `ansi-color-N`, or a table with `fg`, `bg`, `bold`, `dim`, `italic`, `underline`, `reverse`, `crossed-out` |

Fix tools that apply to the same file run in lexicographic order of their names, each receiving the previous tool's output.
