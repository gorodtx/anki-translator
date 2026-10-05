# Translator · Внедрение macOS Mono

Брендинг внедрён в исходники и установленный build 305. Проверены обе сборки, упаковка
ресурсов, strict codesign, Finder/Get Info, локальный DMG и положительный backend ping.
**B06/B08 остаются открыты:** пользователь открыл Settings, но CUA всё ещё не адресует
окно; последний собственный trust report нового app — `false`, а ручная reauthorization,
⇧⌘T translation и History ещё ожидают пользовательского результата.

Дата: 05.10.2026. Исполнитель: `Translator-Brand-macOS`, терминал
`term_efe4aa70-1e38-42f6-8007-cd19a98aa55c`, task `task_da34bd59e066`, dispatch
`ctx_55a74ec40a6c`. Native Codex ID `01a10c36-041c-73d3-b4a5-b96090075d82`
подтверждён собственным `CODEX_THREAD_ID`, разобранным как UUID, и собственной записью
Orca search. Точная команда возобновления:

```sh
cd '/Users/den/Documents/dev/selection_translator_anki' && codex resume '01a10c36-041c-73d3-b4a5-b96090075d82'
```

Shared checkout: `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`,
base/HEAD на старте `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Git index,
commit/push и остальные design assets принадлежат координатору. Исполнитель не выполнял
staging, commit, push или публичный релиз.

## Исходники и сборка

Все пять подготовленных native файлов совпали с SHA256 в `design/delivery-verification.json`.
Artwork сохранён: AppIcon `ca1f8328df7395ca05066fbeff9449e6ead4df2dbfefecf4c473ca7f43e3a4b3`,
`icons/main_icon.png` `0730efa3ee32ea72729785ce6b04ebe7bb9b975f0507ef61b79a00fea444c851`.
ICNS имеет десять representations: `ic04/ic11/ic05/ic12/ic07/ic13/ic08/ic14/ic09/ic10`;
16@2x и 32@1x сохраняют свою исходную оптическую геометрию. Codec и готовые PNG не менялись.

`TranslatorApp.swift` использует явные bitmap representations 28×18, 56×36 и 84×54 px,
все с логическим размером 28×18 pt. `NSImage.isTemplate=true` и `.renderingMode(.template)`
передают системе alpha-маску непрерывной линии. PNG скопированы без изменений из
`design/translator-icon/menu-bar/macOS/TranslatorMenuBar.imageset/` в `Resources/MenuBar/`.
Оба ручных сборщика копируют их до codesign; SwiftPM asset catalog не добавлялся.
При запуске голого development executable без bundle ресурсов используется системный
fallback и записывается диагностика. В проверенных bundles присутствуют все три PNG.

```sh
TRANSLATOR_APP_BUILD=305 macos/Translator/scripts/build_app.sh release
TRANSLATOR_APP_BUILD=305 scripts/build_macos_app.sh --out /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full --skip-swift
codesign --verify --deep --strict macos/Translator/.build/Translator.app
codesign --verify --deep --strict /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full/Translator.app
```

Оба пути: **PASS**, version `0.3.0`, build `305`, bundle ID `com.translator.desktop`,
`LSUIElement=true`, accessory policy сохранена. Подпись полной сборки ad-hoc,
CDHash `5dae68c3706841f4366dcf6d820e0ece6063a230`; Developer ID и notarization отсутствуют.
Build identity: revision `6931540ad76a6ab7a5abe70d49c513e93e881d36` плюс незакоммиченные
изменения ресурсов и source SHA256 `c68e5ef625ddcd4e9ff73eb18760df75bf37dd118e86420bca0f116f276ff99c`.
Revision не выдан за полностью committed состояние. Декодирование ICNS через Apple
`iconutil` выполнено отдельно от проверки контейнера.

Логи, bundle и проверки находятся вне repo в
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/`:
`short-build.log`, `full-build.log`, `resource-checks.json`, `full/Translator.app`.
Сборка полного bundle использовала уже построенный Swift release; backend функциональность
и installer policy не менялись. Перезапуск старых VM/DB тестов, downloads и uploads не выполнялся.

## Установка и сохранность

До замены проверен `/Applications/Translator.app`: build `304`, ad-hoc,
CDHash `0c68ccaa11c25394a315a7f36ebe4bced537e088`, native SHA256
`495ff7ab0b786017fd0e8a23c587401c84f0f7b4f132b00ca31b6eddac055ea2`.
Strict codesign старого app: **PASS**. Точная восстановимая копия —
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/Translator-build304.app`;
её strict codesign тоже **PASS**. Предыдущая identity, config/history hashes и metadata трёх
SQLite записаны в `previous304.json`. DB bytes не копировались и не перехешировались.
Фактический shortcut из preferences: `hotKey=17:768`, **Shift+Command+T**.

После выдачи desktop GUI lock координатором старый native app закрыт через CUA `super+q`.
Прежние PID `39421` (native) и `39430` (собственный backend) проверены по точным executable
paths и уже завершились; дополнительные kill не потребовались. Новая копия подготовлена
через `ditto` в `/Applications/.Translator-brand305.app`, strict codesign проверен до
переименования. Старый оригинал перенесён наружу в `Translator-build304-original.app`,
затем staging переименован в `/Applications/Translator.app`. Копия `Translator-build304.app`
остаётся независимым первоначальным backup. Пользовательские каталоги не заменялись.

Новый установленный native SHA256:
`a9e51ac83baf98c64b4835e9ce0e493447ba0107b60700621b3db8a2581c753e`.
Установленный ICNS совпадает с approved hash выше; strict codesign после установки **PASS**.
Первый native PID `37501`, backend `37573`; положительный UDS `ping` вернул именно `37573`,
protocol `1`, `history_persistence=true`, три DB ready, `pending_bytes=0`,
Apple dictionary ready и Apple translation model `installed`. Это фактический runtime,
а не вывод из source/config. Команда проверки была read-only NDJSON запросом `ping` к
`~/Library/Application Support/Translator/run-app/backend.sock`; результат в `installed-ping.json`.

После первого запуска config/history SHA256 совпали с baseline, history count **1**.
Размеры и mtime трёх SQLite неизменны. DB/history/settings/Anki settings не редактировались.
Anki profile и synchronized карточки не проверялись: эта branding задача их не меняет.

## Native screenshots и текущие gates

Все UI действия выполнялись через `mcp__cua_repl`. Следующие PNG сохранены вне repo
в каталоге evidence и лично просмотрены:

| Screenshot | Результат |
|---|---|
| `previous304-general.png` | Старый Settings, shortcut ⇧⌘T, baseline до замены. |
| `installed305-finder.png` | **PASS**: новая иконка у Translator в Applications. |
| `installed305-get-info.png` | **PASS**: правильный preview иконки, version 0.3.0, Applications, 59,6 МБ. |
| `local305-dmg-finder.png` | **PASS**: mounted local DMG содержит новую иконку app и Applications link. |
| `installed305-desktop-dark.png` | Белый захват слоя Finder Desktop; **не является** menu-bar evidence. |

Локальный DMG создан исключительно под evidence, существующий public artifact не затронут:

```sh
scripts/package_macos_dmg.sh /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full/Translator.app /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/local-dmg
hdiutil attach -readonly -nobrowse -mountpoint /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/dmg-mounted /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/local-dmg/Translator-0.3.0-macos-arm64.dmg
```

`hdiutil verify`, SHA256 check, mounted strict codesign и побайтовое сравнение mounted ICNS
с installed ICNS: **PASS**. SHA256 DMG
`b6c9751106a5c0dac514e00261d4174f0d5b7ad662a323bc35503ccefac8ff26`.
Это локальная сборка 305 с прежним version 0.3.0, а не новый public release.

CUA `getApp('/Applications/Translator.app')` запустил app, но его начальный AX state
вернул `timeoutReached`: accessory app не имеет открытого окна. Аналогичная попытка
SystemUIServer тоже дала timeout. Bundle-ID selection видит несколько backup app с тем же
ID и сообщает ambiguity; backups не запускались. Попытки ограничены, продуктовый workaround
не добавлялся. Реальные menu open, light/dark/Retina, About, новый Settings и translation/history
UI на этом checkpoint остаются **UNKNOWN**, не выданы за PASS. Координатору отправлен запрос
на поддерживаемый путь наблюдения или точное ручное открытие Settings пользователем.

В 13:32 UTC собственная `AppModel.refreshAccessibilityTrust()` новой сборки записала
`accessibilityTrusted=false`; текущий source использует authoritative
`AXIsProcessTrustedWithOptions(prompt:false)`. `accessibilityPermissionRequested=true`,
shortcut сохранён. Текущий Accessibility grant **не сохранён** после смены ad-hoc identity;
это ожидаемая, но реально проверенная зависимость от пользователя. Shortcut translation
**BLOCKED** до ручной reauthorization; TCC reset, auto grant и изменения trust logic не выполнялись.
Блокер отправлен координатору в том же ходе.

В 13:34 UTC координатор запросил у пользователя открыть новое menu → Settings и оставить
окно открытым; разрешение на ручную reauthorization пока ожидается. Внешний screencapture/AX
automation не разрешён, существующий debug-window hook не используется как замена обычной
приёмке. Build 305 не перезапускается и не переподписывается. Implementation/resources/README
заморожены для поимённого commit координатора; checksums в `source-freeze.sha256`.
После Root-only commit `db03fd9` base693 остаётся ancestor; это не меняет bytes установленного app.
Own DMG mount `disk4` снят после проверки; локальный файл DMG и screenshots сохранены.

В 13:38 UTC координатор передал фактический ответ пользователя **«Settings открыты»**
на просьбу открыть новое menu → Settings. Это пользовательская приёмка действия, а не
результат debug-hook. Однако последующие CUA выбор точного installed app path, выбор по
display name и один retry после `js_reset` опять дали `timeoutReached`. CUA inventory
не показывает Translator при живом exact PID `37501`; после пользовательского открытия
это отдельный blocker addressability инструмента. Нельзя заключать, что пользователь
не открыл окно, и нельзя выдавать его ответ за лично просмотренный screenshot.

В 13:39 UTC native/backend PID и пути оставались теми же, `accessibilityTrusted=false`
в актуальных preferences. CUA helper, shared runtime, приложение и подпись не менялись;
`js_reset` только очистил локальные JS bindings. Дополнительные слепые retries остановлены,
blocker повторно отправлен Root. Личные new Settings/About/menu/light-dark/Retina/translation/
history screenshots всё ещё **UNKNOWN**, shortcut capture **BLOCKED** из-за grant.

В 13:45 UTC координатор выполнил normal native commit
`bb8ed09bdbe407e6b159abaaf79d84127dbedd06` для 12 frozen implementation/resource/README
paths, без этого отчёта. Исполнитель лично проверил `git log`, `git show --stat`, ancestry
base693 и `shasum -a 256 -c source-freeze.sha256`: **12/12 PASS**. Поэтому commit включает
именно проверенные исходники. Installed 305 не пересобирался, не переподписывался и не
перезапускался; его identity продолжает честно ссылаться на base693 плюс source digest.
Ruff/format/mypy и Swift release gates этого коммита — отдельный **отчёт координатора**,
не повторный запуск исполнителя. Source commit не закрывает pending installed UI/grant gate.
GUI lock с 13:41 UTC передан Root; исполнитель не выполняет desktop input до новой выдачи lock.

## Замороженный checkpoint · 13:52 UTC

По запросу Root от 13:51 UTC этот отчёт заморожен для отдельного evidence commit.
Последние измеренные installed PID/trust — 13:39 UTC после фактического пользовательского
открытия Settings в 13:38 UTC: native `37501`, backend `37573`, trust `false`, shortcut
`17:768`. Более позднее значение без повторного измерения не заявляется. Последняя
подтверждённая source revision — native commit `bb8ed09bdbe407e6b159abaaf79d84127dbedd06`.

Вопрос пользователя о ручной reauthorization в General → Open System Settings…,
обычном ⇧⌘T переводе и Show History всё ещё pending. **Ожидание не считается ответом,
разрешением или PASS.** CUA-only blocker, unknown menu/light-dark/Retina/About/new Settings
visual gates и blocked shortcut capture сохранены в учёте. Root может доставить проверенные
source/resources и проверить CI; это не закрывает B06/B08. `worker_done` на этом checkpoint
не отправлен. Новые фактически измеренные или прямо сообщённые пользователем результаты
будут добавлены отдельной датированной записью после commit этого checkpoint.

Build 305, его подпись и пользовательские данные остаются неизменными. GUI lock принадлежит
Root. Доступные evidence artifacts сохранены вне repo, own DMG mount снят; source и данные
не подвергаются повторным тестам, downloads, uploads или cleanup пользовательских каталогов.

## Журнал ограничений

В 13:19 UTC `penpot-tool doctor` и `overview` вернули `fetch failed`. Координатор отдельно
сообщил свой PASS в 13:16 UTC с правильными file/page IDs; это другой запуск.
Shared Penpot runtime, VM, browser и autostart не менялись. Утверждённых локальных exports
достаточно для интеграции. Исторические CONTINUE и Claude AppIcon instructions сверены
с текущим handoff: прежняя рекомендация общего iconutil генератора уступает утверждённому
native codec; прежнее ограничение keep304 явно снято пользователем только для этой задачи.
