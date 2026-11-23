#!/usr/bin/env python3
"""Record fixture state and run read-only checks for the jujutsu-vcs evals.

  jjcheck.py record CASE RUN_DIR            write RUN_DIR/fixture-state.json
  jjcheck.py check CASE ASSERTION RUN_DIR   print evidence; exit 0 pass, 1 fail

The repository under test is RUN_DIR/work/app. Every jj call uses
--ignore-working-copy and an empty JJ_CONFIG, so checks never snapshot the
working copy or depend on the operator's configuration. Files on disk are read
directly. Exit 2 means the check itself could not run.
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ENV = {**os.environ, "JJ_CONFIG": "", "JJ_USER": "Checker", "JJ_EMAIL": "checker@example.com"}
CACHE_PARTS = ("__pycache__",)


class CheckError(Exception):
    pass


def jj(repo, *args):
    proc = subprocess.run(
        ["jj", "--ignore-working-copy", "--no-pager", "--color=never", *args],
        cwd=repo, env=ENV, capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise CheckError(f"jj {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout


def one(repo, revset, template):
    out = jj(repo, "log", "--no-graph", "-r", revset, "-T", template + ' ++ "\\n"')
    lines = [line for line in out.splitlines() if line]
    if len(lines) != 1:
        raise CheckError(f"revset {revset!r} resolved to {len(lines)} commits")
    return lines[0]


def many(repo, revset, template):
    out = jj(repo, "log", "--no-graph", "-r", revset, "-T", template + ' ++ "\\n"')
    return [line for line in out.splitlines() if line]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def disk_sha(path):
    return sha(Path(path).read_bytes()) if Path(path).exists() else None


def is_cache(path):
    return any(part in CACHE_PARTS for part in path.split("/")) or path.endswith(".pyc")


def file_show(repo, rev, path):
    proc = subprocess.run(
        ["jj", "--ignore-working-copy", "--no-pager", "file", "show", "-r", rev, f'root-file:"{path}"'],
        cwd=repo, env=ENV, capture_output=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def fingerprint(repo, rev):
    paths = [p for p in jj(repo, "file", "list", "-r", rev).splitlines() if p and not is_cache(p)]
    return {p: sha(file_show(repo, rev, p) or b"") for p in sorted(paths)}


def changed_paths(repo, rev):
    out = jj(repo, "diff", "-r", rev, "--name-only")
    return sorted(p for p in out.splitlines() if p and not is_cache(p))


def commit_of(repo, rev):
    return one(repo, rev, "commit_id")


def change_of(repo, rev):
    return one(repo, rev, "change_id")


def parents_of(repo, rev):
    return one(repo, rev, 'parents.map(|c| c.commit_id()).join(",")').split(",")


def subject(repo, rev):
    return one(repo, rev, "description.first_line()")


# ---------------------------------------------------------------- recording

def record(case, run_dir):
    repo = run_dir / "work" / "app"
    state = {"case": case}
    if case == "squash-described":
        state["main"] = commit_of(repo, "main")
        state["retry_change"] = change_of(repo, 'subject(exact:"Add retry logic to fetch()")')
        state["fixup_change"] = change_of(repo, 'subject(glob:"fixup:*")')
        state["final_client_sha"] = sha(file_show(repo, 'subject(glob:"fixup:*")', "src/client.py"))
    elif case == "try-and-undo":
        state["main"] = commit_of(repo, "main")
        stack = many(repo, "::feature ~ ::main", "change_id")  # newest first
        state["feature_changes"] = stack
        state["feature_commits"] = many(repo, "::feature ~ ::main", "commit_id")
        state["feature_parent"] = parents_of(repo, "roots(::feature ~ ::main)")
        state["fingerprints"] = {c: fingerprint(repo, f"change_id({c})") for c in stack}
        state["wc_parent"] = commit_of(repo, "@-")
    elif case == "git-vocabulary":
        state["main"] = commit_of(repo, "main")
        state["wip_app_sha"] = disk_sha(repo / "src" / "app.py")
    elif case == "others-changes":
        state["main"] = commit_of(repo, "main")
        state["readme_sha"] = disk_sha(repo / "README.md")
        state["config_sha"] = disk_sha(repo / "src" / "config.py")
    elif case == "rebase-conflict":
        state["feature_changes"] = many(repo, "::feature ~ ::main", "change_id")  # newest first
        state["readme_sha"] = disk_sha(repo / "README.md")
        origin = run_dir / "work" / "origin.git"
        state["origin_main"] = git_ref(origin, "refs/heads/main")
    else:
        raise CheckError(f"unknown case {case}")
    (run_dir / "fixture-state.json").write_text(json.dumps(state, indent=2) + "\n")
    return state


def git_ref(bare, ref):
    proc = subprocess.run(["git", "--git-dir", str(bare), "rev-parse", "--verify", "--quiet", ref],
                          capture_output=True, text=True)
    return proc.stdout.strip() or None


# ------------------------------------------------------------------ checks

def described_new(repo, main):
    """Non-empty commits after main, newest first, as (change, commit, subject)."""
    rows = many(repo, f"commit_id({main})..visible_heads() ~ empty()",
                'change_id ++ "\\t" ++ commit_id ++ "\\t" ++ description.first_line()')
    return [tuple(r.split("\t", 2)) for r in rows]


def check(case, assertion, run_dir):
    repo = run_dir / "work" / "app"
    state = json.loads((run_dir / "fixture-state.json").read_text())
    key = f"{case}/{assertion}"

    if key == "squash-described/folded":
        rows = described_new(repo, state["main"])
        rows = [r for r in rows if changed_paths(repo, r[1])]
        fixups = [r for r in rows if r[2].startswith("fixup:")]
        if fixups:
            return False, f"A fixup commit is still visible: {fixups[0][2]!r}."
        if len(rows) != 1:
            return False, f"Expected one non-empty commit after main, found {len(rows)}: {[r[2] for r in rows]}."
        content = file_show(repo, rows[0][1], "src/client.py")
        if content is None or sha(content) != state["final_client_sha"]:
            return False, "The remaining commit's src/client.py differs from the retry+timeout version."
        return True, f"One commit after main ({rows[0][2]!r}); src/client.py matches the folded version; no fixup commit remains."

    if key == "squash-described/message-kept":
        rows = [r for r in described_new(repo, state["main"]) if changed_paths(repo, r[1])]
        if len(rows) != 1:
            return False, f"Expected one non-empty commit after main, found {len(rows)}."
        desc = json.loads(one(repo, f"commit_id({rows[0][1]})", "description.escape_json()"))
        if desc.strip() == "Add retry logic to fetch()":
            return True, "Description is exactly 'Add retry logic to fetch()'."
        return False, f"Description is {desc.strip()!r}."

    if key == "try-and-undo/restored":
        problems = []
        if commit_of(repo, "main") != state["main"]:
            problems.append("main moved")
        stack = many(repo, "::feature ~ ::main", "change_id")
        if stack != state["feature_changes"]:
            problems.append(f"feature stack change IDs are {stack}, expected {state['feature_changes']}")
        else:
            if parents_of(repo, "roots(::feature ~ ::main)") != state["feature_parent"]:
                problems.append("the stack's root has a different parent than before")
            for c in stack:
                if fingerprint(repo, f"change_id({c})") != state["fingerprints"][c]:
                    problems.append(f"contents of change {c[:8]} differ")
        bookmarks = sorted(many(repo, "bookmarks()", 'local_bookmarks.map(|b| b.name()).join(",")'))
        names = sorted({n for row in bookmarks for n in row.split(",") if n})
        if names != ["feature", "main"]:
            problems.append(f"bookmarks are {names}, expected ['feature', 'main']")
        if problems:
            return False, "; ".join(problems) + "."
        same_ids = many(repo, "::feature ~ ::main", "commit_id") == state["feature_commits"]
        return True, ("main and feature are where they started, with the same change IDs, parent and contents"
                      + (" (identical commit IDs)." if same_ids else " (rewritten commits with new commit IDs)."))

    if key == "try-and-undo/working-copy":
        parents = parents_of(repo, "@")
        feature = commit_of(repo, "feature")
        if parents != [feature]:
            return False, f"@'s parent is {parents}, not feature ({feature[:12]})."
        changed = changed_paths(repo, "@")
        if changed:
            return False, f"@ holds changes beyond Python caches: {changed}."
        return True, "@ is an empty change on top of feature (ignoring Python caches)."

    if key == "try-and-undo/rebase-happened":
        ops = jj(repo, "op", "log", "--no-graph", "-T", 'description ++ "\\n"').splitlines()
        rebases = [o for o in ops if o.startswith("rebase")]
        if rebases:
            return True, f"Operation log has {len(rebases)} rebase operation(s), e.g. {rebases[0]!r}."
        return False, "Operation log has no rebase operation."

    if key == "git-vocabulary/typo-commit":
        rows = many(repo, f"commit_id({state['main']})+ & subject(glob-i:\"fix typo in readme*\")",
                    "commit_id")
        if not rows:
            return False, "No commit whose subject is 'Fix typo in README' has main as its parent."
        for commit in rows:
            changed = changed_paths(repo, commit)
            readme = (file_show(repo, commit, "README.md") or b"").decode()
            if changed == ["README.md"] and "receive" in readme and "recieve" not in readme:
                return True, f"Commit {commit[:12]} on main changes only README.md and fixes the typo."
        return False, f"Typo commit(s) found, but contents are wrong: changed={changed}, README has recieve={'recieve' in readme}."

    if key == "git-vocabulary/wip-on-disk":
        now = disk_sha(repo / "src" / "app.py")
        if now == state["wip_app_sha"]:
            return True, "src/app.py on disk matches the work in progress exactly."
        return False, "src/app.py on disk differs from the work in progress."

    if key == "others-changes/version-commit":
        rows = [r for r in described_new(repo, state["main"]) if "src/cli.py" in changed_paths(repo, r[1])]
        if not rows:
            return False, "No commit after main changes src/cli.py."
        change, commit, subj = rows[0]
        changed = changed_paths(repo, commit)
        if changed != ["src/cli.py"]:
            return False, f"The cli.py commit {subj!r} also changes {[p for p in changed if p != 'src/cli.py']}."
        with tempfile.TemporaryDirectory() as tmp:
            for p in ("src/cli.py", "src/config.py"):
                data = file_show(repo, commit, p)
                if data is None:
                    return False, f"{p} missing at the cli.py commit."
                Path(tmp, Path(p).name).write_bytes(data)
            proc = subprocess.run([sys.executable, "-E", "-s", "cli.py", "--version"], cwd=tmp,
                                  capture_output=True, text=True, timeout=30)
        out = (proc.stdout + proc.stderr).strip()
        if "greeter 1.2.0" in out:
            return True, f"Commit {subj!r} changes only src/cli.py; `cli.py --version` prints {out!r}."
        return False, f"`cli.py --version` at {subj!r} printed {out!r} (exit {proc.returncode})."

    if key == "others-changes/others-on-disk":
        bad = [name for name, path, want in (("README.md", repo / "README.md", state["readme_sha"]),
                                              ("src/config.py", repo / "src" / "config.py", state["config_sha"]))
               if disk_sha(path) != want]
        if bad:
            return False, f"On disk, {bad} no longer match the other person's edits."
        return True, "README.md and src/config.py on disk still hold the other person's edits."

    if key == "rebase-conflict/rebased":
        stack = many(repo, "::feature ~ ::main@origin", "change_id")
        if stack != state["feature_changes"]:
            return False, f"feature's commits above main@origin are {stack}, expected {state['feature_changes']}."
        root_parent = parents_of(repo, "roots(::feature ~ ::main@origin)")
        if root_parent != [state["origin_main"]]:
            return False, f"feature's first commit sits on {root_parent}, not origin's main ({state['origin_main'][:12]})."
        conflicted = many(repo, "::feature & conflicts()", "change_id")
        if conflicted:
            return False, f"{len(conflicted)} commit(s) in feature still have conflicts."
        return True, "feature's two commits (same change IDs) sit on origin's new main with no conflicts."

    if key == "rebase-conflict/resolution":
        with tempfile.TemporaryDirectory() as tmp:
            data = file_show(repo, "feature", "src/greet.py")
            if data is None:
                return False, "src/greet.py missing at feature."
            Path(tmp, "greet.py").write_bytes(data)
            code = "import greet; print(greet.greet('Ada')); print(greet.farewell('Ada'))"
            proc = subprocess.run([sys.executable, "-E", "-s", "-B", "-c", code], cwd=tmp,
                                  capture_output=True, text=True, timeout=30)
        out = proc.stdout.strip().splitlines()
        if out == ["Hi, Ada!", "Goodbye, Ada!"]:
            return True, "At feature, greet('Ada') is 'Hi, Ada!' and farewell('Ada') is 'Goodbye, Ada!'."
        return False, f"At feature, greet/farewell printed {out} (stderr: {proc.stderr.strip()[:200]})."

    if key == "rebase-conflict/readme-kept":
        if disk_sha(repo / "README.md") != state["readme_sha"]:
            return False, "README.md on disk no longer matches the user's edit."
        touched = [c for c in many(repo, "::feature ~ ::main@origin", "commit_id")
                   if "README.md" in changed_paths(repo, c)]
        if touched:
            return False, "A feature commit now changes README.md."
        return True, "README.md on disk still holds the user's edit, and no feature commit includes it."

    if key == "rebase-conflict/not-pushed":
        origin = run_dir / "work" / "origin.git"
        feature = git_ref(origin, "refs/heads/feature")
        main = git_ref(origin, "refs/heads/main")
        if feature:
            return False, "origin has a feature branch."
        if main != state["origin_main"]:
            return False, "origin's main moved."
        return True, "origin has no feature branch and its main is unchanged."

    raise CheckError(f"unknown check {key}")


def main(argv):
    try:
        if len(argv) == 3 and argv[0] == "record":
            print(json.dumps(record(argv[1], Path(argv[2]).resolve())))
            return 0
        if len(argv) == 4 and argv[0] == "check":
            ok, evidence = check(argv[1], argv[2], Path(argv[3]).resolve())
            print(("PASS: " if ok else "FAIL: ") + evidence)
            return 0 if ok else 1
        print(__doc__, file=sys.stderr)
        return 2
    except (CheckError, OSError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
