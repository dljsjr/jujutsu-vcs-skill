# The squash workflow

Describe the change you are aiming for first, then work in a scratch change on top of it, and move edits down into it with `jj squash` as each one proves right. The scratch change is a real commit: it can be diffed, tested, partly kept, or thrown away, while the described change below holds only what was accepted.

Use it for iterative work where it matters to see exactly what is new before keeping it, such as an edit-and-test loop. For straightforward work, edit in `@` and `jj commit`.

## Start

```sh
jj describe -m "Add retry to fetch()"   # on new work in @, or: jj new REV -m "..."
jj new                                  # the scratch change, on top
```

The described change is `@-`. Its message states the goal; refine it with `jj describe @- -m "msg"` as the work takes shape.

## Iterate

| Step | Command |
| --- | --- |
| See what the scratch change adds | `jj diff` |
| See what has been accepted so far | `jj diff -r @-` |
| Keep everything in scratch | `jj squash` |
| Keep some files | `jj squash PATHS` |
| Throw away scratch edits | `jj restore [PATHS]` |
| Keep scratch edits for a different change | `jj squash --into REV PATHS` |

The scratch change has no description, so `jj squash` never asks for a combined message. After each squash, `@` is an empty scratch change again, ready for the next attempt.

For an experiment that may fail, the scratch change is already the safety net: test it, then keep it with `jj squash` or drop it with `jj restore`.

## Finish

When the goal is met, `@` is an empty change on top of the described one, which is the normal resting state. Check `jj diff -r @-` for the final edits; push or continue from there.
