# Template language

Templates format command output. Commands that accept `-T`/`--template` evaluate a template expression against a top-level object, `self`.

## Keywords

All 0-argument methods of `self`'s type are available as bare keywords: in `jj log`, `commit_id` = `self.commit_id()`.

| Command | `self` type | Default template setting |
| --- | --- | --- |
| `jj log`, `jj show` | `Commit` | `templates.log`, `templates.show` |
| `jj evolog` | `CommitEvolutionEntry` | `templates.evolog` |
| `jj op log`, `jj op show` | `Operation` | `templates.op_log`, `templates.op_show` |
| `jj bookmark list`, `jj tag list` | `CommitRef` | `templates.bookmark_list`, `templates.tag_list` |
| `jj workspace list` | `WorkspaceRef` | `templates.workspace_list` |
| `jj file list`, `jj file show` | `TreeEntry` | `templates.file_list`, `templates.file_show` |
| `jj file annotate` | `AnnotationLine` | `templates.file_annotate` |
| `jj diff -T` (per file) | `TreeDiffEntry` | — |
| `jj config list` | `name: String`, `value: ConfigValue`, `overridden: Boolean`, `source: String`, `path: Option<FsPath>` | `templates.config_list` |

`jj log -T` with no value lists the built-in templates: `builtin_log_compact` (default log), `builtin_log_comfortable`, `builtin_log_compact_full_description`, `builtin_log_detailed` (default show), `builtin_log_oneline`, `builtin_log_redacted`, `builtin_evolog_compact`, `builtin_op_log_compact`, `builtin_op_log_comfortable`, `builtin_op_log_oneline`, `builtin_op_log_redacted`, `builtin_workspace_list`, `builtin_config_list`, `builtin_config_list_detailed`, `builtin_draft_commit_description`, `builtin_draft_commit_description_with_diff`, and node templates. Definitions are in `cli/src/config/templates.toml` in the jj source.

## Literals

- `true`, `false`; integers.
- `"…"` string literals support `\"`, `\\`, `\t`, `\r`, `\n`, `\0`, `\e`, `\xHH`. Other escapes are errors.
- `'…'` string literals have no escapes and cannot contain `'`.
- Lambdas: `|x| expression`.
- Map literals (in `json()` only): `{"key" => value, …}`.

## Operators

From tightest to loosest. Infix operators of equal binding associate left to right.

| Level | Operator | Operands |
| --- | --- | --- |
| 1 | `x.f()`, `f(x)` | Method, function call |
| 2 | `-x`, `!x` | Integer negation, logical not |
| 3 | `p:x` | String pattern or pattern alias |
| 4 | `*`, `/`, `%` | Integer |
| 5 | `+`, `-` | Integer |
| 6 | `>=`, `>`, `<=`, `<` | Integer |
| 7 | `==`, `!=` | Boolean, ByteString, Integer, String |
| 8 | `&&` | Boolean, short-circuit |
| 9 | `\|\|` | Boolean, short-circuit |
| 10 | `++` | Concatenate templates |

## Global functions

| Function | Result |
| --- | --- |
| `if(cond, then, [else])` | Conditional |
| `try(expr, fallback…)` | First argument that evaluates without a runtime error (parse and type errors are not suppressed) |
| `coalesce(t…)` | First non-empty argument |
| `concat(t…)` | Concatenation |
| `join(sep, t…)` | Arguments separated by `sep` |
| `separate(sep, t…)` | Non-empty arguments separated by `sep` |
| `surround(prefix, suffix, t)` | `prefix ++ t ++ suffix` if `t` is non-empty |
| `fill(width, t, [break_words])` | Wrap at `width` |
| `indent(prefix, t)` | Prefix non-empty lines |
| `pad_start(width, t, [fill])`, `pad_end(…)`, `pad_centered(…)` | Pad to `width` (single-line content) |
| `truncate_start(width, t, [ellipsis])`, `truncate_end(…)` | Truncate to `width` (single-line content) |
| `label(labels, t)` | Apply color labels (space-separated) |
| `hyperlink(url, text, [fallback])` | OSC 8 hyperlink when color is enabled; otherwise `fallback` (default `text`) |
| `raw_escape_sequence(t)` | Emit escape sequences unsanitized (zero-width content only) |
| `stringify(t)` | Format to `String`, dropping labels |
| `replace(pattern, t, \|caps\| replacement)` | Replace pattern matches in formatted content, keeping other formatting |
| `json(value)` | Serialize to JSON; `json({"id" => commit_id, "tags" => tags})` builds an object |
| `hash(t)` | Hex digest of the content |
| `config(name)` | `Option<ConfigValue>` for a config key |
| `git_web_url([remote])` | Best-effort HTTPS URL for a remote (default `origin`); empty on failure |

## Types

Conversions: **B** = to Boolean, **S** = Serialize (usable in `json()`), **T** = printable.

### Commit (S)

| Method | Returns |
| --- | --- |
| `.description()` | `String` (ends with `\n` when non-empty) |
| `.trailers()` | `List<Trailer>` (in order; keys may repeat) |
| `.change_id()`, `.commit_id()` | `ChangeId`, `CommitId` |
| `.parents()` | `List<Commit>` |
| `.author()`, `.committer()` | `Signature` |
| `.signature()` | `Option<CryptographicSignature>` |
| `.mine()` | Author email is the user's |
| `.working_copies()` | `List<WorkspaceRef>` whose `@` is this commit |
| `.current_working_copy()` | This workspace's `@` |
| `.bookmarks()` | Local and remote bookmarks (a tracked remote bookmark only if it differs from local) |
| `.local_bookmarks()`, `.remote_bookmarks()` | `List<CommitRef>` |
| `.tags()`, `.local_tags()`, `.remote_tags()` | `List<CommitRef>` |
| `.divergent()`, `.hidden()`, `.immutable()`, `.conflict()`, `.empty()`, `.root()` | `Boolean` |
| `.change_offset()` | `Option<Integer>` |
| `.contained_in(revset)` | `Boolean`; `revset` is a string literal |
| `.diff([fileset])` | `TreeDiff` against the parents |
| `.files([fileset])` | `List<TreeEntry>` of files present in the commit; changed files are `.diff().files()` |
| `.conflicted_files()` | `List<TreeEntry>` |

### CommitEvolutionEntry (S)

`.commit()`, `.operation()`, `.predecessors()` (`List<Commit>`), `.inter_diff([fileset])` (`TreeDiff` against the predecessors, rebased onto this commit's parents).

### CommitRef (S, T) — bookmark or tag

| Method | Returns |
| --- | --- |
| `.name()`, `.remote()` | `RefSymbol`, `Option<RefSymbol>` |
| `.present()`, `.conflict()` | `Boolean` |
| `.normal_target()` | `Option<Commit>` (when not conflicted) |
| `.removed_targets()`, `.added_targets()` | `List<Commit>` |
| `.tracked()` | Tracked by a local ref (true even if the local ref was deleted but the deletion is not pushed) |
| `.tracking_present()` | Tracked and the local ref exists |
| `.tracking_ahead_count()`, `.tracking_behind_count()` | `SizeHint` relative to the tracking local ref |
| `.synced()` | Local ref equals all tracked remotes, or remote ref equals its local ref |

### Operation (S)

`.id()` (`OperationId`), `.description()`, `.attributes()`, `.time()` (`TimestampRange`), `.user()`, `.workspace_name()` (empty if none), `.snapshot()`, `.current_operation()`, `.root()`, `.parents()`.

### Files and diffs

| Type | Methods |
| --- | --- |
| `TreeDiff` | `.files()` (`List<TreeDiffEntry>`), `.git([context])`, `.color_words([context])`, `.stat([width], [max_bar_width])` (`DiffStats`), `.summary()` |
| `TreeDiffEntry` | `.path()` (target path for copies and renames), `.display_diff_path()`, `.status()` (`modified`, `added`, `removed`, `copied`, `renamed`), `.status_char()` (`M A D C R`), `.source()`, `.target()` (`TreeEntry`) |
| `TreeEntry` | `.path()`, `.normal_value()` (`Option<TreeValue>`; unset if absent or conflicted), `.conflict()`, `.conflict_side_count()`, `.file_type()` (`file`, `symlink`, `tree`, `git-submodule`, `conflict`), `.executable()` |
| `TreeValue` (T) | Prints the full object ID (for a submodule, the recorded commit) |
| `DiffStats` (T) | `.files()` (`List<DiffStatEntry>`), `.total_added()`, `.total_removed()`; prints as a histogram |
| `DiffStatEntry` | `.path()`, `.display_diff_path()`, `.status()`, `.status_char()`, `.lines_added()`, `.lines_removed()`, `.bytes_delta()` |
| `AnnotationLine` | `.commit()`, `.content()` (`ByteString`, includes newline), `.line_number()`, `.original_line_number()`, `.first_line_in_hunk()` |
| `RepoPath` (S, T) | Repo-relative, `/`-separated. `.display()` (native, cwd-relative), `.absolute()` (`FsPath`), `.parent()` (`Option<RepoPath>`) |
| `FsPath` (S, T) | Filesystem path. `.absolute()`, `.relative()` (to cwd) |

### Identifiers, people, time

| Type | Methods |
| --- | --- |
| `ChangeId` (S, T) | `.short([len])`, `.shortest([min_len])`, `.normal_hex()` |
| `CommitId` (S, T) | `.short([len])`, `.shortest([min_len])` |
| `OperationId` (S, T) | `.short([len])` |
| `ShortestIdPrefix` (S, T) | `.prefix()`, `.rest()`, `.upper()`, `.lower()` |
| `Signature` (S, T) | `.name()`, `.email()` (`Email`), `.timestamp()` |
| `Email` (B, S, T) | `.local()`, `.domain()` (may lack `@`) |
| `Timestamp` (S, T) | `.ago()`, `.format(strftime)`, `.utc()`, `.local()`, `.after(date)`, `.before(date)`, `.since(ts)` |
| `TimestampRange` (S, T) | `.start()`, `.end()`, `.duration()` |
| `CryptographicSignature` | `.status()` (`good`, `bad`, `unknown`, `invalid`), `.key()`, `.display()`. These verify the signature and are slow; test presence with `if(commit.signature(), …)`. |
| `WorkspaceRef` (S, T) | `.name()`, `.target()` (`Commit`), `.root()` (`Option<FsPath>`; unset for workspaces created before jj 0.38) |
| `ConfigValue` (S, T) | `.as_boolean()`, `.as_integer()`, `.as_string()`, `.as_string_list()`; prints as TOML |
| `Trailer` (T) | `.key()`, `.value()` |
| `SizeHint` (S) | `.lower()`, `.upper()`, `.exact()` (Options), `.zero()` |

### Strings and lists

| Type | Methods |
| --- | --- |
| `String` (B, S, T) | `.len()` (bytes), `.contains(s)`, `.match(pattern)`, `.starts_with(s)`, `.ends_with(s)`, `.remove_prefix(s)`, `.remove_suffix(s)`, `.trim()`, `.trim_start()`, `.trim_end()`, `.substr(start, [end])` (byte indices; negative counts from the end), `.first_line()`, `.lines()`, `.split(pattern, [limit])`, `.replace(pattern, repl, [limit])` (`$0`, `$1` captures), `.upper()`, `.lower()`, `.escape_json()` |
| `ByteString` (B, S, T) | Same methods as `String` without `.escape_json()`; content may not be UTF-8 |
| `RefSymbol` (S, T) | A `String` rendered as a revset symbol (quoted when needed); not convertible to Boolean |
| `List` (B) | `.len()`, `.join(sep)`, `.filter(\|x\| …)`, `.map(\|x\| …)`, `.any(\|x\| …)`, `.all(\|x\| …)`, `.first()`, `.last()`, `.get(i)` (each `Option<T>`), `.reverse()`, `.skip(n)`, `.take(n)` |
| `List<Trailer>` | Also `.contains_key(key)` |
| `RegexCaptures` | `.len()`, `.get(i)`, `.name(n)` (for `replace()` lambdas) |

### Option (B)

- Converts to Boolean: true when set.
- Methods of the inner value can be called directly; calling one on an unset value is an error.
- In comparisons, unset is less than any set value.
- Types that already convert to Boolean (`String`, `List`) are never wrapped in `Option`; their unset value is empty.

### String patterns in templates

Same kinds as revsets (`exact:`, `glob:`, `regex:`, `substring:`, `-i`), but quotes are mandatory, and a **bare literal is a case-sensitive substring match**, unlike revsets where a bare pattern is a glob. Patterns can only appear at the call site; they cannot be stored in variables or aliases as values.

### Serialization

JSON field names and value types are usually stable across versions but are not guaranteed. Parsers should tolerate added fields.

## Aliases

Defined in `[template-aliases]`. Keywords, functions (overloadable by arity), and `name:x` patterns can be defined. Aliases shadow built-ins.

```toml
[template-aliases]
sh = 'commit_id.short()'
'format_field(key, value)' = 'key ++ ": " ++ value ++ "\n"'
'json:x' = 'json(x) ++ "\n"'
```

### Aliases used by the default templates

| Alias | Default | Controls |
| --- | --- | --- |
| `format_short_id(id)` | `id.shortest(12)` | ID display in log output |
| `format_short_change_id(id)`, `format_short_commit_id(id)` | `format_short_id(id)` | Per-kind ID display |
| `format_short_operation_id(id)` | — | Operation ID display |
| `format_timestamp(timestamp)` | — | Timestamps (`timestamp` or `timestamp.ago()`) |
| `format_time_range(time_range)` | relative | `jj op log` times |
| `format_short_signature(signature)` | `signature.email()` | Author display |
| `commit_timestamp(commit)` | committer timestamp | Which timestamp the log shows |
| `format_short_cryptographic_signature(sig)`, `format_detailed_cryptographic_signature(sig)` | — | Signature display (`ui.show-cryptographic-signatures = true`) |
| `default_commit_description` | empty | Text in a new description editor |

## Template settings

| Key | Purpose |
| --- | --- |
| `templates.log`, `show`, `evolog`, `op_log`, `op_show`, `bookmark_list`, `tag_list`, `workspace_list`, `config_list`, `file_list`, `file_show`, `file_annotate` | Default templates per command |
| `templates.log_node`, `templates.op_log_node` | Graph node symbols (`Option<Commit>` / `Operation` keywords) |
| `templates.draft_commit_description` | Editor content for descriptions (`self` is `Commit`) |
| `templates.new_description` | Description for `jj new` without `-m` (empty by default) |
| `templates.duplicate_description` | Description for `jj duplicate` copies |
| `templates.revert_description` | Description for `jj revert` commits |
| `templates.commit_trailers` | Trailers added to descriptions (one per line; exact duplicates skipped). Built-ins: `format_signed_off_by_trailer(commit)`, `format_gerrit_change_id_trailer(commit)`. |
| `templates.git_push_bookmark` | Name for `jj git push -c` bookmarks (default `"push-" ++ change_id.short()`) |

## Color labels

Output is labeled automatically by command, context, and method (`jj op log -T 'self.id().short()'` is labeled `op_log operation id short`). `--color=debug` shows the labels. `label()` adds custom ones. `jj config list --include-defaults --include-overridden colors` shows the effective colors.

## Examples

| Output | Command |
| --- | --- |
| Full IDs, one commit per line | `jj log -G -T 'commit_id ++ " " ++ change_id ++ "\n"'` |
| Parents of `@` | `jj log -G -r @ -T 'parents.map(\|c\| c.commit_id().short()).join(",")'` |
| Description with a fallback | `jj log -G -r @ -T 'coalesce(description, "(no description set)\n")'` |
| First bookmark or change ID | `jj log -T 'try(bookmarks.first().name(), change_id.shortest(8)) ++ "\n"'` |
| JSON Lines | `jj log -G -T 'json({"change" => change_id, "commit" => commit_id, "subject" => description.first_line()}) ++ "\n"'` |
| Object IDs on both sides of a diff | `jj diff -T 'path ++ " " ++ self.source().normal_value() ++ " -> " ++ self.target().normal_value() ++ "\n"'` |
| Bookmarks not in sync with their remote | `jj bookmark list -T 'if(!synced, name ++ "\n")'` |
| Workspace names and roots | `jj workspace list -T 'name ++ " " ++ coalesce(root, "?") ++ "\n"'` |
