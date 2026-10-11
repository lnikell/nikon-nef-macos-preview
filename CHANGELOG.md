# Changelog

## Unreleased

- Self-contained generated test fixtures; no personal NEF sample is required.
- One-command install and repair targets, plus fresh-macOS setup instructions.
- Build for the current Mac's architecture, with macOS CI configured for Apple Silicon and Intel.

## 1.0.1

- Fill the complete Quick Look bitmap on Retina displays, fixing an image drawn in the bottom-left quarter over a white background.
- Add regression coverage for portrait and landscape thumbnails at 1×, 2× and 3× scale, with and without a point-space transform.

## 1.0.0

- Extract the largest standard embedded JPEG from a Nikon NEF.
- Preserve colour profile and apply orientation for Finder thumbnails and spacebar Quick Look.
- Install sandboxed extensions inside a windowless containing application.
