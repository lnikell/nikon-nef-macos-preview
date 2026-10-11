#!/usr/bin/env python3
"""Unregister our two extensions and preserve the bundle in a backup archive."""
from datetime import datetime
from pathlib import Path
import shutil
import subprocess

root = Path.home() / 'Library/Application Support/Nikon Finder Preview'
app = root / 'Nikon Finder Preview.app'
if not app.exists():
    raise SystemExit('Nikon Finder Preview is not installed at the expected location.')
backup = root / ('Nikon-Finder-Preview-backup-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.zip')
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(backup)], check=True)
for kind in ['Preview', 'Thumbnail']:
    subprocess.run(['pluginkit', '-e', 'ignore', '-i', 'local.alex.NikonFinderPreview.' + kind], check=True)
    subprocess.run(['pluginkit', '-r', str(app / 'Contents/PlugIns' / ('Nikon' + kind + '.appex'))], check=False)
lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
subprocess.run([lsregister, '-u', str(app)], check=True)
shutil.rmtree(app)
subprocess.run(['qlmanage', '-r', 'cache'], check=False)
subprocess.run(['killall', '-KILL', 'com.apple.quicklook.ThumbnailsAgent'], check=False)
print('Uninstalled. Bundle backup:', backup)
