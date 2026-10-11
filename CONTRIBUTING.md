# Contributing

## Local checks

```sh
make test build
```

The build uses native macOS frameworks and local ad hoc signing. There is no dependency manager. The GitHub Actions workflow runs the same checks on Apple Silicon and Intel macOS runners. It does not install the extensions in CI.

For changes to rendering or extension registration, also run `make install`, test representative NEFs with `python3 test.py --nef /path/to/photo.NEF`, and inspect Finder manually at small icon sizes and in Space previews. The unit tests use generated fixtures; do not commit private photographs or camera-card contents.

## Source conventions

- Preserve read-only access to originals and the extension sandbox.
- Bound TIFF traversal and validate offsets before reading image data.
- Use the actual Core Graphics bitmap and coordinate transform for thumbnail drawing. `contextSize` is measured in points; the bitmap may be larger on Retina displays.
- Keep the existing `local.alex.NikonFinderPreview` bundle IDs stable. They are retained for compatibility with the original local installation; changing them would create parallel extensions instead of updating it.
- Bump `CFBundleVersion` and `CFBundleShortVersionString` in `build.py` for a new release.

## Bug reports

Include macOS version, Mac architecture, camera model and firmware, NEF compression setting, extension version, and whether the problem affects small Finder icons, the preview pane, or Space. A screenshot of the problem is helpful. Only share a sample photograph if you are comfortable making it public.

## Submitting changes

Fork the repository, make changes on a branch, run the local checks, and open a pull request with the reason for the change and the checks performed.

Review `git status --short` and `git diff --cached` before committing. The ignore rules exclude generated bundles, caches, photographs, extracted previews, local environment files, and signing material. Keep sample images outside the repository; the tests generate their own fixtures. Do not force-add private files. Ignore rules do not protect files that Git already tracks, and they cannot detect secrets inside source or documentation.

Use a GitHub noreply email for commits if you do not want your personal email to appear in the public history.

## Releases

Update the version in `build.py` and `CHANGELOG.md`, pass the local checks, verify Finder behaviour, and tag the release. Prefer source releases so users can build locally. A binary intended for general distribution needs an appropriate signing and notarization workflow; the current build only provides ad hoc local signing.
