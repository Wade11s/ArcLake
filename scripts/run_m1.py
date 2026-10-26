#!/usr/bin/env python3
"""Build, test and smoke-launch the ArcLake M1 workspace foundation."""

import argparse
import hashlib
import json
import os
import platform
import re
import signal
import sqlite3
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_TESTS = [
    "T06 bootstrap commits Default workspace before ready effect",
    "T07 Spaces have independent roots and switch restores selection",
    "T08 Favorites are Profile scoped and unfavorite returns to current Space",
    "T09 Pinned saved URL and custom title survive close and reset",
    "T10 Folder moves are atomic and respect tree rules",
    "100 random legal tree moves preserve all invariants",
    "Invalid tree move does not write or advance revision",
    "T25 uncommitted transaction is invisible after reopen",
    "T26 disk full rolls back all rows",
    "T26 read-only database fails explicitly",
    "T26 revision mismatch does not publish new state",
    "T27 interrupted migration rolls back and preserves backup",
    "T27 future schema is rejected without overwrite",
    "T28 stale decision cannot overwrite committed revision",
]


def command_output(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    text = (result.stdout + result.stderr).strip()
    return text.splitlines()[0] if text else "unknown"


def package_tools_version():
    first = (ROOT / "Package.swift").read_text().splitlines()[0]
    match = re.search(r"swift-tools-version:\s*(\S+)", first)
    return match.group(1) if match else "unknown"


def minimum_target(binary):
    result = subprocess.run(
        ["xcrun", "vtool", "-show-build", str(binary)],
        cwd=ROOT, capture_output=True, text=True, timeout=30
    )
    match = re.search(r"^\s*minos\s+(\S+)", result.stdout, re.MULTILINE)
    return match.group(1) if match else "unknown"


def launch_smoke(binary, database, output, launch_number):
    env = os.environ.copy()
    env["ARCLAKE_M1_DATABASE_PATH"] = str(database)
    stdout_path = output / f"ui-launch-{launch_number}.stdout.log"
    stderr_path = output / f"ui-launch-{launch_number}.stderr.log"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(
            [str(binary)], cwd=ROOT, env=env,
            stdout=stdout, stderr=stderr, start_new_session=True
        )
        time.sleep(2.5)
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
    return process.returncode


def inspect_database(path):
    with sqlite3.connect(path) as database:
        version = database.execute("PRAGMA user_version").fetchone()[0]
        profiles = database.execute("SELECT COUNT(*) FROM profiles").fetchone()[0]
        spaces = database.execute("SELECT COUNT(*) FROM spaces").fetchone()[0]
        revision = database.execute(
            "SELECT CAST(value AS INTEGER) FROM meta WHERE key='revision'"
        ).fetchone()[0]
        wal = database.execute("PRAGMA journal_mode").fetchone()[0]
    return {
        "schemaVersion": version,
        "profiles": profiles,
        "spaces": spaces,
        "revision": revision,
        "journalMode": wal,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--skip-ui-smoke", action="store_true")
    args = parser.parse_args()

    stamp = time.strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    output = ROOT / "test-results/m1" / stamp
    output.mkdir(parents=True)
    latest = ROOT / "test-results/m1/latest.json"
    latest.write_text(json.dumps({"directory": str(output.relative_to(ROOT)), "state": "running"}, indent=2))

    build_log = ""
    if not args.skip_build:
        build = subprocess.run(
            ["swift", "build", "-c", "debug", "--product", "ArcLakeM1"],
            cwd=ROOT, capture_output=True, text=True, timeout=240
        )
        build_log = build.stdout + build.stderr
        (output / "build.log").write_text(build_log)
        if build.returncode:
            print(f"Build failed; see {output}/build.log")
            return 1

    bin_path = subprocess.run(
        ["swift", "build", "-c", "debug", "--show-bin-path"],
        cwd=ROOT, capture_output=True, text=True, timeout=60
    ).stdout.strip()
    binary = Path(bin_path) / "ArcLakeM1"
    if not binary.exists():
        print("ArcLakeM1 binary is missing")
        return 1

    target = minimum_target(binary)
    if target != "27.0":
        print(f"Expected macOS 27.0 deployment target, got {target}")
        return 1

    tests = subprocess.run(
        ["swift", "test"], cwd=ROOT,
        capture_output=True, text=True, timeout=300
    )
    test_log = tests.stdout + tests.stderr
    (output / "tests.log").write_text(test_log)
    required = {
        name: f'Test "{name}" passed' in test_log
        for name in REQUIRED_TESTS
    }

    ui_smoke = {"performed": False, "firstLaunch": None, "secondLaunch": None}
    if not args.skip_ui_smoke:
        smoke_dir = output / "smoke"
        smoke_dir.mkdir()
        database = smoke_dir / "ArcLake.sqlite"
        first_code = launch_smoke(binary, database, output, 1)
        first = inspect_database(database)
        second_code = launch_smoke(binary, database, output, 2)
        second = inspect_database(database)
        ui_smoke = {
            "performed": True,
            "firstLaunch": {"exitCode": first_code, "database": first},
            "secondLaunch": {"exitCode": second_code, "database": second},
            "passed": (
                first["schemaVersion"] == 1
                and first["profiles"] == 1
                and first["spaces"] == 1
                and first["revision"] == 1
                and first["journalMode"].lower() == "wal"
                and second["profiles"] == 1
                and second["spaces"] == 1
                and second["revision"] == 1
            ),
        }

    gate_passed = (
        tests.returncode == 0
        and all(required.values())
        and ui_smoke.get("passed", False)
    )
    environment = {
        "macOS": platform.mac_ver()[0],
        "architecture": platform.machine(),
        "swiftVersion": command_output(["swift", "--version"]),
        "xcodeVersion": command_output(["xcodebuild", "-version"]),
        "packageToolsVersion": package_tools_version(),
        "minimumDeploymentTarget": target,
        "binarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
    }
    (output / "environment.json").write_text(json.dumps(environment, indent=2))
    summary = {
        "m1Gate": "passed" if gate_passed else "failed",
        "m1GatePassed": gate_passed,
        "testExitCode": tests.returncode,
        "requiredTests": required,
        "uiSmoke": ui_smoke,
        "environment": environment,
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2))
    latest.write_text(json.dumps({
        "directory": str(output.relative_to(ROOT)),
        "m1GatePassed": gate_passed,
    }, indent=2))
    print(f"M1 results: {output}")
    print("Core/Persistence tests:", "PASS" if tests.returncode == 0 else "FAIL")
    print("Required M1 scenarios:", "PASS" if all(required.values()) else "FAIL")
    if ui_smoke["performed"]:
        print("SwiftUI cold-start smoke:", "PASS" if ui_smoke["passed"] else "FAIL")
    print("M1 gate:", "PASS" if gate_passed else "FAIL")
    return 0 if gate_passed else 1


if __name__ == "__main__":
    sys.exit(main())
