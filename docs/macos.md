# Translator для macOS

Приложение рассчитано на Apple Silicon и macOS 26 или новее. В `Translator.app` находятся native SwiftUI/AppKit оболочка, Swift helper, CPython 3.13 и зависимости backend. На компьютере пользователя не нужны terminal, `uv`, внешний Python, репозиторий или Command Line Tools.

Опубликован [предварительный выпуск v0.3.0](https://github.com/gorodtx/selection_translator_anki/releases/tag/v0.3.0): build 295, Apple Silicon, macOS 26+, DMG 25 229 806 bytes. SHA256: `dd7249f9b7061a83176e52f15e0a9e6532bbddab4c75cf70041fd603688292ea`. Размеры и SHA256 всех восьми assets совпали; DMG скачан без авторизации, смонтирован, оба встроенных launcher прошли проверку. Базы SQLite объёмом 1,9 GB повторно не публикуются.

**Подписанная публичная установка остаётся BLOCKED (D05).** Apple Developer Program отсутствует, у текущего DMG ad-hoc подпись. Обычное открытие скачанного приложения через Gatekeeper не подтверждено. В tag CI пять проверок исходников, native-компонентов и упаковки завершились успешно; notarization остановилась на обязательных signing inputs. Developer ID, notarization, stapling и проверка Gatekeeper остаются условиями полноценной публичной доставки. [Прогресс доставки](release/PROGRESS-DELIVERY.md), [историческая приёмка](release/PROGRESS-TRANSLATOR1.md).

## Установка

После появления подписанного и нотарифицированного релиза:

1. Скачать `Translator-<version>-macos-arm64.dmg` и открыть его в Finder.
2. Перетащить `Translator.app` на значок `Applications` в окне DMG.
3. Открыть Translator из Applications, затем извлечь DMG.

В образе находятся приложение и ссылка `/Applications`. `install_macos.sh` в этом сценарии не используется. Приложение запускает backend из собственного bundle и соединяется с ним по Unix socket; положительный `ping` подтверждает готовность.

Первый запуск показывает существующие шаги Settings. Accessibility нужна для чтения выделения через глобальную клавишу; разрешение выбирает пользователь в System Settings. Services доступен без этого разрешения. Словари Apple и языковая пара проверяются отдельно: наличие системного API не означает установленную модель. Загрузка пары выполняется существующим SwiftUI `.translationTask`/`prepareTranslation()`; headless helper самостоятельно модель не скачивает. Open at login — отдельный пользовательский выбор через `SMAppService.mainApp`; drag install не создаёт отдельный LaunchAgent backend.

Offline базы не входят в DMG. Загрузка в Settings использует packaged `db-bundle.lock.json`, показывает объём отсутствующих файлов, сохраняет partial download и проверяет SHA256 до переноса на окончательное имя. Для полностью пустого хранилища текущий lock содержит **1 896 546 304 байта**. Отсутствие баз не препятствует запуску backend и не означает готовую offline конфигурацию.

## Архитектура и владение процессами

```text
Выделение / hotkey / Services
             │
             ▼
Translator.app — SwiftUI/AppKit, LSUIElement
             │ Unix socket, NDJSON
             ▼
TranslatorBackend → TranslatorEngine — embedded CPython
             ├── общая translate_logic, history, cache, Anki
             └── TranslatorLookup — Swift helper
                    ├── Dictionary Services
                    └── Translation.framework
```

Оболочка отвечает за ввод, окна и pasteboard. Backend отвечает за перевод, историю и Anki; GTK presentation не импортируется в macOS daemon. `TranslatorEngine -> ../python/bin/python3.13` и `TranslatorLookup -> apple-lang-helper` — ссылки внутри bundle. Они сохраняют исходные бинарники и дают узнаваемые имена в Activity Monitor.

`BackendBootstrap` сначала отправляет `ping` и проверяет protocol 1, положительный PID и boolean capability `history_persistence: true`. Совместимый существующий backend используется без смены владельца; Quit клиента его не завершает. Живой несовместимый или не отвечающий listener считается занятой точкой: приложение не заменяет его, а показывает причину в Settings. Исторический daemon с тем же номером protocol, но без этой capability, не считается совместимым.

При отсутствии listener приложение запускает `Contents/MacOS/TranslatorBackend` через `Process`, передаёт socket и собственный `TRANSLATOR_PARENT_PID`, пишет логи вне bundle и ждёт готовности до 30 секунд. Собственный child может быть автоматически перезапущен три раза. После исчерпания попыток существующая Start Backend позволяет попробовать снова.

Native `TranslatorBackend` и резервный shell launcher передают embedded Python флаг `-P` перед `-m`: текущая рабочая папка не подменяет packaged modules. `PYTHONPATH` задаёт только каталоги ресурсов приложения. Source tests и запуск обоих entrypoints из папки с намеренно конфликтующим `desktop_app` проверяют этот контракт; проверка выполняется `scripts/check_macos_bundle_runtime.py` с пустым профилем и минимальным PATH. На целевой машине эта developer проверка не нужна.

Quit завершает только сохранённый собственный `Process`: SIGTERM, ограниченное ожидание, при необходимости SIGKILL того же PID. Opt-in daemon watcher сравнивает фактический parent PID и штатно закрывает daemon при смерти владельца, включая SIGKILL оболочки. Внешний LaunchAgent без parent marker сохраняет прежнее поведение. Одно имя процесса не является доказательством владения.

## Данные и изолированные проверки

| Данные | Обычный путь |
| --- | --- |
| Настройки и история backend | `~/Library/Application Support/Translator` |
| Offline базы | `~/Library/Application Support/Translator/db` |
| Socket обычного приложения | `~/Library/Application Support/Translator/run-app/backend.sock` |
| Логи | `~/Library/Logs/Translator` |
| Native preferences | domain приложения, `UserDefaults` |

Обычный launcher использует `run-app`; исторический external daemon сохраняет `run`. Это отделяет запуск нового приложения от занятого legacy listener. История backend записывается через async atomic persistence и восстанавливается при новом запуске. Изолированная migration/restart проверка сохранения одной записи пройдена; работа с существующей синхронизированной коллекцией Anki требует отдельной functional acceptance и не следует из distribution checks.

Developer overrides: `TRANSLATOR_CONFIG_DIR`, `TRANSLATOR_DB_DIR`, `TRANSLATOR_RUNTIME_DIR`, `TRANSLATOR_SOCKET_PATH`, `TRANSLATOR_LOG_DIR`. `DB_DIR` задаёт единственное место поиска баз. Приоритет socket: явный socket, явный runtime directory, системный default. `CONFIG_DIR` отдельно от socket и не переносит runtime автоматически. AF_UNIX ограничен 103 UTF-8 байтами. `socket.with_suffix(".pid")` даёт разные markers произвольным socket; нормальный `backend.sock` сохраняет `backend.pid`.

`TRANSLATOR_DEFAULTS_SUITE` включает отдельный native domain для first-run, Settings pane, hotkey и Accessibility flag. В этом режиме восстановление/автосохранение frames через стандартный domain NSWindow отключено. Обычный запуск сохраняет прежние preferences и геометрию. Перенаправление `HOME` не изолирует per-user launchctl, TCC или login items: проверки используют именованные пути/domains, собственные PID и volumes.

## Обновление, откат, удаление

Для DMG-установки пользователь завершает Translator, заменяет приложение в Applications новой копией и запускает её. Данные и offline базы находятся вне app bundle. Для ручного отката нужно сохранить прежнюю копию до замены, завершить новую и вернуть прежнюю по тому же пути. Совместимость данных со всеми историческими версиями проверяется отдельно; замена двух локальных bundle не доказывает её автоматически.

Удаление приложения после Quit сохраняет Application Support и Logs. Удаление данных и отключение ранее выбранного Open at login — отдельные пользовательские действия.

`scripts/install_macos.sh` остаётся developer/legacy маршрутом с `current`, `previous`, staging, rollback и LaunchAgent. Обычному пользователю он не нужен. Account-home guard fail-closed при ошибке `dscl`; restart/remove проверяют exact executable path и используют exact PID, оставляя одноимённые development/downloaded копии в покое. Настоящая пользовательская legacy установка не менялась в distribution acceptance.

## Протокол

Single source: `desktop_app/platform/macos/ipc/protocol.py`; UTF-8, один JSON object на строку.

| Направление | Формат |
| --- | --- |
| Request | `{"id": <str\|int>, "method": "...", "params": {...}}` |
| Success | `{"id": ..., "ok": true, "result": {...}}` |
| Error | `{"id": ..., "ok": false, "error": {"code","message"}}` |
| Event | `{"event": "...", "payload": {...}}` |

Methods: `ping`, `translate`, `cancel`, `close`, `history.list`, `history.select`, `examples.refresh`, `copy_all`, `anki.status`, `anki.decks`, `anki.select_deck`, `anki.create_model`, `anki.prepare_upsert`, `anki.apply_upsert`, `anki.model_fields`, `anki.model_names`, `engines.refresh`, `db.download`, `db.cancel`, `settings.get`, `settings.save`, `shutdown`. Events: `translation.state`, `notification`, `anki.availability`, `db.progress`. Swift literals сравниваются с Python в CI.

`ping.engines` разделяет availability, пользовательские `enabled` toggles и `stale`. Первый probe ожидается до установленного лимита; aged snapshot обновляется в фоне, `engines.refresh` ждёт новое состояние. `installed`, `supported`, `unsupported`, `unavailable` не смешиваются с выбором пользователя.

`ping.db` содержит booleans трёх баз, `sources` фактических расположений, `dir` места загрузки и `pending_bytes`. Непрочитанный lock означает unknown, а не нулевую загрузку. Socket node не означает готовый listener: healthcheck спрашивает `ping` и не переводит текст, чтобы не загрязнять историю.

`settings.save` принимает шесть boolean source keys: `apple_dictionary`, `apple_translation`, `google`, `cambridge`, `offline_examples`, `definitions_pack`. Неверные keys/типы отвергаются без изменения файла; loader старых файлов остаётся lenient. Все источники могут быть выключены с понятной notification.

`anki.model_fields` возвращает `fields` и optional `error`; пустой список не доказывает неверные поля. `anki.model_names` возвращает note types. Выбор модели сохраняется настройкой; создание собственного note type — отдельное действие. Реальные add/duplicate/merge/media/custom-field проверки относятся к functional acceptance Main.

## Apple engines и исходные решения

Swift helper использует stdio NDJSON; ops: `ping`, `dictionaries`, `availability`, `define`, `text_definition`, `translate`, `shutdown`. Typed errors отсутствующей модели не превращают весь pipeline в hard failure.

Structured Dictionary Services path возвращает markup/headword/title/anchor и собирается в `LexicalInfo`; flat `DCSCopyTextDefinition` — fallback. Фильтры отделяют чужие phrasal blocks и сохраняют корректное падежное управление после `+ a/i/p`. Примеры сами по себе не становятся придуманным переводом headword. Эти решения восстановлены в [CONTEXT-TRANSLATOR1.md](release/CONTEXT-TRANSLATOR1.md).

Helper не блокирует main queue: Dictionary Services и Translation отвечают через неё. Вход stdio читается отдельно. Большие статьи требуют увеличенного stream limit; default asyncio 64 KB недостаточен. Длительный helper принадлежит backend и ограниченно перезапускается после падения.

Старые hardware timings, dictionary corpus и screenshot geometry являются историческими измерениями; они не перенесены в текущий PASS. SF/system typography, Liquid Glass, assets и native primitives сохранены. macOS не имеет пользовательского Dynamic Type control, поэтому исходный проект использует системные text styles без обещания iOS text scaling.

## Developer build

На build машине нужны Apple Silicon, macOS 26 SDK, Swift/Command Line Tools и `uv`; на целевой машине они не нужны.

```bash
uv sync --frozen --dev
uv python install 3.13
scripts/build_macos_app.sh --out dist
scripts/package_macos_dmg.sh dist/Translator.app out
uv run --frozen ruff check .
uv run --frozen python -m mypy
uv run --frozen python -m pytest -q
```

Format gate проверяет изменённые Python files через `uv run --frozen ruff format --check`. Swift tests запускаются соответствующими `scripts/swift-test.sh`, учитывающими Swift Testing из Command Line Tools.

Builder требует настоящие shell/backend/helper binaries, embeds CPython/dependencies, заранее компилирует bytecode, исключает внешние symlinks и offline SQLite, сохраняет `build-info.json` и подписывает bundle. Manifest содержит revision, SHA256 точного исходного набора, arch/minimum OS/version/build, resolved dependencies, database lock и unsigned Python binary identity. Изменение исходников во время сборки останавливает source guard.

SHA256 DMG проверяет bytes конкретного artifact. Повторяемый build recipe и checksum не означают bit-for-bit одинаковый DMG: подпись/timestamp, filesystem metadata и текущий неполный transitive dependency lock меняют bytes. Manifest сохраняет реально разрешённые версии. После runtime/toolchain bundle должен оставаться неизменным; `PYTHONDONTWRITEBYTECODE=1` задаётся при собственном запуске backend.

## CI и публичная подпись

Workflow содержит gates, Linux parity, Swift helper/shell, bundle и tag-only notarization. Bundle job создаёт DMG с app version, legacy ZIP и checksums. Tag version берётся из `vX.Y.Z`; полная Git history сохраняет build count.

Один `scripts/sign_macos_app.sh` обслуживает локальный builder и CI: все Mach-O, включая `TranslatorBackend`, подписываются до outer app. Developer ID включает hardened runtime и timestamp. Ошибка nested signing останавливает pipeline; `codesign --verify --deep --strict` проверяет результат.

Tag notarization требует все шесть inputs: `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`, `APPLE_SIGNING_IDENTITY`, `APPLE_CERT_BASE64`, `APPLE_CERT_PASSWORD`. Их отсутствие завершает public gate ошибкой BLOCKED вместо успешного пропуска.

Native `SecPKCS12Import` получает certificate password вне argv. `notarytool store-credentials` получает app-specific password через documented secure prompt в echo-disabled PTY и сохраняет его в temporary keychain; submit использует keychain profile. Unit tests проверяют synthetic input/redaction и fail-closed behaviour. Реальная Apple authorization adapter ещё не проверена из-за отсутствия аккаунта.

App и DMG отдельно должны получить явный status `Accepted`, пройти stapling/validation и Gatekeeper assessment. ZIP/DMG checksums пересчитываются после подписи и stapling. Signing material удаляется в `always()` cleanup. Public upload/release publishing в текущей задаче не выполнялись.

Protected GitHub inventory 03.10.2026 показал пустые repository-scoped Actions variable/secret names; environment/org/effective-job inputs остаются unknown. API access не доказывает push auth, CI execution или скачанное приложение. Gatekeeper downloaded notarized DMG проверяется отдельно после появления легитимного Developer ID/account и разрешения на публикацию.

## Границы подтверждения

Source tests, local seal, actual embedded backend под Foundation harness, native snapshot и real SwiftUI/Anki interaction — разные измерения. Mock screenshot или исторический отчёт не заменяют текущий запуск. Полный coverage sanitized историй, current commands/results/SHA256 и unresolved items находятся в release CONTEXT/PROGRESS и внешнем distribution evidence root. Visual redesign в этом проходе не выполнялся.

Измеренная приёмка 04.10.2026: sourcec248d6/DMG662cbf64 в собственной чистой VM прошёл обычную Finder installation/update, автоматический TextEdit Services, native UI загрузку трёх pinned DB/Apple pair, холодный первый EN→RU, History/restart и новый Services перевод при блокированной внешней сети. Это локальный ad-hoc artifact и реальный native GUI с синтетическим текстом; публичная подпись/notarization/download Gatekeeper, физический drag/hotkey и remote CI остаются отдельными gates. Точный scope, исходные JPEG/SHA и preserved fixture rollback assertion/cleanup результаты находятся в [P028](release/PROGRESS.md). Дизайн не менялся.
