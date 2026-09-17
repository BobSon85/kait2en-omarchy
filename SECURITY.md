# Security and privilege model

This is an Omarchy shell plugin. Omarchy plugins run unsandboxed inside
`omarchy-shell`; review the repository before enabling it.

## Privileged actions

The QML panel does not run privileged commands directly. It opens a visible
terminal for the user and invokes `scripts/install.sh`, `scripts/set-bass.sh`,
or `scripts/uninstall.sh`. Those scripts show their purpose and use `sudo` for
the documented system paths only.

The systemd updater runs as root because it installs system-wide PipeWire,
WirePlumber, UCM, LV2, udev, and systemd files. It does not accept arbitrary
commands or settings; the only administrator setting is numeric `BASS_AMT`.

## Network and source updates

The updater fetches the public KAIT2EN-Fedora and Bankstown repositories into
`/var/lib/kait2en-dsp`, builds them locally, and installs the resulting files.
It does not send user data or credentials. A source update is applied only
after the upstream build and tests complete; previous installed trees are
kept in timestamped backups.

## Owned paths

System integration owns the following paths:

- `/usr/local/libexec/kait2en-omarchy-update`
- `/etc/systemd/system/kait2en-dsp-update.{service,timer}`
- `/etc/kait2en-omarchy/settings.conf`
- `/usr/share/t2-dsp/` and `/usr/lib/lv2/bankstown.lv2/`
- `/usr/share/wireplumber/wireplumber.conf.d/51-kait2en-dsp.conf`
- `/usr/lib/udev/rules.d/89-kait2en-dsp.rules`

Backups are retained under `/var/lib/kait2en-dsp/backups`. Shared Apple T2
UCM files are deliberately retained during removal because other audio
components may use them.
