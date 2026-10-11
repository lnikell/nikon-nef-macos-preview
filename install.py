#!/usr/bin/env python3
"""Install the windowless extension bundle for the current user."""
from pathlib import Path
import argparse
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--restart-finder', action='store_true', help='Relaunch Finder to clear its cached file icons.')
args = parser.parse_args()

ROOT = Path(__file__).resolve().parent
NAME = 'Nikon Finder Preview.app'
source = ROOT / 'build' / NAME
if not source.exists():
    source = ROOT / NAME
if not source.exists():
    raise SystemExit('Build first: python3 build.py')

destination = Path.home() / 'Library/Application Support/Nikon Finder Preview' / NAME
destination.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(source)], check=True)
# An existing extension process may retain the previous executable in memory.
subprocess.run(['killall', '-KILL', 'NikonThumbnail'], check=False, stderr=subprocess.DEVNULL)
subprocess.run(['ditto', str(source), str(destination)], check=True)
# Force LaunchServices to refresh metadata after an update.
destination.touch()
lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
subprocess.run([lsregister, '-f', str(destination)], check=True)
for kind in ['Preview', 'Thumbnail']:
    extension = destination / 'Contents/PlugIns' / ('Nikon' + kind + '.appex')
    subprocess.run(['pluginkit', '-a', str(extension)], check=True)
    subprocess.run(['pluginkit', '-e', 'use', '-i', 'local.alex.NikonFinderPreview.' + kind], check=True)
subprocess.run(['qlmanage', '-r'], check=True)
subprocess.run(['qlmanage', '-r', 'cache'], check=True)
# This cache service can ignore SIGTERM and retain an outdated provider list.
# It has no user documents; launchd restarts it on the next thumbnail request.
subprocess.run(['killall', '-KILL', 'com.apple.quicklook.ThumbnailsAgent'], check=False)
print('Installed. Reopen your Finder folder; select a NEF and press Space.')
print(destination)
if args.restart_finder:
    subprocess.run(['killall', 'Finder'], check=False, stderr=subprocess.DEVNULL)
