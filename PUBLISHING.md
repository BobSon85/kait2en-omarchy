# Omarchy Plugins submission notes

This file is a checklist for the maintainer. It is not executed by the
plugin and does not contain credentials.

## Listing metadata

- Category: `Hardware`
- Tags: `quickshell`, `system`, `media`
- Repository: https://github.com/BobSon85/kait2en-omarchy

## Store description

KaiT2en Audio DSP brings native Apple T2 speaker support to Arch Linux and
Omarchy. T2 MacBooks need model-specific UCM profiles, host-side DSP graphs
and PipeWire/WirePlumber integration for their internal speakers to sound
correctly. The plugin detects the exact Mac model, installs the matching
components, keeps them updated through a systemd timer and provides an
Omarchy-native panel for status, virtual bass, optional 8-band EQ and
diagnostics. It is designed for MacBook users who want reliable internal
audio without maintaining manual model-specific configuration. Headphones and
normal system audio controls remain untouched.

## Short description

Native KaiT2en speaker DSP, automatic updates and diagnostics for Apple T2 Macs
running Arch Linux and Omarchy.

## Before submission

- [ ] Push this repository to a public GitHub repository.
- [ ] Confirm the plugin ID is globally unique in the marketplace.
- [ ] Run `omarchy plugin validate .` on an Omarchy Quattro system.
- [ ] Test install and removal on a clean supported T2 MacBook.
- [ ] Test an unsupported model and confirm that no privileged action runs.
- [ ] Test KAIT2EN update, profile rollback/backup, WirePlumber restart and
      EQ disable.
- [ ] Review the exact commit and all installer commands.
- [ ] Confirm ownership of the repository and preview assets.
- [ ] Submit the repository only after the checklist is true.

The marketplace validates the repository structure and compatibility; it is
not a security audit. The plugin must therefore keep its terminal install
workflow visible and document every system path it owns.
