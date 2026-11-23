# Revset language

A revset is an expression that selects a set of revisions. Commands that need a single revision fail if the revset resolves to zero or several commits.

## Symbols

| Symbol | Refers to |
| --- | --- |
| `@` | The working-copy commit of the current workspace |
| `<workspace>@` | Another workspace's working-copy commit |
| `<name>` | A tag, bookmark, commit ID prefix, or change ID prefix, in that priority order |
| `<name>@<remote>` | A remote bookmark or remote tag |
| `<change-id>/<n>` | The `n`th most recent commit of a change (`/0` = newest); needed for hidden or divergent commits |

- A commit ID or change ID prefix must be unique. A change ID must refer to a visible, non-divergent commit unless an offset is given.
- Symbol priority is tag, then bookmark, then ID. To force an interpretation, use `commit_id(x)`, `change_id(x)`, `bookmarks(exact:x)`, or `tags(exact:x)`.
- Quote a symbol to keep operators from being parsed: `"x-"` is the bookmark named `x-`. On the shell: `jj log -r '"x-"'`.
- An unknown symbol is an error at resolution time. `present(x)` turns it into the empty set.

## Operators

Listed from tightest to loosest binding. Infix operators of equal binding associate left to right.

| Level | Operator | Meaning |
| --- | --- | --- |
| 1 | `f(x)` | Function call |
| 2 | `x-`, `x+` | Parents, children (either may be empty) |
| 3 | `p:x` | String or date pattern, or a pattern alias |
| 4 | `x::` | Descendants of `x`, including `x` |
| 4 | `::x` | Ancestors of `x`, including `x` (= `root()::x`) |
| 4 | `x::y` | Descendants of `x` that are ancestors of `y` (Git's `--ancestry-path`) |
| 4 | `x..` | Not ancestors of `x` (= `~::x`) |
| 4 | `..x` | Ancestors of `x` except the root (= `::x ~ root()`) |
| 4 | `x..y` | Ancestors of `y` that are not ancestors of `x` (Git's `x..y`); `x` and `y` need not be related |
| 4 | `::` | All visible commits (= `all()`) |
| 4 | `..` | All visible commits except the root |
| 5 | `~x` | Complement |
| 6 | `x & y`, `x ~ y` | Intersection, difference |
| 7 | `x \| y` | Union |

`..` does not distribute over a union on its left: `(A | B)..` = `A.. & B..`.

Examples on the graph `D` (merge of `B` and `C`), `B` and `C` (children of `A`), `A` (child of root):

| Expression | Result | Expression | Result |
| --- | --- | --- | --- |
| `D-` | B, C | `A+` | B, C |
| `B::` | D, B | `B..` | D, C |
| `B::D` | D, B | `B..D` | D, C |
| `B::C` | (empty) | `B..C` | C |
| `..B` | B, A | `(C\|B)..` | D |

## Hidden revisions

Revsets search visible commits only. A hidden commit is included when named explicitly (commit ID, change offset, `name@remote`, `at_operation()`); its ancestors then join the search space for `all()`, `x..`, and `~x`, but not for `..visible_heads()`.

## Functions

`[arg]` is optional. Labelled arguments (`remote=`) can be passed by name.

### Graph

| Function | Result |
| --- | --- |
| `parents(x, [depth])` | `x-`; `parents(x, 3)` = `x---` |
| `children(x, [depth])` | `x+`; `children(x, 3)` = `x+++` |
| `ancestors(x, [depth])` | `::x`, optionally limited to `depth` generations |
| `descendants(x, [depth])` | `x::`, optionally limited |
| `first_parent(x, [depth])` | Parents, following only the first parent of merges |
| `first_ancestors(x, [depth])` | Ancestors along first parents only (like `git log --first-parent`) |
| `reachable(srcs, domain)` | Commits reachable from `srcs` through parent and child edges without leaving `domain`. `reachable(@, mutable())` is the current stack. |
| `connected(x)` | `x::x` |
| `heads(x)` | Commits in `x` with no descendants in `x` (= `x ~ ::x-`) |
| `roots(x)` | Commits in `x` with no ancestors in `x` (= `x ~ x+::`) |
| `fork_point(x)` | `heads(::x1 & … & ::xN)` |
| `merge_point(x)` | `roots(x1:: & … & xN::)` |
| `latest(x, [count])` | The `count` (default 1) most recent by committer timestamp |
| `bisect(x)` | Commits about half of `x` descend from |
| `exactly(x, count)` | `x`, or an error unless it has exactly `count` commits |
| `merges()` | Commits with more than one parent |
| `forks()` | Commits with more than one child |
| `visible_heads()` | All visible heads |
| `root()` | The root commit |
| `all()`, `none()` | Everything visible (plus named hidden commits and their ancestors); nothing |

### Identifiers and references

| Function | Result |
| --- | --- |
| `change_id(prefix)` | Commits with that change ID prefix (several if divergent; no match is not an error) |
| `commit_id(prefix)` | The commit with that commit ID prefix |
| `bookmarks([pattern])` | Local bookmark targets (all targets of conflicted bookmarks) |
| `remote_bookmarks([name], [[remote=]pattern])` | Remote bookmark targets; `@git` bookmarks only with `remote="git"` or `remote="*"` |
| `tracked_remote_bookmarks(…)`, `untracked_remote_bookmarks(…)` | Filtered by tracking state; same arguments |
| `tags([pattern])` | Local tag targets |
| `remote_tags(…)`, `tracked_remote_tags(…)`, `untracked_remote_tags(…)` | Same arguments as the bookmark versions |
| `working_copies()` | Every workspace's working-copy commit |

### Metadata and content (filters)

| Function | Matches commits whose... |
| --- | --- |
| `description(pattern)` | description matches. A non-empty description usually ends with `\n`: `description("")` is "no description", `description("foo\n")` is exactly "foo". |
| `subject(pattern)` | first line (without newline) matches |
| `author(pattern)` | author name or email matches (= `author_name(p) \| author_email(p)`) |
| `author_name(pattern)`, `author_email(pattern)` | that field matches |
| `author_date(datepattern)` | author date matches |
| `committer(pattern)`, `committer_name(…)`, `committer_email(…)`, `committer_date(…)` | committer fields match |
| `mine()` | author email equals `user.email` (case-insensitive) |
| `signed()` | commit is cryptographically signed |
| `empty()` | changes nothing (includes clean merges and the root) |
| `files(fileset)` | changes touch matching paths. Paths are cwd-relative; a directory matches recursively. Quote `.` as `files(".")`. |
| `diff_lines(text, [fileset])` | diff has a changed line matching `text` (Git's `log -G`: `diff_lines(regex:x)`) |
| `diff_lines_added(text, [fileset])`, `diff_lines_removed(…)` | only added, or only removed, lines match |
| `conflicts()` | tree contains conflicted files |
| `divergent()` | change is divergent |

Filters are evaluated commit by commit. Without a bounding set they scan every visible commit, so intersect them with a range on large repos: `trunk()..@ & conflicts()`.

### Control

| Function | Result |
| --- | --- |
| `present(x)` | `x`, or `none()` if a symbol in `x` does not resolve |
| `coalesce(x, y, …)` | The first argument that is not empty |
| `at_operation(op, x)` | `x` evaluated at an operation (`at_operation(@-, visible_heads())`). Brings that operation's visible commits into the search space. Works with sibling operations since 0.46. |

## String patterns

Used by functions that match text (`description`, `author`, `bookmarks`, …) and by name arguments on the CLI.

| Kind | Matches |
| --- | --- |
| *(none)* | Same as `glob:` |
| `exact:"s"` | The whole string, exactly |
| `glob:"p"` | The whole string against a Unix-style glob (globset syntax) |
| `substring:"s"` | Strings containing `s` |
| `regex:"p"` | Strings containing a match of the regular expression (regex crate syntax) |

- A bare pattern is a **glob**, so it must match the whole string: `description(fix)` matches only a description that is exactly `fix`. Use `description(*fix*)` or `description(substring:fix)` for "contains".
- Descriptions end with a newline, so a whole-string pattern without a wildcard matches nothing: `description("Add parser")` and `description(exact:"Add parser")` both fail for a commit described `Add parser` (*verified*). Use `subject("Add parser")`, which matches the first line without its newline.
- Append `-i` for case-insensitive matching: `glob-i:"fix*"`, `substring-i:"error"`, `exact-i:…`.
- Quotes are optional when the pattern has no special characters.
- Patterns combine with `~x`, `x & y`, `x ~ y`, `x | y`: `bookmarks(~glob:"ci/*")`.

## Date patterns

| Kind | Matches |
| --- | --- |
| `after:"d"` | At or after `d` |
| `before:"d"` | Before `d` (exclusive) |

Accepted forms include `2024-02-01`, `2024-02-01T12:00:00`, `2024-02-01T12:00:00-08:00`, `2024-02-01 12:00:00`, `2 days ago`, `5 minutes ago`, `yesterday`, `yesterday 5pm`, `yesterday 15:30`.

## Aliases

Defined in `[revset-aliases]`. Symbols, functions (overloadable by arity), and `name:x` patterns can be defined. An alias shadows a built-in function of the same name. Aliases expand like macros: an argument used twice is evaluated twice.

```toml
[revset-aliases]
HEAD = '@-'
'user(x)' = 'author(x) | committer(x)'
'grep:x' = 'description(regex:x)'
stack = { definition = 'reachable(@, mutable())', doc = 'The current stack' }  # doc shows in completions
```

### Built-in aliases

| Alias | Definition |
| --- | --- |
| `trunk()` | The default remote's default bookmark, set per repo at init or clone. Fallback: the newest of `main`, `master`, `trunk` on `upstream` or `origin`; otherwise `root()`. An override must resolve to exactly one commit. |
| `builtin_log()` | `present(@) \| ancestors(immutable_heads().., 2) \| trunk()` (the default `revsets.log`) |
| `builtin_immutable_heads()` | `trunk() \| tags() \| untracked_remote_bookmarks() \| untracked_remote_tags()` |
| `immutable_heads()` | `builtin_immutable_heads()`; redefine this to change immutability |
| `immutable()` | `::(immutable_heads() \| root())` |
| `mutable()` | `~immutable()` |
| `visible()` | `::visible_heads()` |
| `hidden()` | `~visible()`; empty unless hidden commits are named |

The full set is in `cli/src/config/revsets.toml` in the jj source.

## Revset settings

| Key | Default | Used by |
| --- | --- | --- |
| `revsets.log` | `builtin_log()` | `jj log` without `-r` or paths |
| `revsets.short-prefixes` | value of `revsets.log` | Shortest unique ID prefixes |
| `revsets.log-graph-prioritize` | `present(@)` | Revisions drawn in the leftmost column |
| `revsets.arrange`, `revsets.fix`, `revsets.run`, `revsets.sign`, `revsets.simplify-parents` | `reachable(@, mutable())` | Defaults for those commands |
| `revsets.converge` | `mutable() & divergent()` | `jj converge` |
| `revsets.git-push` | `remote_bookmarks(remote=exact:remote)..@` | `jj git push` with no targets |
| `revsets.bookmark-advance-to` | `@` | `jj bookmark advance` |
| `revsets.bookmark-advance-from` | `heads(::to & bookmarks())` | `jj bookmark advance` |
| `revsets.op-diff-changes-in` | `mutable() \| immutable_heads()` | `jj op show/diff/log -p` |

## Examples

| Goal | Revset |
| --- | --- |
| Parent of the working copy | `@-` |
| Everything `git log` shows | `..` or `::@` |
| Work not on any remote | `remote_bookmarks()..` |
| Work not on `origin` | `remote_bookmarks(remote=origin)..` |
| Unpushed ancestors of `@` | `remote_bookmarks()..@` |
| Local work plus descendants | `(remote_bookmarks()..@)::` |
| The current stack | `reachable(@, mutable())` |
| Most recent non-empty ancestor | `heads(::@ ~ empty())` |
| Git's root commits | `root()+` |
| Like `--simplify-by-decoration` | `tags() \| bookmarks()` |
| My unpushed bookmarks | `mine() & bookmarks() & ~remote_bookmarks()` |
| Commits mentioning "reset" by a user | `author(*martinvonz*) & description(*reset*)` |
| Show elided revisions between two | `connected(x \| y)` |
