#!/usr/bin/env python3
"""Build each run's repository fixture in a prepared skillwright workspace.

  build_fixtures.py WORKSPACE

For every run in WORKSPACE/manifest.json, runs fixtures/<case>.sh on the run's
work/ directory, then records the starting state in the run directory's
fixture-state.json (outside work/, where executors do not look) for the checks.
Refuses a run whose work/app already exists.
"""

import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main(argv):
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    workspace = Path(argv[0]).resolve()
    manifest = json.loads((workspace / "manifest.json").read_text())
    failures = 0
    for run in manifest["runs"]:
        run_dir = workspace / run["directory"]
        case = run["case_id"]
        script = HERE / "fixtures" / f"{case}.sh"
        if (run_dir / "work" / "app").exists():
            print(f"skip {run['id']}: work/app exists", file=sys.stderr)
            failures += 1
            continue
        built = subprocess.run(["sh", str(script), str(run_dir / "work")], capture_output=True, text=True)
        recorded = built.returncode == 0 and subprocess.run(
            [sys.executable, "-I", str(HERE / "checks" / "jjcheck.py"), "record", case, str(run_dir)],
            capture_output=True, text=True,
        ).returncode == 0
        print(f"{'ok  ' if recorded else 'FAIL'} {run['id']}")
        if not recorded:
            print(built.stderr, file=sys.stderr)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
