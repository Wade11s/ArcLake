#!/usr/bin/env python3
"""Build and exercise the independent M0 app with owned loopback fixtures/stores.

Every run allocates fresh IDs; seed and verify reuse the same saved manifest.
No system browser setting is changed. Only this run's three stores are removed.
"""
import argparse, hashlib, json, os, platform, selectors, subprocess, sys, time, uuid
from pathlib import Path
from m0_fixture import servers

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'build/ArcLakeM0.app/Contents/MacOS/ArcLakeM0'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--test', action='store_true')
    mode.add_argument('--demo', action='store_true')
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    stamp = time.strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
    output = ROOT / 'test-results/m0' / stamp
    output.mkdir(parents=True)
    (ROOT / 'test-results/m0/latest.json').write_text(json.dumps({'directory': str(output.relative_to(ROOT)), 'state': 'running', 'automatedSubsetPassed': False}, indent=2))
    if not args.skip_build:
        build = subprocess.run(['bash', 'scripts/build_m0.sh'], cwd=ROOT, capture_output=True, text=True)
        (output / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            print(f'Build failed; see {output}/build.log'); return 1
    if not APP.exists(): parser.error('Build missing; omit --skip-build')
    unit_results = {}
    if not args.demo:
        for name, command in [('swift', ['swift', 'test']), ('fixture', [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_m0_fixture.py'])]:
            unit = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
            (output / f'unit-{name}.log').write_text(unit.stdout + unit.stderr)
            unit_results[name] = unit.returncode
            if unit.returncode:
                print(f'{name} tests failed; see {output}/unit-{name}.log'); return 1
    config = {'store-a': str(uuid.uuid4()), 'store-b': str(uuid.uuid4()),
              'disposable-store': str(uuid.uuid4()), 'run-token': stamp}
    environment = {'macOS': platform.mac_ver()[0], 'architecture': platform.machine(),
                   'bundleID': 'dev.arclake.M0Probe', 'binarySHA256': hashlib.sha256(APP.read_bytes()).hexdigest(),
                   'adHocSigned': True, 'sandboxEntitlements': ['app-sandbox', 'network.client'],
                   'minimumDeploymentTarget': '14.0', 'mode': 'demo' if args.demo else 'test'}
    reports = {}
    def run_phase(phase):
        # Round-trip the saved file on every app launch; stable identities are not
        # dependent on in-memory objects retained by the previous app process.
        saved = json.loads((output / 'run-config.json').read_text())
        command = [str(APP), '--phase', phase]
        for key, value in saved.items(): command += ['--' + key, value]
        try:
            completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                       timeout=None if phase == 'demo' else 150)
            (output / f'{phase}.stdout.log').write_text(completed.stdout)
            (output / f'{phase}.stderr.log').write_text(completed.stderr)
            lines = [s[len('M0_REPORT '):] for s in completed.stdout.splitlines() if s.startswith('M0_REPORT ')]
            report = json.loads(lines[-1]) if lines else {'phase': phase, 'checks': [], 'error': 'No structured report'}
            report['exitCode'] = completed.returncode
        except subprocess.TimeoutExpired as exc:
            (output / f'{phase}.timeout.log').write_text(str(exc))
            report = {'phase': phase, 'checks': [], 'error': 'Timeout; owned app process killed', 'exitCode': -1}
        reports[phase] = report
        (output / f'{phase}.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
        return report
    def passed(report):
        return report.get('exitCode') == 0 and not report.get('error') and bool(report.get('checks')) and not any(c['status'] == 'fail' for c in report['checks'])
    def force_quit_phase():
        command = [str(APP), '--phase', 'force-quit-seed']
        for key, value in config.items(): command += ['--' + key, value]
        captured = b''
        ready = False
        with (output / 'force-quit-seed.stderr.log').open('wb') as errors:
            process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=errors, bufsize=0)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    deadline = time.monotonic() + 30
                    while time.monotonic() < deadline and process.poll() is None:
                        if selector.select(timeout=0.1):
                            block = os.read(process.stdout.fileno(), 4096)
                            if not block: break
                            captured += block
                            if b'M0_FORCE_QUIT_READY\n' in captured:
                                ready = True; break
            finally:
                if process.poll() is None: process.kill()  # Only the child PID we created.
                tail, _ = process.communicate(timeout=10)
                captured += tail
        (output / 'force-quit-seed.stdout.log').write_bytes(captured)
        success = ready and process.returncode == -9
        report = {'phase': 'force-quit-seed', 'exitCode': process.returncode,
                  'checks': [{'id': 'owned-app-SIGKILL-after-acknowledged-write',
                              'status': 'pass' if success else 'fail',
                              'detail': 'Harness killed only its child app after all four storage markers were read back.'}]}
        reports['force-quit-seed'] = report
        (output / 'force-quit-seed.json').write_text(json.dumps(report, indent=2))
        return success
    ok = False
    with servers() as origins:
        config.update({'origin-a': origins[0], 'origin-b': origins[1]})
        (output / 'run-config.json').write_text(json.dumps(config, indent=2))
        (output / 'environment.json').write_text(json.dumps(environment, indent=2))
        print(f'M0 results: {output}', flush=True)
        try:
            if args.demo:
                print('Local-only M0 demo. Quit the app to stop fixtures and remove this run’s test stores.', flush=True)
                demo = run_phase('demo')
                ok = demo.get('exitCode') == 0
            else:
                seed = run_phase('seed')
                print('seed:', 'PASS' if passed(seed) else 'FAIL', flush=True)
                if passed(seed):
                    verify = run_phase('verify')
                    print('restart verify:', 'PASS' if passed(verify) else 'FAIL', flush=True)
                    negative = run_phase('negative')
                    detected = negative.get('exitCode') == 1 and any(c['id'] == 'negative-control-isolation' and c['status'] == 'fail' for c in negative['checks'])
                    print('negative control:', 'DETECTED (expected)' if detected else 'FAIL', flush=True)
                    forced = force_quit_phase()
                    force_verify = run_phase('verify-force-quit') if forced else {}
                    print('forced-quit persistence:', 'PASS' if forced and passed(force_verify) else 'FAIL', flush=True)
                    ok = passed(verify) and detected and forced and passed(force_verify)
        finally:
            cleanup = run_phase('cleanup')
            print('owned-store cleanup:', 'PASS' if passed(cleanup) else 'FAIL — retain manifest for retry', flush=True)
            ok = ok and passed(cleanup)
            summary = {'automatedSubsetPassed': ok, 'm0Gate': 'pending',
                       'gateReason': 'Real keyboard/IME, nonzero page scroll handoff, actual WebKit process crash and macOS 14 runtime still unverified.',
                       'phases': reports, 'environment': environment, 'unitTestExitCodes': unit_results}
            (output / 'summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False))
            (ROOT / 'test-results/m0/latest.json').write_text(json.dumps({'directory': str(output.relative_to(ROOT)), 'automatedSubsetPassed': ok}, indent=2))
    print('Automated subset:', 'PASS; M0 full gate remains pending' if ok else 'FAIL', flush=True)
    return 0 if ok else 1

if __name__ == '__main__': sys.exit(main())
