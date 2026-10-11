#!/usr/bin/env python3
"""Build locally signed macOS extensions using the installed Xcode toolchain."""
import pathlib
import platform
import plistlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent
BUILD = ROOT / 'build'
APP = BUILD / 'Nikon Finder Preview.app'
PREFIX = 'local.alex.NikonFinderPreview'
ARCH = platform.machine()
if platform.system() != 'Darwin' or ARCH not in ('arm64', 'x86_64'):
    raise SystemExit('Build on an Apple Silicon or Intel Mac with Xcode Command Line Tools installed.')


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def plist(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(data))


def bundle_info(name, identifier, extension=False):
    return {
        'CFBundleName': name, 'CFBundleDisplayName': name,
        'CFBundleIdentifier': identifier, 'CFBundleExecutable': name,
        'CFBundlePackageType': 'XPC!' if extension else 'APPL',
        'CFBundleSupportedPlatforms': ['MacOSX'],
        'CFBundleVersion': '2', 'CFBundleShortVersionString': '1.0.1',
        'CFBundleInfoDictionaryVersion': '6.0', 'LSMinimumSystemVersion': '13.0',
        'NSHighResolutionCapable': True,
    }


BUILD.mkdir(parents=True, exist_ok=True)
entitlements = BUILD / 'Sandbox.entitlements'
plist(entitlements, {
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-only': True,
})

flags = ['-O', '-swift-version', '5', '-target', f'{ARCH}-apple-macos13.0',
         '-module-cache-path', str(BUILD / 'ModuleCache'), '-parse-as-library']

for kind in ['Preview', 'Thumbnail']:
    name = 'Nikon' + kind
    extension = APP / 'Contents' / 'PlugIns' / (name + '.appex')
    binary = extension / 'Contents' / 'MacOS' / name
    binary.parent.mkdir(parents=True, exist_ok=True)
    run('xcrun', 'swiftc', *flags, '-emit-executable', '-application-extension',
        '-module-name', name, '-Xlinker', '-e', '-Xlinker', '_NSExtensionMain',
        ROOT / 'Sources' / 'EmbeddedPreview.swift', ROOT / 'Sources' / (kind + 'Provider.swift'),
        '-framework', 'AppKit', '-o', binary)
    attributes = {'QLSupportedContentTypes': ['com.nikon.raw-image']}
    if kind == 'Preview':
        attributes.update(QLIsDataBasedPreview=True, QLSupportsSearchableItems=False)
    else:
        attributes['QLThumbnailMinimumDimension'] = 0
    info = bundle_info(name, PREFIX + '.' + kind, True)
    info['NSExtension'] = {
        'NSExtensionPointIdentifier': 'com.apple.quicklook.' + kind.lower(),
        'NSExtensionPrincipalClass': 'Nikon' + kind + 'Provider',
        'NSExtensionAttributes': attributes,
    }
    plist(extension / 'Contents' / 'Info.plist', info)
    run('codesign', '--force', '--sign', '-', '--entitlements', entitlements,
        '--generate-entitlement-der', extension)

binary = APP / 'Contents' / 'MacOS' / 'Nikon Finder Preview'
binary.parent.mkdir(parents=True, exist_ok=True)
run('xcrun', 'swiftc', *flags, ROOT / 'Sources' / 'Container.swift', '-o', binary)
info = bundle_info('Nikon Finder Preview', PREFIX)
info.update(LSUIElement=True, LSBackgroundOnly=True, NSPrincipalClass='NSApplication')
plist(APP / 'Contents' / 'Info.plist', info)
run('codesign', '--force', '--sign', '-', '--entitlements', entitlements,
    '--generate-entitlement-der', APP)
run('codesign', '--verify', '--deep', '--strict', '--verbose=2', APP)
print(APP)
