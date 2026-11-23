# Reshaping history

Turn work that landed in the wrong shape, usually one large change, into a series of reviewable commits after the fact. Every jj command works on any commit, not only `@`, and descendants follow each rewrite automatically, so commits can be split, merged, moved, and reordered anywhere in the stack.

Use it for requests such as "clean this up before I open a pull request" or "split this into separate pull requests". To build a stack deliberately from the start, see [stacked-changes.md](stacked-changes.md).

Commands below use `trunk()`. In a repo with no remote it resolves to `root()`; use the trunk bookmark's name instead, such as `main`.

## Record the starting point

Before reshaping, note the commit ID at the top of the work. Reshaping should change how the edits are divided, not the final result:

```sh
jj log -G -r 'heads(trunk()..@ ~ empty())' -T commit_id
```

The old commit stays addressable by that ID after it is rewritten. If anything goes wrong, `jj undo` or `jj op restore` takes the repo back.

## Split

`jj split -r REV PATHS -m "msg"` puts PATHS into a first commit with message `msg`, and leaves the rest in a second commit on top that keeps the original message. The first commit keeps REV's change ID; the remainder gets a new one, which the command prints as `Remaining changes:`. Split that remainder to cut off the next piece:

```sh
jj split -r BIG src/parser.py tests/test_parser.py -m "Add the config parser"
# Remaining changes: REST ...
jj split -r REST src/cli.py -m "Use the parser in the CLI"
# Remaining changes: REST2 ...
jj describe REST2 -m "Document the config file"
```

Splitting edits within one file needs a diff editor; script one as [automation.md](../references/automation.md#scripted-diff-editor) shows, rather than running `jj split` without PATHS, which opens a terminal UI.

## Move, combine, reorder

| Goal | Command |
| --- | --- |
| Move some files' edits from one commit to another | `jj squash --from X --into Y PATHS`, adding `-u` to keep Y's message when both have one |
| Combine two commits | `jj squash --from X --into Y -u`; X is abandoned once empty |
| Put C before B | `jj rebase -r C -B B` (`-A` for after) |
| Fold fixes into the commits that introduced the lines | `jj absorb` from a change on top |
| Reword any commit | `jj describe REV -m "msg"` |

## Make changes independent

`jj parallelize FIRST::LAST` turns a line of commits into siblings that share the original parent, so each can become its own pull request. Commits above them become merges of the siblings. A commit that depends on an earlier one's edits becomes conflicted; parallelize only the ones that are independent, or reorder first.

## Check the result

1. Compare the final content with the starting point; the output should be empty: `jj diff --from OLD_TOP --to 'heads(trunk()..@ ~ empty())' --summary`.
2. Check each commit's contents and look for conflicts: `jj log -r 'trunk()..@' --summary`.
3. Optionally build or test every commit: `jj run --ignore-changes -r 'trunk()..@ ~ empty()' -- TEST_COMMAND`. Each revision runs in its own checkout under `.jj/run/` with only tracked files, so ignored files such as installed dependencies are absent.
