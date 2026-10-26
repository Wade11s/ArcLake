#!/usr/bin/env python3
"""Retry cleanup only for a saved ArcLake M0 run manifest under this repository."""
import json, subprocess, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    sys.exit('Usage: python3 scripts/cleanup_m0.py test-results/m0/<run>/run-config.json')
manifest = Path(sys.argv[1]).resolve()
try: manifest.relative_to(root / 'test-results/m0')
except ValueError: sys.exit('Refusing a manifest outside this project’s M0 results.')
if manifest.name != 'run-config.json': sys.exit('Expected run-config.json')
env = json.loads((manifest.parent / 'environment.json').read_text())
if env.get('bundleID') != 'dev.arclake.M0Probe': sys.exit('Not an ArcLake M0 run.')
config = json.loads(manifest.read_text())
if set(config) != {'store-a', 'store-b', 'disposable-store', 'run-token', 'origin-a', 'origin-b'}:
    sys.exit('Unexpected manifest keys.')
command = [str(root / 'build/ArcLakeM0.app/Contents/MacOS/ArcLakeM0'), '--phase', 'cleanup']
for key, value in config.items(): command += ['--' + key, value]
r = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
(manifest.parent / 'cleanup-retry.stdout.log').write_text(r.stdout)
(manifest.parent / 'cleanup-retry.stderr.log').write_text(r.stderr)
print(r.stdout)
sys.exit(r.returncode)
