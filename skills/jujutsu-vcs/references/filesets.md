# Fileset language

A fileset is an expression that selects files. Commands take filesets as positional path arguments, and some revset and template functions take them as arguments (`files()`, `diff_lines()`, `Commit.diff()`).

## Quoting

- A path containing whitespace or metacharacters must be quoted inside the expression, unless the whole expression is a single path with no operators or function calls.
- Glob characters are not metacharacters, but the shell still needs quoting.

| Command | Quoting |
| --- | --- |
| `jj diff 'Foo Bar'` | Shell quotes required; inner quotes optional |
| `jj diff '~"Foo Bar"'` | Both required |
| `jj diff '"Foo(1)"'` | Both required |
| `jj diff '~glob:**/*.rs'` | Shell quotes required |

## Patterns

A bare `"path"` is parsed as `prefix-glob:`: a cwd-relative path prefix, with glob characters expanded.

| Pattern | Matches |
| --- | --- |
| `cwd:"path"` | The cwd-relative path and everything under it |
| `file:"path"`, `cwd-file:"path"` | Exactly that cwd-relative file |
| `glob:"pattern"`, `cwd-glob:"pattern"` | Paths matching the glob, relative to cwd. `glob:"*.c"` is not recursive. |
| `prefix-glob:"pattern"`, `cwd-prefix-glob:"pattern"` | Glob matches and everything under matching directories. `prefix-glob:"*.d"` = `glob:"*.d" \| glob:"*.d/**"`. |
| `root:"path"` | The workspace-relative path and everything under it |
| `root-file:"path"` | Exactly that workspace-relative file |
| `root-glob:"pattern"` | Glob relative to the workspace root |
| `root-prefix-glob:"pattern"` | Prefix glob relative to the workspace root |

Append `-i` to glob kinds for case-insensitive matching: `glob-i:"*.TXT"`. Glob syntax follows the globset crate.

## Operators

From tightest to loosest. Infix operators of equal binding associate left to right.

| Level | Operator | Meaning |
| --- | --- | --- |
| 1 | `f(x)` | Function call |
| 2 | `p:x` | Pattern or pattern alias |
| 3 | `~x` | Everything but `x` |
| 4 | `x & y`, `x ~ y` | Both; `x` but not `y` |
| 5 | `x \| y` | Either |

## Functions

| Function | Matches |
| --- | --- |
| `all()` | Everything |
| `none()` | Nothing |

## Aliases

Defined in `[fileset-aliases]`. Symbols, functions (overloadable by arity), and `name:x` patterns can be defined. An alias shadows a built-in with the same name.

```toml
[fileset-aliases]
LOCK = '**/Cargo.lock | **/package-lock.json | **/uv.lock'
'not:x' = '~x'
```

The `{ definition = '…', doc = '…' }` form adds a description shown in shell completions.

## Examples

| Goal | Command |
| --- | --- |
| Diff without `Cargo.lock` | `jj diff '~Cargo.lock'` |
| Files in `src` that are not Rust | `jj file list 'src ~ glob:"**/*.rs"'` |
| Split so that `foo` goes into the second commit | `jj split '~foo'` |
| Commits touching any lockfile | `jj log -r 'files(LOCK)'` (with the alias above) |

## Settings that take filesets

| Key | Default | Meaning |
| --- | --- | --- |
| `snapshot.auto-track` | `all()` | New files that are tracked automatically |
| `fix.tools.<name>.patterns` | (none) | Files a fix tool applies to (list of filesets) |
