# Разработка и техническая документация Translator

Продуктовый сценарий, актуальный macOS download и ограничения выпуска — в [README](../README.md). Здесь сохранены полезные технические сведения прежнего README; устаревшие утверждения о размере bundle, LaunchAgent-first установке и модели перевода заменены текущими источниками. Native интерфейс/engine в Presentation Layer не изменяются.

## Общая архитектура

`translate_logic` и `desktop_app/application` общие для обеих платформ. GNOME использует GTK4/libadwaita + D-Bus; macOS — SwiftUI/AppKit shell и Unix-domain socket Python daemon с NDJSON RPC. Общий перевод, примеры и Anki integration не форкаются в сайте. В приложении используются Dictionary Services и отдельный Apple Translation helper; network providers optional. Условие наличия языковых ресурсов проверяется отдельно от enabled setting.

macOS bundle содержит native bootstrap, CPython3.13, backend/dependencies и `apple-lang-helper`. Целевой пользователь не устанавливает uv/Python/repository. SQLite в bundle не входят: Settings скачивает pinned ресурсы в shared user store и проверяет lock. Native bootstrap/lifecycle, Services, login startup и first-run подробно описаны в [macos.md](macos.md). Публичная Developer ID/notarization/Gatekeeper приёмка остаётся D05BLOCKED, пока нет Apple Developer Program.

## Разработка macOS

Build host: Apple Silicon/macOS26 SDK/Swift Command Line Tools/uv. Актуальные build/package/signing команды и manifest checks — [macos.md](macos.md), release planning — [EPIC-02](release/EPIC-02-APPLICATION.md). Для shared checkout действует ownership; не запускайте второй backend в том же пользовательском профиле во время native проверки.

```bash
uv sync --frozen --dev
scripts/build_macos_app.sh --out dist
scripts/package_macos_dmg.sh dist/Translator.app out
```

Для изолированного developer backend задайте отдельные config/data/runtime/socket paths по [macOS isolation contract](macos.md), затем:

```bash
scripts/run_backend_macos.sh
uv run python -m desktop_app.platform.macos.client ping
```

`ping` проверяет responsiveness/availability и не добавляет перевод в history. Diagnostic `translate` действительно запускает pipeline и может писать историю выбранного профиля — не использовать его как read-only healthcheck. Socket node не доказывает живого listener.

## Linux/GNOME: сохранённая поддержка

GNOME installer/runtime относится к Linux artifact и systemd/D-Bus адаптеру; текущий Presentation Layer не обещает дополнительную проверку Linux desktop. Сценарий: выделение → configured hotkey/desktop invocation → popup. Актуальные release assets и проверка SHA256 обязательны, macOS DMG нельзя использовать как Linux installer.

Developer install из checkout:

```bash
bash scripts/install.sh install
bash scripts/install.sh update
bash scripts/install.sh rollback
bash scripts/install.sh healthcheck
```

Для удаления используется `bash scripts/install.sh remove`. Installer хранит current/previous releases и управляет `translator-desktop.service`; текущие опции читать в [install.sh](../scripts/install.sh). Нельзя выполнять installer/removal на чужом активном профиле без согласования. Старый README предлагал shell download для latest; пользовательскому macOS пути терминал не нужен, поэтому эти Linux команды вынесены сюда.

Developer запуск GNOME:

```bash
uv run python -m desktop_app.main
```

Runtime Python3.13+, GTK4/libadwaita/PyGObject обеспечиваются Linux installation flow. D-Bus service/interface/method смотрите в [GNOME D-Bus adapter](../desktop_app/presentation/dbus/service.py), application flags — в [main.py](../desktop_app/main.py). Не переносите исторические keybindings в macOS demo до ручной проверки.

## Данные, конфигурация, приватность

macOS defaults: configuration directory `~/Library/Application Support/Translator` по [platform paths](../desktop_app/platform/paths.py), shared DB `~/Library/Application Support/Translator/db`, история/data и runtime/log/socket paths описаны в [macos.md](macos.md). Linux follows XDG config/data/runtime; locale and settings находятся в приложении. Не публикуйте settings/env/history как diagnostic evidence. Сетевые providers могут передавать выбранный текст внешнему сервису, когда включены; blanket claim «всегда полностью offline/private» неверен.

Pinned [db-bundle.lock.json](../scripts/db-bundle.lock.json): `primary.sqlite3`, `fallback.sqlite3`, `definitions_pack.sqlite3`, отдельный release `db-a6f07d1e1c28`,1 896 546 304bytes. Code-only release переиспользует pinned DB metadata, не пересобирает и не повторно загружает corpus. DB build — явная отдельная `--build-db` операция; старый README смешивал code и DB release paths. Текущие команды — [release script](../dev/scripts/build_release_assets.sh), [preflight](../dev/scripts/release_preflight.sh) и [release docs](release/EPIC-02-APPLICATION.md).

License repository — [LICENSE](../LICENSE). Лицензия application source/SQLite engine не заменяет provenance/лицензии corpus: текущий [DB research](presentation/RESEARCH.md) нашёл mixed sources и отсутствие per-row attribution. Публичный DB-backed web demo требует отдельной проверки прав; новая презентация не экспортирует corpus.

## Anki

Нужен запущенный Anki с AnkiConnect; выбор колоды/note type и поля проверяются отдельно. Любой add/update/merge записывает данные: developer диагностика не должна пользоваться личной collection как fixture. Настройки полей/model creation, prepare/apply RPC и acceptance — в [macos.md](macos.md) и [эпике приложения](release/EPIC-02-APPLICATION.md). Работающий backend не доказывает запись/duplicate/media в точном пользовательском профиле.

## Проверки и доставка

```bash
uv run --frozen ruff check .
uv run --frozen python scripts/check_python_format.py
uv run --frozen python -m mypy
uv run --frozen python -m pytest -q
```

Swift tests — соответствующие `scripts/swift-test.sh` в native packages. Shared Git hooks требуют normal gates и English ASCII commit titles, named staging, без hook bypass. Presentation owner не управляет index/commit/push/deploy: Root принимает exact named paths и выполняет delivery. Source/local/browser/CI/public signing/native/manual acceptance — разные gates.

## Presentation и локальный preview

Без npm install/build: [site](../site/README.md) — HTML/CSS/JS и original assets. Запуск только отдельного loopback preview:

```bash
uv run --no-project python -m http.server 8765 --bind 127.0.0.1 --directory site
```

Текущий site содержит только slot для настоящего пользовательского видео и provisional icon: [site README](../site/README.md). Исследование DB lab сохранено в [research](presentation/RESEARCH.md), но реализация приостановлена новым user steering и вынесена во внешний archive. Генерация ролика/рисованного demo отменена; пользователь готовит настоящую запись и логотип, [capture brief](presentation/VIDEO-BRIEF.md).
