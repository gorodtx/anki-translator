# Translator · Внедрение macOS Mono

Брендинг внедрён в исходники; окончательный build **306** установлен в
`/Applications/Translator.app` с обратимым backup 305. Проверены обе сборки, упаковка
ресурсов, strict codesign, exact installed identity, сохранность данных и положительный
backend ping. Finder/Get Info/DMG проверки 305 ниже исторические; новые UI gates ещё открыты.
**B06/B08 остаются открыты:** пользователь открыл Settings, но CUA всё ещё не адресует
окно; последний собственный trust report нового app — `false`, а ручная reauthorization,
перевод и History ещё ожидают пользовательского результата.

**Актуализация 17:58 UTC:** пользователь отклонил прежний квадратный AppIcon в ClearDark/Graphite,
а исправленный control установлен в 306. Последняя read-only TCC проверка связывала
grant с CDHash 304; новый persisted own trust report остаётся 0, реальная manual
reauthorization ещё pending. Реальный сохранённый shortcut ⇧⌘Q.
Его нельзя предлагать нажимать без проверки регистрации: это также системный Log Out.
Официальный compiler PNG inputs прошёл, но кандидат скрывает клубок и строки из-за
обратного порядка наложения. Retry правки JSON отклонён compiler с generic format error;
восстановление root тоже не прошло compiler. Затем обе пробы diagnostic batch прошли
compiler; маленькие системные renders восстановили клубок и три строки. Root подтвердил
control. Его inputs/provenance перенесены без изменений, оба builders и строгие guards
независимо проверены и закоммичены Root. Обе реальные локальные сборки **306 PASS**,
с exact revision/source digest и strict signatures. Review полного bundle прошёл,
replacement и normal launch выполнены; installed signature/resource/data checks PASS.
Настоящая UI/translation acceptance ожидается при pending desktop availability.
Source CI `5c2747a` красный в существующем timed fallback
test, исправление принадлежит Root. Предыдущая
native SVG hash-equality проверка отозвана: три слоя были прозрачными.
Generated app copies очищены точечно после проверки одного recoverable 305 ZIP;
актуальный rollback — `Translator-build305-rollback.zip`, исторические copy paths ниже
не выдаются за существующие после cleanup. Final signed full306 и все proof records сохранены.

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

## Новый пользовательский результат и диагноз · 14:40–14:53 UTC

После замороженного checkpoint координатор получил два реальных пользовательских PNG.
Исполнитель лично просмотрел оба: в System Settings → Accessibility строка Translator
имеет включённый синий switch и очень тёмную квадратную иконку; в новом Translator Settings
сохраняется `Setup: Accessibility / Needed for the shortcut`. Пользователь отдельно уточнил,
что отклонил **квадратный AppIcon**, а не непрерывную линию menu bar. Menu artwork остаётся
неизменным. Успешный перевод и History пользователь не подтвердил. **B06/B08 не пройдены,
визуальная приёмка квадратного AppIcon открыта повторно.**

Исходные пользовательские файлы:

- `/var/folders/ks/m81rr3hx30j9v95xlnc_svg00000gn/T/orca-paste-1791210576135-c09f108d-ef5f-492f-831e-0d9ae50a9421.png`;
- `/var/folders/ks/m81rr3hx30j9v95xlnc_svg00000gn/T/orca-paste-1791210580303-3a84faa8-783e-46dd-9950-25d67c3e751e.png`.

Root сохранил их отдельно с hashes в соседнем `brand/github/user-305-feedback.json`.
Это его артефакт; собственный результат исполнителя — просмотр изображений и следующие
read-only измерения. Новых desktop input, restart, re-sign, TCC reset или cache clear не было.

**Причина отказа Accessibility измерена.** Exact system TCC row
`kTCCServiceAccessibility / com.translator.desktop`, прочитанная SQLite `mode=ro`, имеет
`auth_value=2`, но её `csreq` всё ещё требует CDHash старого build 304:
`0c68ccaa11c25394a315a7f36ebe4bced537e088`. `csreq -r … -t` декодирует ровно этот
`cdhash` requirement. Last modified записи — **14:29:18 UTC**, следовательно недавний
включённый switch не заменил старую code identity. Тест `codesign --verify --strict
-R='cdhash H"0c68ccaa11c25394a315a7f36ebe4bced537e088"'` проходит на original backup 304,
но installed 305 возвращает exit **3**, `code failed to satisfy specified code requirement(s)`.
Новая подпись при этом остаётся валидной, с прежним CDHash 305
`5dae68c3706841f4366dcf6d820e0ece6063a230`. Это объясняет authoritative `false` приложения;
AppModel/SelectionCapture не нуждаются в подмене trust check или исправлении stale UI flag.

Собственные evidence вне repo: `accessibility-existing.csreq`,
`accessibility-identity-1447.json`, `diagnosis-1453.json`. Прочитана только целевая запись
Accessibility этого bundle; TCC database не изменялась. Native PID **37501** и собственный
backend **37573** продолжают работать по прежним точным installed paths. Пользователь
изменил shortcut: актуальный `hotKey=12:768` соответствует **Shift+Command+Q** по текущему
KeyCombo, а не прежнему ⇧⌘T. Новое значение сохраняется; baseline не восстанавливался.

**Тёмная иконка воспроизводится в Icon Services.** Apple `iconutil` и прямое AppKit чтение
installed `AppIcon.icns` показывают светлую ivory-панель и светлый клубок; файл по-прежнему
содержит все десять оптических representations. `NSWorkspace.icon(forFile:
"/Applications/Translator.app")` возвращает `isTemplate=false` и 32 `NSISIconImageRep`.
Его render 32 pt ×2 — тёмный graphite-рельеф, соответствующий отвергнутому пользовательскому
изображению. Этот результат лично просмотрен. Явные drawing contexts `.aqua` и `.darkAqua`
оставляют его тёмным, тогда как direct ICNS render остаётся светлым. Это artifact inspection,
а не screenshot, UI input или замена native acceptance.

Exact read-only global appearance keys:
`AppleIconAppearanceTheme=ClearDark`, `AppleIconAppearanceTintColor=Graphite`,
`AppleInterfaceStyle=Dark`. Текущий системный выбор — clear/mono dark с graphite, поэтому
обычная смена AppKit light/dark drawing context недостаточна. Apple описывает автоматическую
генерацию отсутствующих appearance variants и явные Default/Dark/Mono variants в
[App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) и
[Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).
Совокупность настроек и прямого воспроизведения локализует проблему в автоматически
полученном **ClearDark appearance** legacy ICNS, а не в повреждённом PNG, menu template
или закешированном старом рисунке. Старый 304 имеет другую синюю A/Я-иконку. Bundle resolver
выбирает `/Applications/Translator.app`; два внешних backup зарегистрированы, но не выбраны.

Диагностические artifacts в `brand/native/`: `inspect-native-icons.swift`,
`native-icon-service-appearances.txt`, `workspace305-32pt-2x-NSAppearanceNameAqua.png`,
`workspace305-32pt-2x-NSAppearanceNameDarkAqua.png`,
`direct305-32pt-2x-NSAppearanceNameDarkAqua.png`, `decoded-build304.iconset/`.
Get Info большой preview/Finder PASS из первого checkpoint остаются действительными
только для тех конкретных представлений. Малый Get Info header уже был тёмным; прежний
PASS не доказывает приемлемость ClearDark AppIcon во всех системных местах.

Минимальный план перед следующим installed build:

1. Сохранить десять fallback ICNS reps, исходную геометрию ivory/graphite и menu line.
   Добавить явное native appearance packaging с читаемыми клубком/передней панелью в Mono/Clear.
   Обычный macOS `.appiconset` с `luminosity=dark` — пока непроверенный вариант: Apple
   [asset catalog documentation](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
   описывает Dark/Tinted slots для iOS/iPadOS, а все macOS appearance variants — через `.icon`.
2. Локально установлены Command Line Tools; `xcrun --find actool` не находит compiler.
   Использовать официальный Xcode 26 compiler существующего macOS CI в ограниченной
   resource-only `workflow_dispatch` job, с source/compiler provenance, partial Info.plist,
   generated resources и SHA256. Не устанавливать полный Xcode на host и не менять его defaults.
3. Проверить generated resource через Icon Services в отдельном **незапущенном** staging
   bundle под текущим ClearDark. Успешный compiler exit сам по себе не доказывает исправление.
   Оба bundle builders должны переносить validated compiled resources и `CFBundleIconName`
   до signing, сохраняя ручную упаковку menu PNG и существующий fallback.
4. После доказанного resource исправления заморозить одну конечную identity, собрать build
   больше 305, проверить exact signature, сделать reversible backup 305 и только затем
   заменить installed app по согласованному desktop lock. До этого новую reauthorization
   не запрашивать: очередной ad-hoc re-sign снова изменит grant requirement.
5. На конечной установленной подписи пользователь удаляет старую строку Translator в
   Accessibility и добавляет именно `/Applications/Translator.app`, затем проверяются
   authoritative trust, фактически выбранный ⇧⌘Q, translation и History. Никакого автоматического
   grant, global reset или правки TCC не планируется. Developer ID отсутствует; будущая смена
   ad-hoc identity остаётся ограничением, отдельно от этой одноразовой приёмки.

На 14:53 UTC это измеренный диагноз и конкретный план, **не выполненное исправление**.
Обновлённые source/resources, новый installed build и конечная native acceptance ещё не готовы.

## Подготовлен resource-only compiler probe · 15:02 UTC

Root выбрал исправление app-owned resources, разрешил узкую новую workflow
`.github/workflows/macos-icon-assets.yml` и расширил ownership на production resource inputs
в `scripts/macos_bundle_manifest.py`. Host Xcode и глобальное ClearDark/Graphite не меняются.

Из официального Apple Landmarks sample получен только `.icon/icon.json` и ZIP directory
посредством проверенных HTTP 206 ranges: **101 898 bytes**, без загрузки архива 336 МБ.
Локальная копия schema reference — `brand/native/apple-landmarks-icon.json`.
`Resources/AppIcon.icon/Assets/` содержит пять точных semantic SVG subtrees существующего
approved master (`back-panel`, `chaos`, `front-panel`, `text`, `highlights`). Сравнение parsed
XML каждого subtree и проверка всех локальных references: **5/5 PASS**. Контуры, координаты,
материал и исходный export не регенерировались. `.icon/icon.json` задаёт явные Mono fills
для светлой передней панели/клубка и graphite задней панели/полос, без нового glass,
translucency или specular. JSON appearance enum и SVG importer пока должен подтвердить
официальный compiler: местная структурная проверка **не равна** compiler/native PASS.

`Resources/AppIcon-source.json` фиксирует provenance и SHA256 preserved source/layers.
`make_icon.sh --compile-appearances OUTPUT_DIR` вызывает официальный Xcode `actool`, пишет
version/SDK/path, compiler log, partial Info.plist и resource provenance/hashes.
Старый default make_icon path остаётся прежним. Новая workflow — только `workflow_dispatch`,
`macos-26`, timeout 10 min и artifact upload; она не запускает app, не подписывает,
не устанавливает и не публикует release. Existing production workflow не изменена.
Оба bundle builders и installed 305 на этом этапе тоже не изменены: pre-sign packing
generated resource будет подключён после реального доказательства исправления.

Source digest теперь учитывает точные menu PNG, appearance source/provenance и compiler
contract, а также files production `.icon/CompiledAppIcon` directories. Root design/research/
docs в shipped source digest не попадают. Manifest дополнительно сравнивает fallback ICNS
и все три menu PNG в собранном bundle с production source, а при `CFBundleIconName=AppIcon`
требует `Assets.car`. На изолированной копии настоящих production inputs поочерёдная
мутация menu @2x, chaos.svg и compiled Assets.car изменила digest и отклонила manifest
**3/3**, до signing; live artwork не менялось. Evidence — `resource-guard-checks.json`.
Ruff check/format и mypy affected manifest script: **PASS**.

Десять source paths заморожены в `brand/native/appearance-source-freeze.sha256` и переданы
Root для named staging/commit/push/manual CI dispatch. Source XML/JSON checks находятся в
`icon-source-checks.json`. Shell syntax и diff check: **PASS**. Historical fallback ICNS
SHA256 остаётся `ca1f8328df7395ca05066fbeff9449e6ead4df2dbfefecf4c473ca7f43e3a4b3`;
menu bytes unchanged. Compiler artifact, actual **16/32 pt** Icon Services ClearDark проверка,
оба готовых новых bundles, новая конечная подпись и installed acceptance ещё **PENDING**.
`worker_done` не отправлен.

## Первый compiler FAIL и узкое исправление · 15:22–15:26 UTC

Source probe вошёл в локально проверенный commit
`252d89c0e3e620ea79c9c1250e7d9e862558508e`. Root сообщил exact remote verification
и [resource run 37331657219](https://github.com/gorodtx/selection_translator_anki/actions/runs/37331657219),
job `111835995198`, с тем же head. Исполнитель самостоятельно не выполнял forge/API checks;
лично прочитал downloaded compiler log, Xcode/SDK и partial plist в
`brand/native/compiler-252d89c-run37331657219/`.

**Official compiler: FAIL** — `Too many visible groups. This icon exceeds the maximum group
limit of four.` Было пять групп. Xcode **26.6 / 17F113**, SDK **26.5**. Частичные `Assets.car`,
`AppIcon.icns` и plist существуют даже после failure; они остаются внешними diagnostic artifacts,
**не признаны валидными и не используются** в build/install. Provenance manifest не создан,
поскольку compilation завершилась ошибкой. Partial plist показывает требуемые
`CFBundleIconFile=AppIcon`, `CFBundleIconName=AppIcon`, но это не visual/compiler PASS.

Две общие CoreSVG строки расследованы локально через **публичный** `NSImage` decoder,
с bounded `CORESVG_VERBOSE=1`, без private API или GUI input. Конкретная ошибка —
`SVGGradient: Attribute parse error: gradientTransform`. В prepared SVG gradients присутствует
пустое `gradientTransform=""`: это невалидная строка, эквивалентная отсутствующему transform.
В owned derivatives удалены **только пять пустых attributes**. Непустые transforms,
контуры, coordinates, colors, filters и historical approved master сохранены.

Front/text/highlights объединены в прежнюю front group с одинаковыми common settings;
теперь **три visible groups**, а полный порядок пяти layers остаётся прежним. Provenance
честно описывает compatibility normalization вместо заявления о byte-identical subtree.
Перед/после normalization публичный native decoder дал **5/5 идентичных 1024 px raster
buffers**; после исправления verbose log имеет **ноль CoreSVG errors**. Evidence:
`icon-compatibility-checks.json`, `svg-native-before-normalization.log`,
`svg-native-after-normalization.log` и соответствующие hashes JSON.

`make_icon.sh` теперь включает bounded verbose compiler logging и отклоняет любые residual
CoreSVG errors до provenance generation. Shell syntax/diff check: **PASS**. Retry freeze —
`appearance-retry-freeze.sha256`, восемь guarded paths, из них шесть реально изменены.
Unchanged chaos/highlights включены как geometry guards. Исполнитель передал Root named
changes для normal commit/push/retry и вновь остановил production edits. Оба builders,
installed 305, подпись, backend/history/grants остаются прежними. Успешный official retry,
actual 16/32 pt ClearDark, финальная resource packing/installation и B06/B08 ещё ожидаются.

## Исторические ограничения инструментария

## Исправление ложного raster PASS и положительные inputs · 15:33–15:40 UTC

Root независимо заметил одинаковый hash у трёх разных shapes и доказал, что
`83ee47245398adee79bd9c0a8bc57b821e92aba10f5f9ade8a5d1fae4d8c4302` — SHA256 полностью
нулевого buffer. Исполнитель повторил содержательную проверку публичным decoder:
SVG renders имеют **2048×2048**, **16 bits/component**, **64 bits/pixel**, row stride
**16 384**, **33 554 432 bytes**. У back-panel/front-panel/text nonzero bytes **0** и
alpha pixels **0**; chaos/highlights содержат pixels. Поэтому предыдущие «5/5 идентичных
buffers» означали equality пустого вывода у трёх layers и **не доказали сохранность рисунка**.
Этот PASS отозван; исчезновение parser logs тоже недостаточно. Исполнитель ошибся, не
включив positive content check сразу. Root не коммитил, не dispatch и не устанавливал
такой retry. Evidence: `native-layer-rejected-svg.json/.log`. Исторические записи выше
сохранены как chronology; ими нельзя закрывать acceptance.

Причина silent blank — неподдержанная native SVG pattern/gradient комбинация; это
локализовано по render результата, а не заменено предположением о валидности XML.
Проба direct gradient refs через тот же primary renderer сохранила alpha footprint,
но дала RGBA differences до 28/255 на back edge и 24/255 на front edge. Она **не принята**;
её evidence-only candidates не внедрены. Сохранение original материаловых pixels важнее
исчезновения importer warnings.

Выбран обычный exact-layer PNG export существующим renderer approved kit:
**Sharp 0.34.5/librsvg**, density 72, resize 1024×1024, `withIccProfile('srgb')`, PNG.
Пять SVG subtrees восстановлены **точно** из unchanged historical master в production
`Resources/AppIcon-layer-sources/`. Они находятся вне `.icon` importer, их XML совпадает
с original semantic groups. PNG в `.icon/Assets/` содержат тот же рисунок, transforms,
filters и цвета; paths не перерисовывались, direct gradient candidates не применены.
`.icon` использует только PNG names и прежний порядок пяти layers внутри трёх групп.
Historical master, curated ICNS/optical exports и menu PNG не менялись.

Все пять PNG лично просмотрены: видны graphite задняя панель, светлый объёмный клубок,
ivory передняя панель, три dark строки и верхние highlights. Публичный AppKit PNG decoder
даёт **1024×1024 / 8 bits/component / 32 bits/pixel / row 4096 / 4 194 304 bytes**.
Его raw RGBA hashes совпадают с independently decoded Sharp output для **5/5**.
Положительные alpha/content stats:

| Layer | Alpha pixels | Bounding box x/y, включительно |
|---|---:|---|
| back-panel | 245 305 | 108,130 → 643,793 |
| chaos | 95 825 | 162,334 → 542,695 |
| front-panel | 196 907 | 451,302 → 931,896 |
| text | 31 784 | 553,542 → 846,759 |
| highlights | 3 476 | 236,134 → 931,452 |

Evidence: `positive-layer-export-checks.json`, `native-layer-positive-png.json/.log`,
лично просмотренные `layer-*-before.png`; renderer/export и inspection scripts лежат
в том же внешнем native evidence. Production provenance v2 сохраняет original vector/
raster hashes, renderer version/method, dimensions, alpha occupancy и bbox. Compiler
provenance и stable-tree source digest теперь учитывают также production layer-source SVG.
Shell syntax, diff check, affected-script Ruff check/format/mypy: **PASS**. Это положительные
**source/import controls**, пока не official compiler, system ClearDark или installed UI PASS.
Новая narrow freeze будет передана Root вместе с explicit deleted SVG importer paths;
source/root Git и install остаются раздельными gates.

## Компиляция PNG и проверка настоящей композиции · 16:00–16:20 UTC

Root закоммитил подготовленные PNG inputs как `305a485a3f51584f7d5e5a8575952231a231c3ce`.
Ресурсный workflow [37337286809](https://github.com/gorodtx/selection_translator_anki/actions/runs/37337286809)
завершился успешно; этот факт получен от координатора отдельно от собственной проверки
скачанного артефакта. Исполнитель сверил **13/13 source hashes**, canonical source digest
`2003629a1b724de90e1b6a2ed980e33021fb8ef7e5a415cbd5224dd9d009a146` и **7/7 generated hashes**.
`Assets.car` имеет SHA256 `75740f4bb3bdf1c81d73362648f127c752d19dbc736379f7fb72007c5301ac17`;
partial plist содержит `CFBundleIconFile=AppIcon`, `CFBundleIconName=AppIcon`.
Оригинальный curated ICNS сохранён отдельно; сгенерированный compiler ICNS его не заменял.
Evidence: `compiler-305a485-run37337286809/`, `compiled-resource-checks.json`.

Создан **не запущенный** минимальный probe bundle
`appearance-probe-305a485/TranslatorIconProbe.app` с отдельным bundle ID
`com.translator.desktop.artwork-probe.305a485`, точным CAR и original fallback. Backend/DB
не копировались и не запускались. Публичные `NSWorkspace.icon(forFile:)` и
`Bundle.image(forResource:)` использованы в `inspect-candidate-icons.swift`:

```sh
xcrun swift /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/inspect-candidate-icons.swift
/usr/bin/assetutil --info /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/compiler-305a485-run37337286809/Assets.car
node /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/check-icon-paint-order.mjs
```

Лично просмотрены системные 16/32 pt 1×/2× и 128 pt renders. Передняя панель стала
светлой, однако **клубок и три строки исчезли**: candidate acceptance **FAIL**.
`NSAppearance` контекст рисования не заменяет фактическое переключение системного
icon appearance; default/dark OS acceptance этим не закрыты. Установленный 305 не заменялся.

`compiled-assets-info.json` показывает порядок group stack `Gradient/front/chaos/back`,
а front group содержит `highlights0/text1/front2` — обратный исходным SVG paint arrays.
Это согласуется с [официальным руководством Apple](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
о рисовании снизу вверх sidebar и с [примером Landmarks](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass):
его JSON перечисляет layer5, затем layer4/3/2, затем layer1, то есть спереди назад.
Проверка композиции **тех же PNG bytes** в наблюдаемом compiler порядке скрывает
100% alpha-площади клубка и текста. Утверждённый порядок back/chaos/front/text/highlights
возвращает **91,3038%** клубка и **100%** текста. Обе композиции лично просмотрены:
`composition-compiled305-256.png` воспроизводит дефект, `composition-approved-256.png`
возвращает исходный рисунок. Evidence: `composition-order-checks.json`,
`appearance-order-repair-proof.json` с точными indices metadata и Apple sample fields.

Подготовлено ровно два production изменения: `AppIcon.icon/icon.json` перечисляет groups
и layers спереди назад; `AppIcon-source.json` фиксирует контракт. `fill` и
`fill-specializations` заменены исключительной формой Apple sample: unnamed default value,
затем dark/mono entries. Все исходные значения цветов сохранены; прежнее предположение
о приоритете plain fill остаётся **inference**, пока новый compiler не покажет нужные colors.
Все остальные **15 resource hashes** совпали до/после, включая PNG, vector, fallback и menu.
Named freeze: `appearance-order-freeze.sha256`, inventory: `appearance-order-inventory.json`.
`git diff --check` и разбор JSON: **PASS**. Следующие gates — отдельные: exact-source
official compiler, compiled paint order/palette, маленькие системные renders, затем
упаковка обоими builders, новая подпись, обратимая установка и ручная native acceptance.

## Исправление root schema после compiler отказа · 16:35–16:37 UTC

Root сообщил failure exact-head `2de2b68e3c1074792737d0d6fb7513918a783a83` resource run
[37341701294](https://github.com/gorodtx/selection_translator_anki/actions/runs/37341701294),
job `111870108229`. Исполнитель лично прочитал скачанный `actool.log`:
`The data couldn’t be read because it isn’t in the correct format.` и
`attempt to insert nil object from objects[0]` в
`selectCatalogIconComposerItemsFromCollection`. Успешной provenance/приёмки нет;
этот output не упакован и не установлен.

Проверка обнаружила неподтверждённое обобщение schema: пример Apple использует exclusive
`fill-specializations` **в layer objects**, а **root** содержит plain `fill`. Перенос
layer формы на root был необоснованным обобщением исполнителя; Root также принял его
при source review; compiler отклонил весь input, но generic error сам по себе **не
изолирует root или layer поле**. Требование plain root fill остаётся inference из
известного compiler PASS и Apple sample. Восстановлены точные
root `fill` и исходные dark/mono entries из ранее успешно скомпилированного `305a485`.
Измеренная правка порядка и подтверждённая Apple layer форма сохранены. Artwork,
цветовые значения, меню и fallback прежние: **15/15 resource hashes** снова совпали.

Новая freeze содержит только `AppIcon.icon/icon.json`
`5020bc8665872604579a4f302b4fa6e3da729676067b7df5c78d0ddb2df4045f` и уточнённый
`AppIcon-source.json` `aae0c8bb324fae9a303d30e9005cd9e97559c258c378ad778e21ca31125a4706`.
Evidence: `appearance-root-schema-freeze.sha256`, `appearance-root-schema-proof.json`,
`compiler-2de2b68-run37341701294/actool.log`. Разбор JSON и diff check прошли; следующий
official retry ожидается через координатора. Source проверки не закрывают compiler,
system appearance, упаковку, подпись или установленную native acceptance.

## Второй format failure и ограниченный diagnostic batch · 16:51–16:58 UTC

Resource run [37343812567](https://github.com/gorodtx/selection_translator_anki/actions/runs/37343812567)
на exact HEAD `78924115f9cdf2534f9e2547cc26b408aabe6fe3` завершился failure по ответу Root.
Исполнитель лично прочитал `compiler-7892411-run37343812567/actool.log`: тот же generic
format/nil-object exception, accepted provenance отсутствует. **Восстановление root
не оказалось достаточным**; вывод о root-only причине не подтверждён. Неизменённые PNG
не означают поддержки всех JSON appearance tokens: термин Mono в Apple UI сам по себе
не доказывает, что string `mono` принимается в данной specialization schema.

Root разрешил один ограниченный resource-only batch из двух cases. Подготовлены
`make_icon.sh --compile-appearance-diagnostics OUTPUT_DIR` и workflow для него.
Baseline `Resources/AppIcon-diagnostics/known-valid-icon.json` byte-identical исходнику
компиляторного PASS `305a485`; primary production JSON `7892411` остаётся прежним.
Control применяет к known-valid declarations **только** измеренное reverse group/layer
ordering. Preferred сохраняет известный root, ordering и использует exclusive LAYER
список **default/dark**, которые присутствуют в Apple sample; layer `mono` удалён
только в diagnostic input. Все appearance-field различия перечислены в его manifest.
Обе ветки сохраняют PNG, source SVG и curated fallback — **11/11 copied artwork files**
каждая. Меню и остальные production resources не менялись.

Каждый case получает отдельные input JSON, input provenance с **13/13 source hashes**,
canonical source digest и revision; отдельные compiler exit/log и, при успехе,
generated resource provenance. Итоговый `diagnostic-summary.json` сохраняет per-case
`compiler_success`, `selected_candidate=null`, native acceptance pending. Успех всего
job не выдается за приёмку конкретного candidate. Batch не подписывает, не запускает,
не устанавливает приложение и не меняет production input или public release.

Локально выполнен сам input generator; source hashes обеих веток положительно сверены.
Control config SHA256 `5474ad926e3af55472e8489aafbe91771504089f28b0a78838bc419a729bc0ce`;
Preferred `be2ec1812e149d33157a5f49bbac8cefa0254c918ed0e5dfdf9c20a55c61689c`.
Shell syntax/diff и Ruff check/format/mypy strict трёх извлечённых Python blocks: **PASS**.
Official compiler локально не запускался, поскольку `actool` отсутствует.
Freeze содержит ровно workflow, `make_icon.sh` и known-valid baseline JSON:
`appearance-diagnostic-batch-freeze.sha256`; inventory и local proof лежат рядом.
Перед promotion нужны реальные per-case compiler результаты и лично просмотренные
маленькие системные renders. Installed 305, backend, TCC и пользовательские данные прежние.

## Две успешные пробы и выбранный control · 17:19–17:29 UTC

Root вернул отдельные CONTROL PASS и PREFERRED PASS resource run
[37347290607](https://github.com/gorodtx/selection_translator_anki/actions/runs/37347290607),
job `111888956735`, exact HEAD `5c2747aca18805e7f0c4fcea9d38377767fd9d3a`, Xcode 26.6,
SDK 26.5. Собственная проверка скачанного batch подтвердила для **каждого** case
13/13 source hashes, 7/7 generated hashes, canonical digest и 11/11 неизменённых artwork
files. Actual source digests: control `ebfc66e6da9e1eff9ab0a673a67fd1ed6ce1e21e8525874cc909e77f9bfde8d6`,
preferred `2496bbea2976420c87dd1560e0a6ac1982797e8728ac88c2ca94d6d1c1928942`.
CAR control `119d9a04a731edc72037a5886ccaca11b0c519ad6bcd962a905a4116ffe6f4d7`;
preferred `4fc7395f36f62a045b59d47b4f36bd608a0b90cf6468ea5c9e974b370e9c4238`.

Два уникальных probe bundles **не запускались**; содержат только native executable,
minimal Info, точный CAR и fallback, без backend/DB. Публичный Icon Services file-icon
request при повторно прочитанных **ClearDark/Graphite/Dark** preferences теперь показывает
светлую переднюю панель, клубок и три уменьшающиеся строки. Исполнитель лично просмотрел
16/32 pt 1×/2× и 128 pt обеих проб, а также named artwork projection; Root независимо
просмотрел шесть outputs и подтвердил control. Положительный результат относится к
**unlaunched staged file icon**, а не к установленному приложению, переключению настоящего
OS Default/Dark, MenuBarExtra, Settings или Accessibility.

Сравнение даёт 28/30 одинаковых PNG hashes. Два отличия находятся в **16 pt Aqua**:
1× — 6 изменённых RGBA components из 1024, максимум 3/255; 2× — 10 из 4096, максимум 2/255.
Остальные 28, включая 32/128 pt, совпадают. Исполнитель сначала неверно назвал эти два
отличия «128 pt» и сообщил all16/32 equality до просмотра diff; этот вывод немедленно
отозван и исправлен в сообщении Root. Авторитетный результат —
`batch-render-pixel-differences.json`, дополненный `batch-render-comparison.json`.
Источник сравнения и лично просмотренные PNG сохранены, ничего не подчищалось.

Control выбран за ту же видимую идентичность при сохранённых known-valid appearance/
color declarations. Его `icon.json` и `AppIcon-source.json` скопированы byte-identically;
**13/13 compiler input hashes** продолжают совпадать. Metadata diagnostic status описывает
момент компиляции; отдельный `CompiledAppIcon/promotion-receipt.json` честно фиксирует
выбор и staged small-render PASS, оставляя installed и actual OS Default/Dark pending.
Compiler provenance не переписывали. Curated 10-rep ICNS, native `ic04/ic05`, исторические
PNG/SVG и template menu masks прежние.

Оба builders теперь вызывают общий `macos_bundle_manifest.py --pack-artwork` **до подписи**.
Он проверяет 13 inputs и canonical digest, generated CAR hash, provenance/receipt связь,
копирует семь ресурсов и задаёт `CFBundleIconName=AppIcon`. B14 сверяет byte equality
реально упакованных CAR/provenance/receipt/menu/fallback и правильный выбор Info icon;
не принимает одно существование файла. Source digest включает также короткий builder.
Положительный реальный CLI pack/verify прошёл; четыре изолированных mutations отвергнуты:
изменённый bundled CAR, удалённый iconName, изменённый source JSON, изменённый compiled CAR.
Ошибки и exits — `resource-packing-guard-checks.json`. Исходники production не менялись
ради отрицательных проверок; app checks не запускались.

Ruff check/format/mypy strict, shell syntax и diff check: **PASS**. Freeze содержит ровно
10 owned resource/build/documentation paths в `appearance-promotion-freeze.sha256`;
inventory фиксирует исключённые Root files и pending installed acceptance. Workflow
по умолчанию компилирует production; отдельный boolean включает diagnostic batch.
Root получил freeze для независимого review/normal named Git и разрешения запуска
обеих необходимых локальных сборок 306. Исполнитель не делал staging/commit/push.

Общий source CI **не зелёный**: Root сообщил `5c2747a` run `37347271230`, signed-app job
`111890548721`, failure `tests/test_provider_failures.py::test_cold_apple_primary_gets_its_engine_budget[True-True]`.
Root владеет узкой test правкой; она не входит в icon freeze. Resource compiler и local
guards остаются своими отдельными gates. Evidence: `batch-resource-checks.json`,
`batch-{control,preferred}-icon-renders.json/.log`, `batch-*-workspace-*.png`,
`appearance-promotion-inventory.json` и неизменённый downloaded batch.

## Реальные shell/full bundles 306 · 17:34–17:37 UTC

Root независимо проверил promotion/guards и сделал normal resource commit
`bfac4d1f736716f9ba41a1ae2927ac3cb11edb6b` ровно для 10 frozen paths, отдельно от своего
test commit. Исполнитель повторно сверил все 10 SHA и ancestry исходной базы, затем
выполнил оба требуемых пути:

```sh
TRANSLATOR_APP_BUILD=306 macos/Translator/scripts/build_app.sh release
TRANSLATOR_APP_BUILD=306 scripts/build_macos_app.sh --out /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full306 --skip-swift
uv run --no-project python scripts/macos_bundle_manifest.py --verify-artwork macos/Translator/.build/Translator.app
uv run --no-project python scripts/macos_bundle_manifest.py --verify-artwork /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full306/Translator.app
codesign --verify --deep --strict macos/Translator/.build/Translator.app
codesign --verify --deep --strict /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full306/Translator.app
```

Builders завершились exit 0, final resource equality и independent strict codesign
прошли на обоих. Info: `0.3.0`, build `306`, `com.translator.desktop`, `LSUIElement=true`,
`CFBundleIconFile=AppIcon`, `CFBundleIconName=AppIcon`; существующий minimum macOS сохранён.
CAR `119d9a04a731edc72037a5886ccaca11b0c519ad6bcd962a905a4116ffe6f4d7` и curated ICNS
`ca1f8328df7395ca05066fbeff9449e6ead4df2dbfefecf4c473ca7f43e3a4b3` совпадают с source.
Short содержит native shell; полный bundle — 61 MB с backend/Python/sidecar. Old DB/VM
tests, скачивания данных, user settings, grants и history ради сборки не трогали.

| Bundle | Native SHA256 после подписи | CDHash |
|---|---|---|
| short 306 | `7cd193afeb9d1e5f13ba702c688c13998a76f3718370334fb4625bf7596fde96` | `e242cadfe4abcbda9dc6614e517b84b5894828dc` |
| full 306 | `f8fdb1edacb5cd54ce4032f495278087422feb810218d64fc9427bd75f24eb5c` | `86db3a69b875b1037903f8dc3c4f92bf386aa19e` |

Full `build-info.json` содержит exact committed revision `bfac4d1...` и текущий source
SHA256 `c3231b87928d687d0030929e16ee3df32454e7fa5d56beb62279b32e2bb41420`; оба значения
сверены с реально запускавшимися source/CLI. Подписи ad-hoc; Developer ID отсутствует,
notarization и public release не выполнялись. Полный bundle:
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full306/Translator.app`.
Evidence: `build306-verification.json`, `short306-build.log`, `full306-build.log`,
`short306-codesign.txt`, `full306-codesign.txt`.

Root получил конкретный signed bundle и независимо подтвердил strict codesign, byte
equality, Info, exact source/build identity и отсутствие bundled SQLite/design directory;
его proof — `github/local-build306-review.json`. `/Applications/Translator.app` пока
**305**, его текущая подпись и пользовательские данные прежние. Перед остановкой,
заменой и desktop UI ожидается свежий shared GUI lock; Root запросил доступность desktop
у пользователя, положительного ответа пока нет. New signature источников
не меняют после этого этапа без координации; будущий grant привязывают к окончательному
installed app, а не к временной пробе или short bundle. Actual menu/light/dark/Retina,
Finder/About/Settings/translation/history acceptance ещё не выдана за PASS.

В 17:40 UTC повторная собственная read-only проверка установленного 305 подтвердила
strict signature, native SHA `a9e51ac...` и CDHash `5dae68c...`. Точные PID остаются
`37501` (native, PPID 1) и `37573` (его backend, PPID 37501), оба с exact executable
paths `/Applications/Translator.app/Contents/...`. Никто не остановлен и не заменён.
Новая подпись full306 не меняется. Evidence: `previous305-pre-replace.json`,
`previous305-codesign.txt`. Этот checkpoint заморожен как **build complete / installation
pending**, а не завершение native задачи. Восстановимые 304 backups, прежний 305,
source/CI history и точный native session/resume сохранены; следующий шаг требует
положительного desktop lock и последующей отдельной проверки final installed grant.

## Окончательная установка 306 и сохранность · 17:47–17:50 UTC

Root уточнил scope: существующая authorization на recoverable replacement и normal
launch действует; pending desktop availability ограничивает **CUA inputs/capture**,
а не добавляет filesystem approval. Исполнитель выполнил утверждённую замену без
GUI clicks/keys/capture. До неё положительный ping подтвердил exact own backend PID,
наличие трёх DB и engines snapshot; этот ping не выдавался за отсутствие активного
перевода или за translation acceptance. У protocol нет read-only current-state query;
измеренного blocker для обычной установки не получено.

До остановки сохранены и проверены независимая точная копия текущего 305
`Translator-build305.app` и staging нового full306. Native PID **37501** был повторно
проверен по exact executable path и остановлен через SIGTERM. Только его уже доказанный
backend **37573** остановлен штатным own UDS `shutdown`; иных процессов не касались.
Старый оригинал перенесён наружу в `Translator-build305-original.app`, staging переименован
в `/Applications/Translator.app`, strict signature и native hash проверены до normal
`open -a /Applications/Translator.app`. Внешние 304 backups также сохранены. DB/history/
settings/Anki/TCC, trust logic, global theme, icon cache и public release не менялись.

В 17:49 UTC собственная final проверка положительно подтвердила:

| Gate | Измеренный результат |
|---|---|
| Installed identity | `0.3.0 (306)`, `com.translator.desktop`, `LSUIElement=true` |
| Native PID/path | **54745**, exact `/Applications/Translator.app/Contents/MacOS/Translator` |
| Backend PID/parent | **54753**, PPID **54745**, exact `Resources/bin/TranslatorEngine` |
| Signature | strict codesign PASS; CDHash `86db3a69b875b1037903f8dc3c4f92bf386aa19e` |
| Native bytes | `f8fdb1edacb5cd54ce4032f495278087422feb810218d64fc9427bd75f24eb5c`, equals reviewed full306 |
| Actual artwork | byte verifier PASS; CAR `119d9a04...`, curated ICNS `ca1f8328...`, all three menu masks unchanged |
| Build identity | revision `bfac4d1f736716f9ba41a1ae2927ac3cb11edb6b`, source `c3231b87928d687d0030929e16ee3df32454e7fa5d56beb62279b32e2bb41420` |
| Data preservation | config/history hashes equal pre-replace; history count **1**; three DB size/mtime equal |
| Shortcut | actual `12:768` preserved, no unasked preference change |
| Runtime | positive own UDS ping from **54753**, protocol/history persistence/three DB present |
| Accessibility | persisted own value **0**; TCC untouched; final real user grant still pending |

`installed306-verification.json`, `installed306-codesign.txt`, `installed306-ping.json`,
`installation306-actions.json`, `preservation-before306.json` и `preservation-after306.json`
содержат точные команды/results и hashes. DB bytes не перепроверяли и не скачивали.
Подпись ровно та, которую принял Root; приложение не пересобирали и не переподписывали
после установки. Developer ID/notarization отсутствуют; существующий public v0.3.0 не менялся.

Installed resource/runtime/data gates **PASS** не заменяют настоящие menu open,
light/dark/Retina/Finder/Get Info/About/Settings/translation/history проверки.
CUA inputs/capture остаются pending до положительного ответа desktop availability;
Root получил конкретные installed path/signature/PIDs для одного final grant/translation
вопроса пользователю. Shortcut ⇧⌘Q не предлагается нажать вслепую; безопасный menu/Services
путь и реальный register status должны быть проверены отдельно. Подпись frozen, final
UI acceptance и task completion ещё **не** объявлены успешными.

## Точечная очистка generated app copies · 17:58 UTC

Root передал прежнюю прямую пользовательскую authorization на cleanup и одну рабочую
установку. Это отдельная filesystem операция, не зависимость от pending GUI availability.
Из exact original 305 создан единственный recoverable archive вне repo:

`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/Translator-build305-rollback.zip`

SHA256 `bb379199c439b304438f32b18dad366c740e37addb2c2eed594875c9e13ffafc`.
Archive распакован `ditto` в отдельный temporary verification directory: strict codesign
прошёл, native hash равен `a9e51ac...`, **1199 file/symlink entries** побайтово/по target
совпали с original. Только после положительного restore check удалены следующие
**точные owned paths** внутри external native evidence:

- `Translator-build305.app`
- `Translator-build305-original.app`
- `Translator-build304.app`
- `Translator-build304-original.app`
- `full/Translator.app` — redundant старый signed full305
- `appearance-probe-305a485/TranslatorIconProbe.app`
- `appearance-probe-5c2747a-control/TranslatorIconProbe.app`
- `appearance-probe-5c2747a-preferred/TranslatorIconProbe.app`
- `packing-check/TranslatorResourceCheck.app`

Temporary restored `.app` также удалён после проверки. Перед удалением ownership
подтверждена exact known paths, Info/native hashes и strict signatures у rollback/full
copies; ни один target не содержал running native process. Исходники, artwork, PNG/log/
hash/provenance records, предыдущие signatures и source/CI chronology оставлены.
Исторические app paths в этих записях описывают выполненные проверки до consolidation;
текущая recoverable копия — указанный ZIP. Broad globs, global cache, Trash или TCC
cleanup не использовались.

Installed `/Applications/Translator.app` и retained `full306/Translator.app` после cleanup
снова прошли strict codesign; native bytes установленного 306 **не изменились**. Активная
installation только `/Applications/Translator.app`; final full306 и короткий source-build
artifact сохранены как не запускавшиеся проверенные build outputs. Пользовательские
DB/history/settings/Anki/grants не затронуты. Exact removal/archive proof —
`generated-app-cleanup.json`. Дальше остаётся требуемая настоящая UI/grant/translation
приёмка; task completion не подменяется cleanup успехом.

## Исторический журнал tooling

В 13:19 UTC `penpot-tool doctor` и `overview` вернули `fetch failed`. Координатор отдельно
сообщил свой PASS в 13:16 UTC с правильными file/page IDs; это другой запуск.
Shared Penpot runtime, VM, browser и autostart не менялись. Утверждённых локальных exports
достаточно для интеграции. Исторические CONTINUE и Claude AppIcon instructions сверены
с текущим handoff: прежняя рекомендация общего iconutil генератора уступает утверждённому
native codec; прежнее ограничение keep304 явно снято пользователем только для этой задачи.

## Подтверждение пользователя и истёкшее окно CUA · 18:07 UTC

Координатор передал полученные от пользователя ответы именно про установленный
**0.3.0 (306)**. Эти результаты имеют уровень **PASS_USER_REPORTED**:

| Проверка | Подтверждение пользователя |
|---|---|
| Services → перевод | Перевод слова `bank` появился |
| History | Запись этого перевода присутствует в History |
| Исправленная квадратная AppIcon | Пользователь сообщил, что новая иконка выглядит нормально |

Это подтверждает пользовательский сценарий и оценку иконки со стороны пользователя;
собственной GUI-проверки агента и снимков этих результатов пока нет. Отдельного ответа
о final Accessibility grant не получено: успешный Services-сценарий не подменяет
измерение grant, refresh состояния или регистрации shortcut. Указанные выше pending
Services/History/icon-opinion пункты теперь закрыты на уровне **PASS_USER_REPORTED**;
исторические pending записи сохранены как датированная история.

Разрешённое пользователем 60-секундное окно рабочего стола было получено в
**18:02:39.535 UTC**, крайний срок — **18:03:39.535 UTC**. Обязательный вызов
`await cua.rewriteDocumentation();` завершился в **18:02:47.519 UTC**. Большой вывод
документации вызвал автоматическое сжатие контекста; восстановление завершилось
только в **18:05:16.354 UTC**, а проверка времени в **18:05:21 UTC** показала, что окно
истекло. В этом окне не выполнено ни одного desktop input или capture, снимков нет.
Это **NOT_DONE**, а не установленный дефект интерфейса Translator. Точная запись:
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/desktop-window-306-not-done.json`.

Релевантная native CUA документация затем восстановлена из собственного журнала
без обращения к рабочему столу. До нового явно положительного desktop lease ввод
и capture остановлены. Собственные menu open, Settings, About, Finder/Get Info,
light/dark/Retina desktop проверки остаются **NOT_DONE**. Смена global theme,
слепое нажатие ⇧⌘Q, TCC reset/auto-grant и недокументированные обходы не выполнялись.

Приложение после установки не пересобирали и не переподписывали. Сохраняется exact306:
native SHA256 `f8fdb1edacb5cd54ce4032f495278087422feb810218d64fc9427bd75f24eb5c`,
CDHash `86db3a69b875b1037903f8dc3c4f92bf386aa19e`. Этот addendum меняет только отчёт;
источники, ресурсы signed bundle, данные и grants не менялись. Git commit/push остаются
исключительно у координатора.

## Фактическая GUI-приёмка exact306 и финальное ограничение пользователя · 05.10.2026

Новое положительное desktop lease было задано точно: **18:15:07–18:18:07 UTC**.
Агент использовал только документированный CUA, связанный с exact installed path:
`await cua.getApp('/Applications/Translator.app')`. Получен настоящий General window.
Затем выполнены `getScreenshot`, exposed `Raise`, обычный application menu Translator →
About Translator, возврат в Settings и выбор Advanced; каждый следующий AX index взят
из свежего snapshot. Standard About panel показывает данные именно установленного
bundle. Это собственная GUI-проверка, а не render отдельного ресурса или новый probe app.

| Gate | Фактически полученный уровень |
|---|---|
| General Settings | **PASS_CUA**: лично просмотрены ⇧⌘Q и выключенный Open at login; значения не менялись |
| Raise Settings window | **PASS_CUA_API**: exposed Raise завершился, AX focused General; отдельный вызов Settings через MenuBarExtra поверх другого приложения этим не доказан |
| About | **PASS_CUA**: лично видны светлый передний слой, узел и три полосы утверждённой AppIcon, `Version 0.3.0 (306)` |
| Advanced | **PASS_CUA**: Backend Running, три DB Available, Apple Dictionary Available |
| Тёмные native окна | **PASS_CUA**: General/About/Advanced лично просмотрены; global theme не менялась |
| Services `bank`, History, оценка квадратной иконки | **PASS_USER_REPORTED**, как зафиксировано выше; агент не выдаёт эти ответы за собственный повторный сценарий |
| Accessibility own app status | **PASS_APP_REPORTED_ROOT_VERIFIED**: Root read-only прочитал собственный сохранённый `accessibilityTrusted=1`; источник записи `AppModel.refreshAccessibilityTrust → SelectionCapture.isTrusted` |
| Setup warning | В собственном General AX/screenshot предупреждений Setup нет; source mapping указывает на готовые required model states. Это отдельно помеченная **source/UI inference**, а не нажатие глобального shortcut |

Root record `github/installed306-cua-peer-review.json` прочитан: hashes трёх снимков
сходятся с собственными captures, Root также лично их просмотрел. Сохранённый own app
boolean не равен новому AX query от helper process; отдельного свежего OS query агент
не выполнял. Services остаётся самостоятельным пользовательским сценарием и не служит
доказательством Accessibility trust. Регистрация/доставка ⇧⌘Q отдельным runtime нажатием
не проверялась; сочетание не нажимали и не меняли.

Три лично просмотренных capture сохранены как исходные **JPEG/JFIF bytes CUA**,
без перекодирования. Root перенёс точные копии в portable evidence:

| Снимок | Pixels | SHA256 |
|---|---:|---|
| [General](evidence/native306/settings-general-dark.jpg) | 1020×436 | `7f3131dc313f3a19fff025233f56514ff1dc926a1264264777870d524f77c3d9` |
| [About](evidence/native306/about-installed306-dark.jpg) | 568×382 | `d6ffe0a62cecc4173c66c39833ca14e0c5c3bfa83fd1984441a6d90be0d48d61` |
| [Advanced](evidence/native306/settings-advanced-dark.jpg) | 1020×894 | `39895a0ff842d100cfec39d3295852a87d30504e7d6ed99977452d505d4ea8c5` |

Первоначальные `.png` имена были исправлены на `.jpg` после `file`/`sips` проверки
формата и dimensions, без новой capture или изменения bytes. В снимках только окна
Translator. Физический Retina display scale не измеряли; pixel dimensions не выданы
за полный Retina acceptance. Portable manifest — `evidence/native306/manifest.json`.
Полные собственные команды, AX text и timestamps находятся вне repo:
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/cua-installed306/cua-commands-and-ax.json`;
уровни acceptance, hashes и явное нарушение deadline — в соседнем `acceptance.json`.

**Lease compliance — FAIL.** Последний возврат на General tab
`await brand306.click(9); await brand306.getAXState();` начат в **18:18:08.841 UTC**,
то есть на **1.841 s после hard deadline**, завершён в **18:18:09.987 UTC**.
Это один поздний input и один поздний AX observation, хотя значения настроек не менялись.
Ошибка сразу раскрыта координатору (`msg_4beb7e40169a`) и сохранена в exact call log.
Последний screenshot завершён в **18:16:58.684 UTC**, после deadline новых снимков нет.
Дальнейший desktop input/capture остановлен; lease не продлевали задним числом.

После этого пользователь прямо остановил дальнейшие computer-use проверки.
Неизмеренные MenuBarExtra open/template на самом desktop, Settings через status menu
поверх другого foreground app, light-mode сравнение, физический Retina scale,
Finder/Get Info и реальная доставка shortcut получают статус
**NOT_DONE_USER_STOPPED_CUA**. Подготовленный ранее capability plan — историческая
запись; новые desktop probes и вопросы о desktop lease не выполняются. Отсутствие этих
проверок не выдано за 100% GUI success и не отменяет уже измеренные собственные и
пользовательские результаты.

Это финальная правка только отчёта. Exact installed306 остаётся тем же full bundle:
source revision `bfac4d1f736716f9ba41a1ae2927ac3cb11edb6b`, source digest
`c3231b87928d687d0030929e16ee3df32454e7fa5d56beb62279b32e2bb41420`, native SHA256
`f8fdb1edacb5cd54ce4032f495278087422feb810218d64fc9427bd75f24eb5c`, CDHash
`86db3a69b875b1037903f8dc3c4f92bf386aa19e`. Новых build/signature/settings/source
изменений нет. Source/local gates, собственная GUI-приёмка, user reports, Root peer
verification и CI/Git delivery остаются разными уровнями; финальные commit/push/CI
контролирует координатор.

## Финальная CLI-only проверка DMG306 · 05.10.2026

После остановки computer-use пользовательский scope допускал ещё одну упаковочную
CLI-проверку, которую отдельно поручил координатор. Уже проверенный signed full306
упакован существующим `scripts/package_macos_dmg.sh`, без rebuild, resign или relaunch:

```sh
scripts/package_macos_dmg.sh \
  /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/full306/Translator.app \
  /Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/dmg306
```

Команда завершилась **0**; собственные `hdiutil verify` и SHA256 check упаковщика прошли.
Локальный artifact `Translator-0.3.0-macos-arm64.dmg` содержит build **306**, размер
**27,396,598 bytes**, SHA256
`eb255c0974606bbff16092ff36942acd80f16c021540b787835cf3df848b0a55`.
Он сохранён только во внешнем `native/dmg306`; существующий public v0.3.0/tag/release
не изменён и новый public release не создан.

DMG присоединён через `hdiutil attach -readonly -nobrowse -noautoopen -mountpoint`
в единственный exact temporary directory внутри owned `native/dmg306`.
Mount не открывал Finder или приложение. Собственная проверка mounted contents дала:

| Gate | Измеренный результат |
|---|---|
| Корень тома | **PASS**: только `Translator.app` и symlink `Applications → /Applications` |
| Полное дерево app | **PASS**: все **1202 file/symlink entries**, bytes и link targets равны reviewed full306 |
| Mounted identity | **PASS**: `com.translator.desktop`, `0.3.0 (306)`, `LSUIElement=true`, minimum26.0 |
| Mounted signature | **PASS**: strict/deep codesign; CDHash `86db3a69b875b1037903f8dc3c4f92bf386aa19e` |
| Mounted native | **PASS**: SHA256 `f8fdb1edacb5cd54ce4032f495278087422feb810218d64fc9427bd75f24eb5c` |
| Семь artwork resources | **PASS**: `uv run python scripts/macos_bundle_manifest.py --verify-artwork` на mounted app |
| Curated ICNS | **PASS**: exact approved bytes, SHA256 `ca1f8328df7395ca05066fbeff9449e6ead4df2dbfefecf4c473ca7f43e3a4b3` |
| Compiled CAR | **PASS**: SHA256 `119d9a04a731edc72037a5886ccaca11b0c519ad6bcd962a905a4116ffe6f4d7` |
| SQLite/design/agent docs | **PASS**: нет SQLite file headers, project `design`, `.git`, `AGENTS.md`, `SKILL.md` или `.env` в payload |
| Завершение mount | **PASS**: exact mount штатно detached, пустой owned temporary directory удалён |

Полные argv, return codes, mount entries, Info, семь hashes, полный tree digest и detach
записаны в
`/Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/dmg306/mounted-verification.json`;
packaging stdout/stderr — `native/dmg306-package.log`, attach/codesign/artwork/detach logs —
в `native/dmg306`. Broad cleanup и изменения настроек не выполнялись. Это упаковочная
CLI-приёмка, не Finder/desktop acceptance, notarization или разрешение на публикацию.
После неё установленные app bytes/source/signature/grants и пользовательские данные
сохраняются; дальнейших computer-use действий нет.
