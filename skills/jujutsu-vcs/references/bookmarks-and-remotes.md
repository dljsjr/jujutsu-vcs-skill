# Bookmarks, tags, and remotes

Run `jj help -k bookmarks` for help on the installed version.

## Bookmarks

- A bookmark is a named pointer to a commit. It maps to a Git branch of the same name.
- Bookmarks **follow rewrites**: when the commit is rewritten (rebase, describe, squash), the bookmark moves to the new commit. When the commit is abandoned, the bookmark is deleted (unless `jj abandon --retain-bookmarks`).
- Bookmarks **do not advance** when commits are created on top. There is no current or active bookmark. Move them with `jj bookmark move`, `set`, or `advance`.
- A bookmark name resolves as a revision; it has lower priority than a tag of the same name. See [revsets.md](revsets.md#symbols).

### Commands

| Command | Effect |
| --- | --- |
| `jj bookmark create NAMES [-r REV]` | Create (default `@`; `--to` is an alias for `-r`) |
| `jj bookmark set NAMES [-r REV] [-B]` | Create or move by name; `-B/--allow-backwards` permits backward or sideways moves |
| `jj bookmark move NAMES\|--from REVS [--to REV] [-B]` | Move existing bookmarks only (default `--to @`) |
| `jj bookmark advance [NAMES] [--to REV]` | Move the closest bookmarks forward to a target (defaults: `revsets.bookmark-advance-from` = `heads(::to & bookmarks())`, `revsets.bookmark-advance-to` = `@`) |
| `jj bookmark rename OLD NEW [--overwrite-existing]` | Rename |
| `jj bookmark delete NAMES` | Delete; the deletion is pushed to tracked remotes on the next push |
| `jj bookmark forget NAMES [--include-remotes]` | Delete locally without recording a deletion to push; corresponding remote bookmarks become untracked |
| `jj bookmark list [NAMES]` | List. `-a/--all-remotes`, `--remote R`, `-t/--tracked`, `-c/--conflicted`, `-r REVSETS`, `-T`, `--sort` |
| `jj bookmark track NAME[@REMOTE]… [--remote R]` | Start tracking remote bookmarks |
| `jj bookmark untrack NAME[@REMOTE]… [--remote R]` | Stop tracking |

Name arguments other than `create`, `set`, and `rename` are glob patterns. Deleting a bookmark does not abandon its commits; `jj abandon main..<bookmark>` does.

### Log decorations

| Shown as | Meaning |
| --- | --- |
| `name` | Local bookmark |
| `name@remote` | Remote bookmark at a different position from the local one |
| `name*` | The local bookmark differs from a tracked remote; it may need pushing |
| `name??` | Conflicted bookmark (shown on each candidate target) |
| `name@git` | Git-tracking bookmark in a colocated repo, shown when it disagrees (for example while conflicted) |

## Remote bookmarks and tracking

- `name@remote` records the bookmark's last-seen position on a remote. It updates on fetch and when that bookmark is pushed. It cannot be edited directly.
- A **tracked** remote bookmark is associated with the local bookmark of the same name. Fetching merges remote changes into the local bookmark (creating it if needed). Pushing updates the remote from the local bookmark. A local bookmark may track the same name on several remotes; names must match.
- An **untracked** remote bookmark is only a pointer to the last fetched position. It is not imported as a local bookmark. Untracked remote bookmarks are immutable by default (part of `builtin_immutable_heads()`).
- Fetch merge rule: if only one side (local or remote) moved, it wins. If both moved and neither is an ancestor of the other, the local bookmark becomes conflicted.

### Automatic tracking

| When | Tracked automatically |
| --- | --- |
| `jj git clone` | The default branch (unless `git.track-default-bookmark-on-clone = false`) |
| `jj git push` of a new bookmark | The newly created remote bookmark |
| `jj git push -c` / `--named` | The generated or named bookmark |
| Fetch or local creation, with `remotes.<remote>.auto-track-bookmarks = "<pattern>"` | New bookmarks whose names match |
| Local creation, with `remotes.<remote>.auto-track-created-bookmarks = "<pattern>"` | Bookmarks created with `create`/`set` |

Other fetched bookmarks arrive untracked. Bookmarks that existed before an auto-track setting was added are not affected by it.

## Tags

- A tag is a named pointer that does not follow rewrites. jj creates lightweight tags; annotated tags from Git can be read and checked out.
- Remote tags are fetched as `name@remote`, like bookmarks, and are tracked by same-name local tags by default. Tracked tags are pushed.

| Command | Effect |
| --- | --- |
| `jj tag set NAMES [-r REV] [--allow-move]` | Create, or move with `--allow-move` |
| `jj tag delete NAMES` | Delete (commits are kept) |
| `jj tag list [NAMES]` | `-a`, `--remote`, `-t`, `-c`, `-r` (`-r 'R::'` = Git's `--contains R`; `-r '::R'` = `--merged R`), `-T`, `--sort` |
| `jj tag track` / `jj tag untrack NAME[@REMOTE]…` | As for bookmarks |

## Remotes

| Command | Effect |
| --- | --- |
| `jj git remote add NAME URL [--push-url URL]` | Add (local paths become absolute) |
| `jj git remote list` | List |
| `jj git remote remove NAME` | Remove, forgetting its bookmarks (also updates the `trunk()` alias) |
| `jj git remote rename OLD NEW` | Rename (also updates `trunk()`) |
| `jj git remote set-url NAME [URL] [--fetch URL] [--push URL]` | Change URLs |

## Fetching

`jj git fetch` downloads from remotes and imports their bookmarks and tags.

| Option | Effect |
| --- | --- |
| *(default remotes)* | `git.fetch`; if unset, the only remote, or `origin` |
| `--remote PATTERN` (repeatable), `--all-remotes` | Choose remotes |
| *(default refs)* | `remotes.<name>.fetch-bookmarks` / `fetch-tags`; if `fetch-bookmarks` is unset, the remote's Git fetch refspecs |
| `-b/--branch PATTERN`, `-t/--tag PATTERN` (repeatable) | Only these refs (glob with `*` only; `\|` and `~` allowed) |
| `--tracked` | Only already-tracked bookmarks and tags |

- Commits no longer reachable from any remote branch are abandoned locally (`git.abandon-unreachable-commits`).
- Fetch rebuilds evolution history from change IDs: if the remote rewrote commits, local descendants are rebased onto the rewritten versions (immutable descendants are not).
- To stop fetching tags from a remote: `remotes.<name>.fetch-tags = '~*'`.

There is no `pull`. Fetch, then rebase: `jj git fetch && jj rebase -o trunk()` (default `-b @`; give `-b` once per branch to rebase several).

## Pushing

`jj git push` updates remote bookmarks and tags from local ones.

### What is pushed

| Option | Pushes |
| --- | --- |
| *(none)* | Tracked bookmarks and tags pointing into `revsets.git-push` (default `remote_bookmarks(remote=exact:remote)..@`) |
| `-b/--bookmark PATTERN` | Matching bookmarks (tracking them if new) |
| `-t/--tag PATTERN` | Matching tags |
| `-r/--revision REVSETS` | Bookmarks and tags on those commits |
| `-c/--change REVSETS` | A new bookmark per commit, named by `templates.git_push_bookmark` (default `push-<change_id.short()>`) |
| `--named NAME=REV` | A new bookmark `NAME` at `REV` |
| `--all` | Every bookmark and tag, including new ones |
| `--tracked` | Every tracked bookmark and tag |
| `--deleted` | Deletions of tracked bookmarks and tags |

- A push sends every commit from the remote's current position up to the ref's target. Descendants beyond the ref are not pushed.
- Remotes: `--remote PATTERN` (repeatable) or `git.push`; otherwise the only remote, or `origin`. The remote is not inferred from tracking. Several remotes may be pushed in one command.
- `--dry-run`, `-o/--option` (Git push options; repeatable).
- `--all`, `--tracked`, and `-r` skip bookmarks that are not eligible (private or conflicted) instead of failing.

### Refusals and overrides

| Refused when the commits to push... | Override |
| --- | --- |
| have empty descriptions | `--allow-empty-description` |
| are in `git.private-commits`, or descend from such a commit | `--allow-private` |
| contain conflicts | `--allow-conflicts` |

Commits already on the remote and immutable commits are never private.

### Safety checks

Before moving, creating, or deleting a remote bookmark:

1. The remote's actual position must match jj's record (like `git push --force-with-lease`). It is also accepted when the unexpected position would not cause a conflict on fetch, for example when it equals the local target.
2. The local bookmark must not be conflicted.
3. A bookmark that already exists on the remote must be tracked.

On failure, run `jj git fetch --remote <remote>`, resolve any bookmark conflict, and push again. Because fetch turns a problematic remote move into a local conflict, push stays safe even when fetch runs in the background.

Rewritten commits are force-pushed automatically, subject to these checks.

## Conflicted bookmarks

- A local bookmark becomes conflicted when it moved both locally and on a remote, or when concurrent operations moved it differently. A remote bookmark (`main@origin`) can be conflicted after concurrent operations.
- `jj status` reports conflicted bookmarks; `jj bookmark list -c` lists them with `-`/`+` old and new targets.
- A conflicted name resolves to every candidate, so commands that need one revision fail with "resolved to multiple revisions".
- Resolve a local bookmark with `jj bookmark move NAME --to REV`, optionally after merging (`jj new NAME`) or rebasing one side onto the other. Resolve a remote bookmark by fetching from that remote.

## Forges

- **GitHub/GitLab:** push one bookmark per pull request. `jj git push -c @-` creates and pushes a generated bookmark; `jj git push --named NAME=@-` a named one. Re-pushing a rewritten stack force-pushes; `jj git push -r 'trunk()..@'` updates every bookmark on the current stack. GitLab merge requests can be created with push options: `-o merge_request.create -o merge_request.target=main`.
- **`gh` in a non-colocated repo:** set `GIT_DIR=$(jj git root)`.
- **Gerrit:** `jj gerrit upload [-r REVSETS]` pushes each revision and its mutable ancestors as Gerrit changes (default: `@` if it has a description, else `@-`). Change-Ids come from jj change IDs unless a `Change-Id:` trailer is present; the generated trailer is added only to the uploaded commit, which can produce divergence after the change is fetched back (fix with `jj rebase --skip-emptied` or by adding trailers locally with `templates.commit_trailers`). Remote: `--remote`, `gerrit.default-remote`, or a remote named `gerrit`. Branch: `-b`, `gerrit.default-remote-branch`. `--dry-run`, reviewers, labels, topics, hashtags, WIP and private flags are available; see `jj gerrit upload --help`.

## Multiple remotes

| Setup | Configuration |
| --- | --- |
| Contributing through a fork (`origin` = fork, `upstream` = canonical) | `git.fetch = ["upstream", "origin"]`, `git.push = "origin"`, `jj bookmark track main` (tracks it on both remotes), `revset-aliases."trunk()" = "main@upstream"` |
| Independent repo that pulls from upstream | `git.fetch = ["origin"]` (or both), `git.push = "origin"`, track `main` on `origin` only, `revset-aliases."trunk()" = "main@origin"` |
| Auto-track all of `origin`, only `main` of `upstream` | `remotes.origin.auto-track-bookmarks = "*"`, `remotes.upstream.auto-track-bookmarks = "main"` |

`trunk()` should be the remote bookmark you rebase onto; it also anchors the immutable set.
