#!/usr/bin/env python3
"""Build and verify the ArcLake M2 Foundation Demo."""

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
    "T01 named product stores isolate cookie and localStorage",
    "T03 stable coordinator reuses WebView without reloading",
    "T05 explicit cross-Profile copy creates new identity and leaves source",
    "T06 bootstrap commits Default workspace before ready effect",
    "T07 Spaces have independent roots and switch restores selection",
    "T08 Favorites are Profile scoped and unfavorite returns to current Space",
    "T09 Pinned saved URL and custom title survive close and reset",
    "T10 Folder moves are atomic and respect tree rules",
    "T11 Space Profile change releases old identities and keeps A history",
    "T12 Profile deletion failure is retryable and then removes all data",
    "T21 URL submission respects new-tab and navigate-current modes",
    "T21 descriptor and command bar share enabled command rules",
    "Real WKWebView loads, navigates back and reports failure",
]


def command_output(command):
    result = subprocess.run(
        command, cwd=ROOT, capture_output=True, text=True, timeout=60
    )
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


def launch_app(binary, database, start_url, output, launch_number):
    env = os.environ.copy()
    env["ARCLAKE_M2_DATABASE_PATH"] = str(database)
    env["ARCLAKE_M2_START_URL"] = start_url
    stdout_path = output / f"app-launch-{launch_number}.stdout.log"
    stderr_path = output / f"app-launch-{launch_number}.stderr.log"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(
            [str(binary)], cwd=ROOT, env=env,
            stdout=stdout, stderr=stderr, start_new_session=True
        )
        deadline = time.monotonic() + 20
        ready = False
        while time.monotonic() < deadline and process.poll() is None:
            try:
                with sqlite3.connect(database, timeout=1) as connection:
                    history = connection.execute(
                        "SELECT COUNT(*) FROM history_visits"
                    ).fetchone()[0]
                    if history > 0:
                        ready = True
                        break
            except sqlite3.Error:
                pass
            time.sleep(0.2)
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
    return process.returncode, ready


def inspect_database(path):
    with sqlite3.connect(path) as database:
        return {
            "schemaVersion": database.execute("PRAGMA user_version").fetchone()[0],
            "profiles": database.execute("SELECT COUNT(*) FROM profiles").fetchone()[0],
            "spaces": database.execute("SELECT COUNT(*) FROM spaces").fetchone()[0],
            "tabs": database.execute("SELECT COUNT(*) FROM tabs").fetchone()[0],
            "history": database.execute(
                "SELECT COUNT(*) FROM history_visits"
            ).fetchone()[0],
            "revision": database.execute(
                "SELECT CAST(value AS INTEGER) FROM meta WHERE key='revision'"
            ).fetchone()[0],
            "journalMode": database.execute("PRAGMA journal_mode").fetchone()[0],
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--skip-ui-smoke", action="store_true")
    args = parser.parse_args()

    stamp = time.strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    output = ROOT / "test-results/m2" / stamp
    output.mkdir(parents=True)
    latest = ROOT / "test-results/m2/latest.json"
    latest.write_text(json.dumps({
        "directory": str(output.relative_to(ROOT)), "state": "running"
    }, indent=2))

    if not args.skip_build:
        build = subprocess.run(
            ["swift", "build", "-c", "debug", "--product", "ArcLakeM2"],
            cwd=ROOT, capture_output=True, text=True, timeout=300
        )
        (output / "build.log").write_text(build.stdout + build.stderr)
        if build.returncode:
            print(f"Build failed; see {output}/build.log")
            return 1

    bin_path = subprocess.run(
        ["swift", "build", "-c", "debug", "--show-bin-path"],
        cwd=ROOT, capture_output=True, text=True, timeout=60
    ).stdout.strip()
    binary = Path(bin_path) / "ArcLakeM2"
    if not binary.exists():
        print("ArcLakeM2 binary is missing")
        return 1
    target = minimum_target(binary)
    if target != "27.0":
        print(f"Expected macOS 27.0 deployment target, got {target}")
        return 1

    tests = subprocess.run(
        ["swift", "test"], cwd=ROOT,
        capture_output=True, text=True, timeout=420
    )
    test_log = tests.stdout + tests.stderr
    (output / "tests.log").write_text(test_log)
    required = {
        name: f'Test "{name}" passed' in test_log
        for name in REQUIRED_TESTS
    }

    fixture_process = None
    ui_smoke = {"performed": False, "passed": False}
    try:
        if not args.skip_ui_smoke:
            config = output / "fixture-origins.json"
            fixture_stdout = (output / "fixture.stdout.log").open("wb")
            fixture_stderr = (output / "fixture.stderr.log").open("wb")
            fixture_process = subprocess.Popen(
                [
                    str(Path(sys.executable)),
                    str(ROOT / "scripts/m0_fixture.py"),
                    "--config-output", str(config),
                ],
                cwd=ROOT, stdout=fixture_stdout, stderr=fixture_stderr,
                start_new_session=True
            )
            deadline = time.monotonic() + 10
            while not config.exists() and time.monotonic() < deadline:
                time.sleep(0.1)
            if not config.exists():
                raise RuntimeError("Fixture server did not start")
            origins = json.loads(config.read_text())["origins"]
            start_url = origins[0] + "/page?m2-smoke=1"

            smoke_dir = output / "smoke"
            smoke_dir.mkdir()
            database = smoke_dir / "ArcLake.sqlite"
            first_exit, first_ready = launch_app(
                binary, database, start_url, output, 1
            )
            first = inspect_database(database)
            second_exit, _ = launch_app(
                binary, database, start_url, output, 2
            )
            second = inspect_database(database)
            ui_smoke = {
                "performed": True,
                "firstLaunch": {
                    "exitCode": first_exit, "browserReady": first_ready,
                    "database": first,
                },
                "secondLaunch": {
                    "exitCode": second_exit, "database": second,
                },
                "passed": (
                    first_ready
                    and first["schemaVersion"] == 1
                    and first["profiles"] == 1
                    and first["spaces"] == 1
                    and first["tabs"] == 1
                    and first["history"] >= 1
                    and first["journalMode"].lower() == "wal"
                    and second["profiles"] == 1
                    and second["spaces"] == 1
                    and second["tabs"] == 1
                ),
            }
    except Exception as error:
        ui_smoke = {"performed": True, "passed": False, "error": str(error)}
    finally:
        if fixture_process and fixture_process.poll() is None:
            os.killpg(fixture_process.pid, signal.SIGTERM)
            try:
                fixture_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(fixture_process.pid, signal.SIGKILL)

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
        "m2Gate": "passed" if gate_passed else "failed",
        "m2GatePassed": gate_passed,
        "testExitCode": tests.returncode,
        "requiredTests": required,
        "uiSmoke": ui_smoke,
        "environment": environment,
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2))
    latest.write_text(json.dumps({
        "directory": str(output.relative_to(ROOT)),
        "m2GatePassed": gate_passed,
    }, indent=2))
    print(f"M2 results: {output}")
    print("Full tests:", "PASS" if tests.returncode == 0 else "FAIL")
    print("Required M2 scenarios:", "PASS" if all(required.values()) else "FAIL")
    print("UI + real page smoke:", "PASS" if ui_smoke.get("passed") else "FAIL")
    print("M2 gate:", "PASS" if gate_passed else "FAIL")
    return 0 if gate_passed else 1


if __name__ == "__main__":
    sys.exit(main())
