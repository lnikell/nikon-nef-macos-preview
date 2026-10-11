# Nikon Finder Preview

**NEF thumbnails and spacebar previews in macOS Finder, using the JPEG already embedded in the RAW file.**

Built to make Nikon ZR photographs browsable when macOS's native RAW decoder cannot display them. There is no photo-viewer window to open, subscription, or paid dependency. The extensions run when Finder requests a preview.

## Install — including after reinstalling macOS

1. Install Apple's Command Line Tools. Open Terminal and run:

   ```sh
   xcode-select --install
   ```

   Finish the installer before continuing. If the tools or Xcode are already installed, skip this step. A paid Apple Developer account is not required.

2. Download the source and install it:

   ```sh
   mkdir -p ~/Projects
   git clone https://github.com/lnikell/nikon-nef-macos-preview.git ~/Projects/nikon-preview
   cd ~/Projects/nikon-preview
   make install
   ```

   If you already have the source folder, skip the clone command and run `make install` from that folder. You can also download and extract the repository's source ZIP from GitHub, then open Terminal in the extracted folder.

3. Reopen the folder containing your `.NEF` files. Finder should show photo thumbnails; select a file and press **Space** for the larger preview.

`make install` runs the tests, compiles and locally signs the extension bundle, installs it for your macOS account, registers both extensions, clears the thumbnail cache, and relaunches Finder. It can also update an existing installation. No `sudo`, Homebrew, Python packages, or network access is needed after the tools and repository are available.

To install without relaunching Finder, use `make test build` followed by `python3 install.py`.

## Repair an existing installation

From this repository's folder:

```sh
make repair
```

This rebuilds and reinstalls the current source, restarts the thumbnail service, and relaunches Finder. It is the first thing to try after a macOS update, missing thumbnails, or stale icons.

If the problem remains:

| Symptom | What to check |
| --- | --- |
| Large preview works, filename icons are blank | In that Finder window, press **Command-J** and enable **Show icon preview**. Run `make repair` if the setting was already enabled. |
| A tiny image appears at the bottom-left of a white icon | Install version **1.0.1 or later** with `make repair`. This was a Retina drawing bug in version 1.0.0. |
| Neither thumbnails nor Space work | Open **System Settings → General → Login Items & Extensions**. Find **Nikon Finder Preview** in the extensions list and enable it if disabled. The grouping and labels vary by macOS release. |
| `xcrun` or `swiftc` is missing | Finish `xcode-select --install`. Check `xcrun --find swiftc` and `xcode-select -p`; if using full Xcode, select its Command Line Tools in Xcode's settings. |
| Only certain NEFs fail | They may not contain a supported embedded JPEG. Run the optional file tests below and include camera model, firmware, NEF compression mode and macOS version in a bug report. |

Check registration by bundle ID:

```sh
pluginkit -m -A -D -vv -i local.alex.NikonFinderPreview.Preview
pluginkit -m -A -D -vv -i local.alex.NikonFinderPreview.Thumbnail
```

Both entries should point to the installed bundle below. A leading `+` indicates that the extension has been enabled. Registration alone does not prove rendering works; verify both Finder icons and Space.

## Where it lives

```text
~/Library/Application Support/Nikon Finder Preview/Nikon Finder Preview.app
```

macOS requires an application bundle to contain the two extensions. This one has no viewer window and does not need to stay open. Moving or deleting your source checkout does not remove the installed extension. Keep the repository backed up or published on GitHub so you can rebuild it after an OS reinstall.

To check the installed version:

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$HOME/Library/Application Support/Nikon Finder Preview/Nikon Finder Preview.app/Contents/Info.plist"
```

## How it works

The shared reader walks the NEF's TIFF directories and selects the largest standard JPEG preview. It preserves the JPEG colour profile and applies the NEF orientation. Quick Look receives JPEG data for Space previews; the thumbnail provider downsamples that same image and fills the requested bitmap, including Retina sizes.

- Originals are opened read-only. No JPEG sidecars are written beside your photographs.
- The extensions are sandboxed and have no networking capability.
- Your default application for opening NEFs is unchanged.
- No RAW-development engine or external library is bundled.

The displayed image is the camera's rendering. It does not reflect later edits made in a RAW editor. Files without a usable standard JPEG preview are unsupported. Tested Nikon ZR High Efficiency* samples contain 6048 × 4032 embedded JPEGs; other Nikon models may work but have not all been verified.

## Requirements and compatibility

- macOS 13 or later is the build target; end-to-end development testing was performed on macOS 27.0.1 on Apple Silicon.
- Apple Command Line Tools or Xcode, including Swift, the macOS SDK, `make` and Python 3.
- Builds target the current Mac's architecture: Apple Silicon or Intel. Intel build/test validation is configured in GitHub Actions; it has not been verified locally.

The bundle is ad hoc signed for local installation. It is not notarized for general binary distribution. Build from source on the Mac where you want to use it.

## Development and tests

```sh
make test
make build
```

The default tests generate their own small JPEG/TIFF fixtures. They cover byte order, orientation, SubIFD selection, malformed offsets, directory cycles, and drawing coverage at 1×, 2× and 3×. No camera card, personal photographs, paid signing identity, or installed extension is needed.

For an optional integration test through macOS's actual thumbnail service, install first, then run from a normal Terminal session:

```sh
python3 test.py --nef "/path/to/portrait.NEF" "/path/to/landscape.NEF"
```

Generated test images are saved under `build/` and ignored by Git. These API checks are complemented by a manual Finder check: small filename icons, icon view, the preview pane, and Space should all show the image with the correct orientation. A restricted execution sandbox may prevent the integration test from granting file access to Quick Look.

| File | Purpose |
| --- | --- |
| `Sources/EmbeddedPreview.swift` | Bounded TIFF reader, JPEG selection, orientation and downsampling |
| `Sources/ThumbnailProvider.swift` | Finder thumbnail rendering |
| `Sources/PreviewProvider.swift` | Data-based Quick Look preview |
| `Sources/Container.swift` | Windowless containing application |
| `build.py` | Native compilation, bundle metadata and local signing |
| `install.py`, `uninstall.py` | Per-user registration and removal |
| `test.py`, `Tests/` | Generated-fixture tests and optional Finder integration tests |

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and release steps, and [CHANGELOG.md](CHANGELOG.md) for changes.

## Uninstall

```sh
make uninstall
```

The uninstaller unregisters these two extensions, archives the installed bundle in the same Application Support folder, removes the bundle, and clears the thumbnail cache. Relaunch Finder if it still displays cached icons. Photographs are never modified.

## License

[MIT](LICENSE). Independent project; not affiliated with Nikon or Apple.

## Platform documentation

- [Apple: thumbnail extensions](https://developer.apple.com/documentation/quicklookthumbnailing/providing-thumbnails-of-your-custom-file-types)
- [Apple: data-based Quick Look providers](https://developer.apple.com/documentation/quicklookui/qlpreviewprovider)
- [Apple: thumbnail drawing coordinates and scale](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailreply/init(contextsize:drawing:))
