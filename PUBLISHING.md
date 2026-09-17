# Omarchy Plugins submission notes

This file is a checklist for the maintainer. It is not executed by the
plugin and does not contain credentials.

## Listing metadata

- Category: `Hardware`
- Tags: `quickshell`, `system`, `media`
- Repository: https://github.com/BobSon85/kait2en-omarchy

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
