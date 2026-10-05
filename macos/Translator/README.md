# Translator (macOS shell)

Native SwiftUI front end for the translator. It owns the interface and the input paths;
all translation logic stays in the Python backend, which it drives over a Unix domain
socket (`desktop_app/platform/macos/daemon.py`).

```
selection ──▶ Translator.app ──NDJSON/UDS──▶ python -m desktop_app.platform.macos.daemon
                   │                                    │
             hot key · Services · AX          existing pipeline, Anki, offline DB
```

## Layout

| Path | What it is |
| --- | --- |
| `Sources/TranslatorCore/` | Wire protocol models, NDJSON framing, hot-key model, popup geometry. No AppKit, so it is unit-testable. |
| `Sources/Translator/` | The app: IPC client, hot key, selection capture, panel, views. |
| `Tests/TranslatorCoreTests/` | 32 tests over the pure layer. |
| `scripts/build_app.sh` | Builds `.build/Translator.app` (bundle + ad-hoc signature). |
| `scripts/swift-test.sh` | `swift test` on a Command-Line-Tools-only machine. |
| `scripts/mock_backend.py` | Canned backend on the real protocol, for working without Python running. |
| `Resources/Info.plist` | `LSUIElement`, `NSServices`. |
| `Resources/AppIcon.icns` | Утверждённый Mono AppIcon с десятью оптическими representations. |
| `Resources/AppIcon.icon/`, `AppIcon-layer-sources/` | Точные слои исходного знака и подтверждённый порядок Icon Composer. |
| `Resources/CompiledAppIcon/` | Официально скомпилированный CAR, неизменённая provenance и отдельный receipt выбора. |
| `Resources/MenuBar/` | Template PNG знака «клубок → ровная линия», 28×18 pt, 1x/2x/3x. |

## Build and run

```sh
scripts/build_app.sh release      # -> .build/Translator.app
open .build/Translator.app
```

На этой машине установлен только Command Line Tools; native shell собирается через
SwiftPM. Appearance resources заранее скомпилированы официальным Xcode в отдельном
resource-only workflow. Локальная сборка не требует установки Xcode.

Знак панели загружает `MenuBarArtwork` через `Bundle.main`: каждая bitmap representation
имеет логический размер 28×18 pt, а `NSImage.isTemplate` и SwiftUI `.template` передают
выбор цвета системе. У знака прозрачный фон; подложки и тени отсутствуют. `Package.swift`
не объявляет asset catalog: оба сборщика (`scripts/build_app.sh` здесь и
`../../scripts/build_macos_app.sh`) вызывают общий `macos_bundle_manifest.py --pack-artwork`
до подписи. Он сверяет 13 compiler inputs, digest, CAR hash и receipt, упаковывает три
menu PNG, CAR, provenance и curated ICNS, затем задаёт `CFBundleIconName=AppIcon`.
Проверяется byte equality реально упакованных ресурсов; одного наличия CAR недостаточно.
Сборка завершается проверкой `codesign --verify --deep --strict`.

Системные macOS appearances используют app-owned layered CAR; fallback сохраняет
десять оптических representations и native `ic04/ic05`. Исходный `AppIcon-source.json`
скопирован byte-identically из compiler input и описывает его исторический diagnostic
статус. Текущий выбор control и проверку маленького **не запущенного** ClearDark probe
фиксирует отдельный `CompiledAppIcon/promotion-receipt.json`. Его положительный результат
не означает installed acceptance или пользовательский Accessibility grant.

Для обновления CAR служит `.github/workflows/macos-icon-assets.yml`: обычный ручной запуск
компилирует production input; `diagnostic_batch=true` собирает две изолированные пробы.
Workflow не подписывает, не устанавливает и не публикует приложение. Artwork и immutable
compiler provenance не перезаписывают после проверки; последующий выбор записывают
отдельным receipt. Global theme, icon cache и TCC не меняют ради отображения.

`TRANSLATOR_APP_BUILD` задаёт локальный номер сборки в обоих путях; без него используется
число коммитов. Короткая сборка содержит native shell, полная — также backend и Python
runtime. Устанавливайте полную сборку. Bundle ID `com.translator.desktop`, `LSUIElement`
и accessory policy сохраняются. Источники AppIcon, оптическая геометрия и native `ic04/ic05`
находятся в `../../design/translator-icon/`; существующие генераторы только копируют или
упаковывают утверждённые exports. Новая сборка ресурсов не требует генерации логотипа.

Tests:

```sh
scripts/swift-test.sh
```

The wrapper exists because Command Line Tools ship Swift Testing in
`/Library/Developer/CommandLineTools/Library/Developer/Frameworks` without telling SwiftPM
about it; plain `swift test` fails with "no such module 'Testing'". XCTest is absent from
Command Line Tools entirely, so tests use Swift Testing only.

## Developing without the Python backend

```sh
python3 scripts/mock_backend.py --socket /tmp/translator-mock.sock
TRANSLATOR_SOCKET_PATH=/tmp/translator-mock.sock \
  TRANSLATOR_DEBUG_TEXT="bank" \
  TRANSLATOR_DEBUG_WINDOW=settings \
  .build/Translator.app/Contents/MacOS/Translator
```

The mock answers every method with canned data and reproduces the two-phase timing
(partial after 150 ms, final after 650 ms). `--fail-anki` makes it report AnkiConnect as
unreachable, which is the path worth checking before shipping any Anki change.

`TRANSLATOR_DEBUG_TEXT` opens the popup on that text at launch and `TRANSLATOR_DEBUG_WINDOW`
(`settings` | `history` | `anki`) opens one window, so the UI can be driven without a
selection or a shortcut.

## Three ways to start a translation

1. **Services menu** — "Translate with Translator" appears on any selected text.
   Declared as `NSServices` in `Info.plist`. Needs no permission at all, and the user can
   bind their own shortcut to it in System Settings › Keyboard › Keyboard Shortcuts › Services.
2. **Global shortcut** (default ⌥⌘T) — Carbon `RegisterEventHotKey`, which is the only
   API that still delivers a system-wide shortcut with no TCC prompt.
3. **Reading the selection directly** — Accessibility (`AXSelectedText` of the focused
   element), falling back to a synthetic ⌘C that saves and restores the user's pasteboard.
   This is the only path that needs the Accessibility grant; without it the shortcut says
   so and points at the settings pane.

The three-finger "Look Up" gesture cannot be intercepted: it is wired to the system's own
Look Up service and a third-party process can neither take it over nor suppress the system
popover. The Services entry is the closest equivalent that actually works.

## Design notes

Everything is a spring, because everything can be interrupted: a partial result lands while
the panel is still animating in, and the user can dismiss it mid-flight. Fixed-duration
transitions would have to finish first.

- `Motion` holds the tokens. Critically damped (`dampingFraction: 1.0`) by default;
  a little overshoot only for the popup's arrival, which follows a physical gesture.
- `GlassSurface` is the one place that decides between Liquid Glass and an opaque
  material. Under Reduce Transparency it swaps to `.background` plus a hairline border,
  so nothing depends on translucency for legibility. Inner sections never stack a second
  translucent layer; they use a low-opacity fill.
- Reduce Motion shortens every animation to a cross-fade rather than removing feedback.
- The popup is a `.nonactivatingPanel`, so the user's app stays frontmost and their
  selection stays selected while they read the translation.
- The panel grows downward from a fixed top-left corner as partial becomes final, so the
  text the user is already reading does not move under them.

## Not done here

- Apple's translation model download uses `.translationTask` + `prepareTranslation()` in
  the settings pane. A headless process cannot request the download; `canRequestDownloads`
  is false outside SwiftUI.
- Notarisation needs an Apple Developer Program identity. The build script signs ad-hoc,
  which works locally and trips Gatekeeper on another machine.
