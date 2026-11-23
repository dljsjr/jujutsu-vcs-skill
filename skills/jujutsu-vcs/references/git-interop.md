# Git interoperability

The Git backend stores jj data in Git's format. In a colocated repository, jj and Git share a working copy. Remotes, fetching, and pushing are in [bookmarks-and-remotes.md](bookmarks-and-remotes.md).

## Creating repos

| Situation | Command |
| --- | --- |
| New repo | `jj git init [DEST]` (colocated unless `git.colocate = false` or `--no-colocate`) |
| Existing Git checkout, in place | `jj git init` in its root (colocated) |
| Existing Git repo, separate jj working copy | `jj git init --git-repo=PATH DEST` (not colocated; sync with `jj git import`/`export`) |
| Bare Git repo as backing store | `jj git init --git-repo=PATH` |
| Clone | `jj git clone URL [DEST]`. `--remote NAME` (default `origin`), `--colocate`/`--no-colocate`, `--depth N`, `-b PATTERN`, `-t PATTERN`, `--object-hash sha1\|sha256` |

Cloning sets the `trunk()` alias for the repo to the remote's default branch and tracks that branch. There is no native jj repo format for cloning; all remotes are Git.

## Colocation

| | Colocated (default) | Not colocated |
| --- | --- | --- |
| Layout | `.git/` and `.jj/` side by side | Git repo inside `.jj/repo/store/git` |
| `git` commands in the working copy | Work | Do not work (`GIT_DIR=$(jj git root)` for tools) |
| Sync between jj and Git | Automatic on every jj command | `jj git import` / `jj git export` |

- In a colocated repo, Git is in **detached HEAD** at the parent of `@`. Run `git switch <branch>` before mutating Git commands that need a current branch.
- Changes made by `git` appear in `jj op log` as `import git refs` operations and can be undone with `jj undo` or `jj op restore`.
- `jj git import` and `jj git export` do nothing in colocated repos unless given `--ignore-working-copy`.
- Convert with `jj git colocation enable|disable|status`. These also work in child workspaces, where `enable` creates a Git worktree and `disable` removes it. See [workspaces.md](workspaces.md#colocated-workspaces).

### Colocation caveats

- Interleaving mutating `git` and `jj` commands can produce bookmark conflicts or divergent changes. Background `git fetch` by IDEs is a common cause.
- With very many refs, the automatic import slows every command; `jj util gc` packs refs.
- Git tools see conflicted commits in their stored form (`.jjconflict-*` directories).
- jj ignores Git's index, Git-style conflict states, and an unfinished `git rebase`.
- A conflicted jj bookmark appears in Git at one position, and jj shows the Git side as `name@git`.

## Compatibility

| Git feature | Support |
| --- | --- |
| Remotes, authentication | Yes. Remote operations run `git` as a subprocess (`git.executable-path`). |
| Git config | Only `[remote "<name>"]` sections (simple fetch refspecs) and `core.excludesFile` are read |
| Branches | Yes, as bookmarks |
| Tags | Lightweight tags can be created; annotated and lightweight tags can be read and checked out |
| `.gitignore`, `.git/info/exclude`, `core.excludesFile` | Yes (native implementation) |
| `.gitattributes` | No; `working-copy.eol-conversion` replaces `core.autocrlf` |
| Hooks | No (no pre-commit or commit-msg hooks run) |
| Merge commits, octopus merges | Yes |
| Detached HEAD, orphan branches | Natural (anonymous branches; the virtual root commit) |
| Staging area | Ignored |
| `git gc` | Probably safe but untested; back up first |
| Bare repositories | Yes (`--git-repo`) |
| Submodules | No. Submodules are not shown in the working copy but are not lost. |
| Partial clones | No |
| Shallow clones | Partly: shallow commits get the root as parent; deepening is not supported |
| Worktrees | jj workspaces; colocated workspaces create Git worktrees |
| Sparse checkout | jj's own `jj sparse` |
| Signed commits | Yes (see [config.md](config.md#signing)) |
| Git LFS | No |
| SHA-256 repositories | Yes, chosen at init (`git.object-hash`) |

## Data mapping

| jj data | In Git |
| --- | --- |
| Commit | A Git commit; the commit ID is the Git commit ID |
| Change ID | A non-standard `change-id` commit header (reverse hex). Written by default (`git.write-change-id-header`). Preserved by `git commit --amend` and most forges, dropped by `git rebase`. Not shown by `git log`/`git show`; visible with `git cat-file -p <commit>`. |
| Commit created by `git` | No change ID header; jj derives its change ID by bit-reversing the commit ID |
| Predecessors (evolution history) | Not in Git; stored in `.jj/repo/store/extra/` |
| Commits referenced by the op log | Kept alive with refs under `refs/jj/keep/*` |
| Conflicted commit | A tree with `.jjconflict-base-*/` and `.jjconflict-side-*/` directories; the real conflict is in a `jj:trees` header |
| Bookmark | Branch `refs/heads/<name>` (colocated) and `refs/remotes/<remote>/<name>` |
| Working-copy commit | Not a Git ref; Git HEAD points to `@-` |

- Paths are assumed to be UTF-8.
- Two commits that differ only in change ID would have the same Git commit ID; jj refuses to write the second.
- `git log --all` in a jj repo also shows commits kept by `refs/jj/*`; exclude them with `git log --exclude 'refs/jj/*' --all`.

## Equivalent commands

Condensed from the official [Git command table](https://docs.jj-vcs.dev/latest/git-command-table/). Every jj command can act on any commit, not only the working copy: `jj squash -r R` moves R's diff into its parent, `jj describe R` rewords R, and so on.

| Git | jj |
| --- | --- |
| `git status` | `jj st` |
| `git diff HEAD` | `jj diff` |
| `git diff R^ R` | `jj diff -r R` |
| `git diff R` | `jj diff --from R` |
| `git diff A B` | `jj diff --from A --to B` |
| `git diff A...B` | `jj diff -r A..B` |
| `git show R` | `jj show R` |
| `git add`, `git rm` | Nothing (files are tracked automatically); `rm` to delete |
| `git rm --cached F` | `jj file untrack F` (F must be ignored) |
| `git commit -a` | `jj commit` |
| `git commit -p` | `jj split` |
| `git commit --amend -a` | `jj squash` |
| `git add -p; git commit --amend` | `jj squash -i` |
| `git commit --fixup=X; git rebase --autosquash X^` | `jj squash --into X` |
| `git commit --amend --only` (reword) | `jj describe @-` |
| Reword any commit | `jj describe X` |
| Reword the working-copy commit (no Git equivalent) | `jj describe` |
| Move part of any commit into any other (no Git equivalent) | `jj squash -i --from X --into Y` |
| Split or edit an older commit (`git rebase -i`, "edit") | `jj split -r R`, `jj diffedit -r R` |
| `git reset --hard` | `jj abandon` (new change) or `jj restore` (empty the current change); both undoable |
| `git reset --soft HEAD~` | `jj squash --from @-` |
| `git restore PATHS` | `jj restore PATHS` |
| `git stash` | `jj new @-` (the old change stays as a sibling; return with `jj edit`) |
| `git switch -c topic main` | `jj new main` (bookmark optional) |
| `git checkout v1.0` | `jj new v1.0` |
| `git merge A` | `jj new @ A` |
| `git rebase B A` | `jj rebase -b A -o B` |
| `git rebase --onto B A^ <tip>` | `jj rebase -s A -o B` |
| Reorder A-B-C-D to A-C-B-D | `jj rebase -r C -B B` (`jj arrange` for many) |
| `git rebase/merge --continue` | Not needed: edit the conflict, then `jj squash` |
| `git cherry-pick S` onto D | `jj duplicate S -o D` |
| `git revert R` | `jj revert -r R -B @` |
| `git log --oneline --graph` | `jj log -r ::@` |
| `git log --all` | `jj log -r ::` |
| `git log --graph --branches --not upstream/main` | `jj log` (the default view shows work not yet on trunk) |
| `git log -G text` | `jj log -r 'diff_lines(regex:text)'` |
| `git ls-files` | `jj file list` |
| `git grep foo` | `jj file search --pattern foo` |
| `git blame F` | `jj file annotate F` |
| `git rev-parse --show-toplevel` | `jj root` |
| `git branch` | `jj bookmark list` |
| `git branch N R` | `jj bookmark create N -r R` |
| `git branch -f N R` | `jj bookmark move N --to R` (`--allow-backwards` for backward moves) |
| `git branch -d N` | `jj bookmark delete N` |
| `git tag N R` | `jj tag set N -r R` |
| `git tag --contains R` | `jj tag list -r 'R::'` |
| `git tag --merged R` | `jj tag list -r '::R'` |
| `git tag -l`, `git tag -d N` | `jj tag list`, `jj tag delete N` |
| `git fetch` | `jj git fetch` |
| `git pull` | `jj git fetch`, then `jj rebase -o trunk()` |
| `git push R B` | `jj git push --bookmark B --remote R` |
| `git push --all` | `jj git push --all` |
| `git reflog` | `jj op log` (whole-repo history) and `jj evolog` (one change) |
| Undo the last command (no Git equivalent) | `jj undo` (`jj redo` reverses it); `jj op revert OP` for an earlier one |
