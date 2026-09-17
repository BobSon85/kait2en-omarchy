# KaiT2en Audio DSP for Omarchy

Native Omarchy integration for the host-side PipeWire DSP profiles from
[KaiT2en-Fedora](https://github.com/kaiT2en/KaiT2en-Fedora), intended for Apple
T2 Macs running Arch Linux and Omarchy.

## Why this plugin exists

Apple T2 MacBooks can run Linux very well, but their internal speakers are not
ordinary ALSA devices. The T2 audio path needs model-specific UCM profiles,
host-side DSP graphs and a correctly wired PipeWire/WirePlumber setup. Without
that integration, the speakers may be quiet, unbalanced or missing entirely.

KaiT2en provides the audio processing that makes the built-in speakers useful
on supported T2 Macs. This plugin brings that work into Omarchy as a native,
discoverable control surface: it detects the exact Mac model, installs the
matching profile, keeps the DSP components updated and exposes status,
virtual bass, an optional equalizer and diagnostics from one panel.

The plugin is intended for users who want their MacBook's internal speakers to
work properly on Arch/Omarchy without maintaining a collection of manual
PipeWire commands and model-specific configuration files. It does not replace
Omarchy's audio panel, alter headphone routing or hide system changes: it adds
the missing T2 speaker integration and leaves the normal audio controls intact.

## Design

The plugin is a user interface and diagnostics layer. It does not replace the
model-specific KAIT2EN speaker graph. Installation and updates are performed by
auditable terminal scripts because Omarchy's plugin installer deliberately does
not run plugin install hooks or `sudo` commands.

The user equalizer is an optional separate PipeWire stage. `Flat` is a safe,
zero-change setting and disabling it removes the user stage rather than
altering the upstream KAIT2EN profile. The bar uses a fixed technical DSP icon:
white means the DSP output is active, while red means it is inactive or muted.

## Supported hardware

The installer reads the DMI product name and follows the profile mapping from
the KAIT2EN source. The supported MacBook matrix is:

| MacBook | KAIT2EN profile |
| --- | --- |
| Air 2018 | `MacBookAir8,1` → `8_1` |
| Air 2019 | `MacBookAir8,2` → `8_2` |
| Air 2020 Intel | `MacBookAir9,1` → `9_1` |
| Pro 15-inch 2018/2019 | `MacBookPro15,1` → `15_1` |
| Pro 13-inch 2018/2019, 4 Thunderbolt ports | `MacBookPro15,2` → `15_2` |
| Pro 15-inch with Radeon Pro Vega | `MacBookPro15,3` → `15_3` |
| Pro 13-inch 2019, 2 Thunderbolt ports | `MacBookPro15,4` → `15_4` |
| Pro 16-inch 2019 | `MacBookPro16,1` → `16_1` |
| Pro 13-inch 2020, 4 Thunderbolt ports | `MacBookPro16,2` → `16_2` |
| Pro 13-inch 2020, 2 Thunderbolt ports | `MacBookPro16,3` → `16_3` |
| Pro 16-inch 2019 | `MacBookPro16,4` → `16_4` |

Unknown models are rejected before any privileged action.

## System integration

`install.sh` is intentionally a visible terminal workflow. It verifies that a
T2-enabled kernel exposes `t2bce_audio`, installs the Arch dependencies
including `alsa-ucm-conf`, then obtains the T2 UCM profiles from the KAIT2EN
source checkout itself. This avoids depending on `apple-t2-audio-config`, an
external package that is not present in every Arch repository. It then builds
the upstream DSP graph and Bankstown, installs the WirePlumber and udev rules
and enables the daily `kait2en-dsp-update.timer`. Existing UCM files are backed
up under `/var/lib/kait2en-dsp` before being updated.

The generated profile target adapts to both the legacy `Audio` ALSA card id and
the upstream model-specific `t2-*` id. Speaker and internal-microphone
profiles are activated only for the matching UCM Speaker/Mic nodes; headphones
and headset microphones remain untouched. Reboot after the first installation
so the udev card-id rule can take effect cleanly.

On supported T2 Macs the installer also applies a dedicated PipeWire stability
override using a 1024-frame quantum. This prevents recurring ALSA underruns that
can cause clicks or short dropouts on the internal speakers. The panel and
diagnostic command report the active quantum, and the uninstaller removes only
the override owned by KAIT2EN.

The plugin also includes a repair action for the known failure mode where a
user-local Bankstown checkout duplicates the system LV2 plugin.

The system uninstaller removes only the integration files it owns. It keeps
the shared `AppleT2` UCM files in place so removing the plugin cannot break
other T2 audio components; the pre-update copies remain available in the
backup directory.

The panel exposes both the optional 8-band user EQ and the KAIT2EN
virtual-bass amount. The latter is stored separately from upstream graphs and
reapplied by the system updater after a profile update.

## Languages

The panel supports English and Polish. English is the default for all other
locales; Polish is selected automatically when the desktop locale starts with
`pl_`. Diagnostic output follows the same locale where it provides its own
messages.

## Development

Install it with the repository URL:

```sh
omarchy plugin add https://github.com/BobSon85/kait2en-omarchy.git --enable
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

Before a real installation, run the non-destructive preflight check:

```sh
./scripts/install.sh --check
```

The check validates the running Arch/T2 environment and model without
installing packages, changing PipeWire, or writing system files. The full
installer remains an explicit terminal workflow because it needs `sudo`.

## License

Plugin code is GPL-3.0-or-later. KAIT2EN and third-party component notices will
be documented before publication.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the attribution and
license handling of the downloaded components.
