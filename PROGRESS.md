# KaiT2en Omarchy plugin — stan prac

Ostatnia aktualizacja: 2026-09-17

## Aktualny stan

- Plugin działa lokalnie w Omarchy.
- Aktywny model: MacBook Air 8,1 / T2.
- KaiT2en DSP jest obecnie domyślnym wyjściem audio:
  `audio_effect.t2-81-speakers`.
- EasyEffects został usunięty.
- PipeWire działa z quantum `1024`, co usunęło wcześniejsze przycięcia audio.
- Plugin ma przełącznik wyjścia między KaiT2en DSP i wyjściem natywnym.

## Ostatnio naprawiony problem

Po przełączeniu na wyjście natywne WirePlumber usuwa filtr KaiT2en. Powrót do DSP wymaga więc ponownego utworzenia filtra. Pierwsza wersja przełącznika wykrywała sink zbyt wcześnie i mogła zgłosić sukces, mimo że domyślne wyjście nadal było natywne.

Obecna wersja skryptu:

- wykrywa brak sinka DSP,
- restartuje tylko WirePlumbera,
- czeka na ponowne utworzenie filtra,
- weryfikuje faktyczny `Default Sink`,
- ponawia aktywację, jeśli PipeWire/WirePlumber trafią na wyścig inicjalizacji,
- przenosi istniejące strumienie audio do wybranego wyjścia.

Test natywne → DSP zakończył się poprawnie. Powrót może potrwać kilka sekund i chwilowo wyciszyć audio.

### Omarchy Spotify po zmianie wyjścia

Po przełączeniu wyjścia backend `omarchy-spotify.service` może stracić połączenie z PipeWire:

```text
Audio Sink Error On Write: PulseAudioSink Connection terminated
```

Jest to skutek restartu/reinicjalizacji grafu audio, a nie błąd KaiT2en. Zwykła aplikacja Spotify działała poprawnie. Omarchy Spotify wznowił działanie po otwarciu lokalnego odtwarzania i naciśnięciu Play.

Przy przyszłych testach po zmianie sinka należy sprawdzić lokalny odtwarzacz Omarchy Spotify i w razie potrzeby ponownie wybrać `This computer` oraz nacisnąć Play.

## Ważne pliki

Repozytorium:

- `scripts/set-output-mode.sh` — przełączanie KaiT2en/native,
- `scripts/status.sh` — status pluginu i tryb wyjścia,
- `scripts/diagnose.sh` — diagnostyka,
- `scripts/update-system.sh` — instalacja/aktualizacja DSP i stabilizacji PipeWire,
- `Panel.qml` — główny panel pluginu,
- `BarWidget.qml` — widget na pasku Omarchy,
- `manifest.json` — manifest pluginu.

Aktywna instalacja:

`~/.config/omarchy/plugins/kait2en.audio/`

Skrypt przełączania jest aktualizowany również w aktywnej instalacji, nie tylko w repozytorium.

## Wykonane funkcje pluginu

- panel zgodny z motywem Omarchy,
- dynamiczne kolory i reakcja na zmianę motywu,
- język angielski domyślnie oraz polski dla polskiego locale,
- status DSP, mikrofonu, aktualizacji i PipeWire,
- diagnostyka w floating centered window, zamykana klawiszem `Q`,
- przycisk odświeżania bez skakania layoutu,
- ikona widgetu z kolorami aktywny/błąd,
- obsługa cyklu życia popoutu Omarchy,
- opcjonalny equalizer użytkownika,
- automatyczna aktualizacja KaiT2en przez systemd timer,
- obsługa wielu modeli MacBooków w macierzy modelu.

## Walidacja

Ostatnio przeszły:

```text
EQ generation and Flat disable: OK
MacBook model matrix: OK
publication structure and secret scan: OK
plugin manifest and shell scripts: OK
git diff --check: OK
```

## Stan publikacji

- Repozytorium GitHub: `https://github.com/BobSon85/kait2en-omarchy`
- GitHub CLI jest skonfigurowane jako `BobSon85`.
- Ostatnie poprawki przełączania wyjścia są lokalne i nie zostały jeszcze wypchnięte na GitHub.
- Przed publikacją trzeba wykonać końcowy test UI, commit, push oraz ewentualnie aktualizację manifestu/wersji.

## Następny punkt pracy

1. Przetestować przełącznik z poziomu panelu Omarchy, nie tylko skryptem.
2. Sprawdzić, czy po przełączeniu działający Spotify/Telegram wracają na wybrane wyjście.
3. Obejrzeć `git diff` i zdecydować, które zmiany wchodzą do kolejnego commita.
4. Dopiero po potwierdzeniu użytkownika wykonać commit i push.

## Szybki powrót do tematu

W nowej sesji wystarczy przeczytać ten plik i sprawdzić:

```bash
cd /home/krzysiek/kait2en-omarchy
git status --short
./tests/validate-scripts.sh
~/.config/omarchy/plugins/kait2en.audio/scripts/status.sh
pactl info | grep 'Default Sink:'
```
