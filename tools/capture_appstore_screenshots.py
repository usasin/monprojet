"""Capture the real Flutter screens on iPhone and iPad simulators, then validate PNG sizes."""
import json
import os
from pathlib import Path
import struct
import subprocess


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def simulator_json(kind):
    return json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', kind, '--json']))[kind]


def capture(family, candidates, accepted_sizes, runtime, types):
    device = next((d for name in candidates for d in types if d['name'] == name), None)
    if device is None:
        raise RuntimeError(f'No supported {family} simulator device: {candidates}')
    udid = subprocess.check_output([
        'xcrun', 'simctl', 'create', f'Prospecto capture {family}', device['identifier'], runtime,
    ], text=True).strip()
    output = Path('build/appstore-screenshots') / family
    output.mkdir(parents=True, exist_ok=True)
    try:
        run('xcrun', 'simctl', 'boot', udid)
        run('xcrun', 'simctl', 'bootstatus', udid, '-b')
        run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
            '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3',
            '--batteryState', 'charged', '--batteryLevel', '100')
        run('flutter', 'drive', '--no-pub', '--driver=test_driver/appstore_screenshots.dart',
            '--target=integration_test/appstore_screenshots_test.dart', '-d', udid,
            env={**os.environ, 'PROSPECTO_SCREENSHOT_DIR': str(output.resolve())})
        images = list(output.glob('*.png'))
        if len(images) != 4:
            raise RuntimeError(f'Expected four {family} captures, got {len(images)}')
        for image in images:
            data = image.read_bytes()
            if data[:8] != b'\x89PNG\r\n\x1a\n':
                raise RuntimeError(f'Invalid PNG: {image}')
            size = struct.unpack('>II', data[16:24])
            if size not in accepted_sizes:
                raise RuntimeError(f'Unsupported Apple size {size}: {image}')
            # JPEG removes the PNG alpha channel without resizing the native capture.
            run('sips', '-s', 'format', 'jpeg', '--setProperty', 'formatOptions', 'best',
                str(image), '--out', str(image.with_suffix('.jpg')))
            print(f'Native Apple capture validated: {image} {size}', flush=True)
    finally:
        run('xcrun', 'simctl', 'shutdown', udid)
        run('xcrun', 'simctl', 'delete', udid)


if __name__ == '__main__':
    runtimes = [r for r in simulator_json('runtimes') if r.get('isAvailable') and 'iOS' in r['name']]
    runtime = max(runtimes, key=lambda r: tuple(int(v) for v in r['version'].split('.')))['identifier']
    types = simulator_json('devicetypes')
    capture('iphone', ['iPhone 16 Pro Max', 'iPhone 17 Pro Max', 'iPhone 15 Pro Max'],
            {(1320, 2868), (1290, 2796), (1260, 2736)}, runtime, types)
    capture('ipad', ['iPad Pro 13-inch (M4)', 'iPad Pro 13-inch (M5)', 'iPad Air 13-inch (M3)',
                     'iPad Air 13-inch (M2)', 'iPad Pro (12.9-inch) (6th generation)'],
            {(2064, 2752), (2048, 2732)}, runtime, types)
