# KaiT2en Audio DSP for Omarchy

Native Omarchy integration for the host-side PipeWire DSP profiles from
[KaiT2en-Fedora](https://github.com/kaiT2en/KaiT2en-Fedora), intended for Apple
T2 Macs running Arch Linux and Omarchy.

## Design

The plugin is a user interface and diagnostics layer. It does not replace the
model-specific KAIT2EN speaker graph. Installation and updates are performed by
auditable terminal scripts because Omarchy's plugin installer deliberately does
not run plugin install hooks or `sudo` commands.

The user equalizer will be an optional separate PipeWire stage. `Flat` must
always be a safe, zero-change setting and disabling it must remove the user
stage rather than alter the upstream KAIT2EN profile.

## Supported hardware

The installer reads the DMI product name and follows the profile mapping from
the KAIT2EN source. It currently covers the upstream Apple T2 speaker profiles
for MacBookAir8,1/8,2, MacBookAir9,1, MacBookPro15,1–15,4 and
MacBookPro16,1–16,4. Unknown models are rejected before any privileged action.

## System integration

`install.sh` is intentionally a visible terminal workflow. It verifies that a
T2-enabled kernel exposes `t2bce_audio`, installs the Arch dependencies
including `apple-t2-audio-config` (UCM), builds the upstream DSP graph and
Bankstown, installs the WirePlumber and udev rules and enables the daily
`kait2en-dsp-update.timer`. The uninstaller disables only files owned by this
integration and leaves backups in `/var/lib/kait2en-dsp`.

The generated profile target adapts to both the legacy `Audio` ALSA card id and
the upstream model-specific `t2-*` id. Speaker and internal-microphone
profiles are activated only for the matching UCM Speaker/Mic nodes; headphones
and headset microphones remain untouched. Reboot after the first installation
so the udev card-id rule can take effect cleanly.

The plugin also includes a repair action for the known failure mode where a
user-local Bankstown checkout duplicates the system LV2 plugin.

The panel exposes both the optional 8-band user EQ and the KAIT2EN
virtual-bass amount. The latter is stored separately from upstream graphs and
reapplied by the system updater after a profile update.

## Development

After the repository is public, installation is performed with:

```sh
omarchy plugin add https://github.com/<owner>/kait2en-omarchy.git --enable
```

Open the KaiT2en Audio widget and choose `Instaluj / napraw` to install the
system dependencies and enable the DSP updater. To remove the shell plugin:

```sh
omarchy plugin remove kait2en.audio
```

The system integration has its own `scripts/uninstall.sh`; removing the shell
plugin does not silently remove audio system files.

Validate the manifest with:

```sh
omarchy plugin validate .
```

For a local test, copy or link this directory into
`~/.config/omarchy/plugins/kait2en.audio/`, then run:

```sh
omarchy-shell shell rescanPlugins
omarchy plugin enable kait2en.audio
```

The installer and updater detect the hardware profile, create backups, and
never touch unsupported Macs.

## License

Plugin code is GPL-3.0-or-later. KAIT2EN and third-party component notices will
be documented before publication.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the attribution and
license handling of the downloaded components.
