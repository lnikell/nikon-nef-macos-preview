#!/usr/bin/env python3
"""Run self-contained tests, optionally followed by installed Finder integration tests."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / 'build'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--nef', nargs='+', type=Path, help='Also request macOS thumbnails for these NEFs; install first.')
args = parser.parse_args()
BUILD.mkdir(parents=True, exist_ok=True)


def suite(name, sources, arguments=()):
    binary = BUILD / name
    subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', '-module-cache-path', str(BUILD / 'ModuleCache'),
                    *[str(ROOT / source) for source in sources], '-o', str(binary)], check=True)
    subprocess.run([str(binary), *map(str, arguments)], check=True)


suite('ReaderTests', ['Sources/EmbeddedPreview.swift', 'Tests/ReaderTests.swift'], [BUILD / 'test-output'])
suite('ThumbnailDrawingTests', ['Sources/EmbeddedPreview.swift', 'Sources/ThumbnailProvider.swift',
                               'Tests/ThumbnailDrawingTests.swift'])
if args.nef:
    suite('FinderThumbnailTests', ['Sources/EmbeddedPreview.swift', 'Tests/FinderThumbnailTests.swift'],
          [BUILD / 'finder-test-output', *[path.expanduser().resolve(strict=True) for path in args.nef]])
