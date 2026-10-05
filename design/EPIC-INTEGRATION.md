# Translator Mono — внедрение

Дата начала: 05.10.2026. Основание: прямое поручение пользователя внедрить принятый набор из `final/`, без повторной генерации. Исходная база — `mac`, `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Снимок подготовки — [delivery-verification.json](delivery-verification.json); полный контракт — [THREE-AGENT-HANDOFF.md](THREE-AGENT-HANDOFF.md). История дополняется; прежние результаты подготовки не переписываются.

## Владельцы и требования

Работают ровно три самостоятельные Orca-сессии. GitHub владеет README, дизайном, Social preview, карточкой профиля и общей Git-доставкой. macOS владеет ресурсами приложения, template-знаком, двумя путями сборки и установленной копией. Web владеет сайтом, favicon и приёмкой браузеров. Полные границы перечислены в handoff. Индекс и Git операции сериализованы у GitHub. Один редактор Penpot — GitHub; готовые рисунки не меняются.

| ID | Требование и доказательство | Начальное состояние |
|---|---|---|
| B01 | Все 12 final exports совпадают с manifest и источниками по SHA256/bytes | PASS: проверено 05.10.2026 |
| B02 | Новый логотип и короткая русская подача в README; ссылки и ad-hoc ограничения сохранены; реальный GitHub render после push | IN_PROGRESS |
| B03 | Social preview: загрузка выбранной RU card, сохранение, повторное чтение и изображение; внешние кеши отдельно | IN_PROGRESS |
| B04 | Дополнительная карточка profile README с сохранением оформления либо точная отсутствующая зависимость | NOT_DONE: `gorodtx/gorodtx` отсутствует в доступном списке 12 репозиториев; прямой GET 404 |
| B05 | 10 ICNS representations и оптические размеры сохраняются; установленный AppIcon просмотрен | IN_PROGRESS: macOS |
| B06 | Непрерывный menu template 28×18 pt, 1x/2x/3x; вид light/dark/Retina и открытие меню | IN_PROGRESS: macOS |
| B07 | Оба пути сборки пакуют ресурсы до подписи; strict codesign; bundle/DMG проверены отдельно | IN_PROGRESS: macOS |
| B08 | Восстановимая замена фактической установки, exact PID, сохранение данных/grants; Settings/About/перевод/история | IN_PROGRESS: macOS |
| B09 | Web логотип обеих тем, favicon/apple-touch, единый media contract; стиль сайта сохранён | IN_PROGRESS: Web |
| B10 | HTTP root/subpath, desktop/mobile390, light/dark, focus/keyboard/reduced motion/console, просмотр PNG | IN_PROGRESS: Web |
| B11 | Chromium и Safari/WebKit имеют отдельные фактические результаты | IN_PROGRESS: Web |
| B12 | Поимённые логические коммиты, normal gates, общий push, remote SHA и CI финального SHA | NOT_DONE |
| B13 | Три role reports и registry native ID/resume/owned paths/evidence перед остановкой | IN_PROGRESS |

## Границы публичной доставки

Новый публичный release, hosting/domain и аватарка пользователя этой задачей не выбраны. Существующий `v0.3.0` и его assets сохраняются. Настоящее видео, poster/captions пока отсутствуют; имитация не допускается. Большие SQLite-базы не загружаются повторно. Дизайн и рабочие отчёты остаются в репозитории, но корневая `design/` не входит в app/DMG.

## Новые знания 05.10.2026

- Подходящая Web-сессия переиспользована. Resume сохранённого macOS ID `01a08ff5-3879-78f0-a8ea-d0d6a318ce2d` вернул native lock «This conversation is open in another app». Попытка завершена без работы; новая полноценная macOS-сессия запущена в той же третьей вкладке. Заблокированный ID не запускается параллельно.
- GitHub API подтверждает аккаунт `gorodtx`, admin/push у целевого репозитория и default branch `mac`. Это не доказательство push.
- Root `penpot-tool doctor` сначала подтвердил подключение и правильные file/page IDs. Поздние отдельные вызовы соседей получили `fetch failed`; эти наблюдения сохраняются отдельно. Runtime/MCP/VM не перезапускаются, внедрение использует проверенные экспорты.

Текущее движение и доказательства — [PROGRESS.md](PROGRESS.md); итоговые отчёты — `integration/`.

## Дополнение 05.10.2026, приёмка интеграции

- B03: сохранённый GitHub Social preview подтверждён GraphQL и HTTP200 image/png; actual CDN bytes104880/SHA совпадают с утверждённой RU карточкой. Внешнее распространение и кеши отдельно NOT_DONE.
- B09/B10: Web локально принят владельцем, Root сверил13file/6screenshot hashes и лично просмотрел desktop/mobile/focus. Chromium и HTTP root/subpath PASS; B11 Safari/WebKit остаётся NOT_DONE. Настоящего видео ещё нет; null слот сохранён.
- B05/B07: оба native builder, strict codesign и локальный DMG измерены macOS; установлен build305, отдельные Finder/Get Info screenshots доступны. Реальный menu light/dark/Retina и Settings/About/перевод/история продолжают проверяться.
- Новое требование B08: ad-hoc подпись новой сборки изменила identity и реальный Accessibility trust стал false. Недостаточно сохранённой старой настройки: приёмка shortcut требует authoritative trust после ручной reauthorization пользователя. Не сбрасывать TCC, не обходить trust и не переподписывать сборку после reauthorization. Пользователь подтвердил открытие Settings через настоящее меню.
- B12: source/design commit `db03fd9` прошёл normal gates после штатного исправления broken future Markdown link. Web/native коммиты и общий push/CI ещё ожидаются; базы не загружались.

## Дополнение 05.10.2026, source delivery checkpoint

- B12: Web13paths зафиксированы в `c2cd5c6`, native12paths в `bb8ed09`; normal gates прошли, installed305 bytes не изменились. Явный token dry-run для `HEAD:refs/heads/mac` прошёл; actual push и CI проверяются отдельно.
- B13: все native IDs/resume commands и role reports сохранены; Web terminal retained, native task остаётся live с открытыми B06/B08. Публикация source с pending acceptance не закрывает эти пункты и весь epic.
- Уточнение B04: измерено отсутствие `gorodtx/gorodtx` именно в доступном списке12repo плюс GET404. Эти факты не доказывают отсутствие любого скрытого/private репозитория. Для публичной карточки требуется доступный подходящий profile README repository; account avatar/Pins остаются вне изменения.
- Новая воспроизводимость B05: ICNS включает десять image representations плюс служебный `TOC ` chunk. Счётчик проверки обязан отличать container metadata от representations; Root исправил временный harness, approved artwork не менялся.

## Дополнение 05.10.2026, измеренная внешняя доставка

- B12 source PASS: `bb8ed09` actual push/remote SHA verified; CI run37322053249 completed/success,5applicable jobs success/notarize skipped. Evidence commit требует отдельной проверки своего SHA; новые данные дополняют журнал, прежние snapshots сохраняются.
- B02 published HTML/assets PASS: GitHub server отдаёт утверждённый img80×80 и подпись; exact src HTTP200/PNG/SHA совпадает с approved export. Browser visual screenshot остаётся UNKNOWN после пользовательской смены desktop; чужой capture удалён из evidence recoverably, не выдан за результат Translator.
- B03 PASS — upload/save/public image; B04 dependency declared — нужен доступный public profile README repository; account/Pins не менялись.
- B06/B08 всё ещё открыты: личные native visual checks и новый Accessibility/shortcut/History outcome требуют доступного наблюдения/ответа пользователя. Сохранение source/CI результата не закрывает этот участок. Ровно три самостоятельные sessions сохраняются; native ожидает один blocking outcome вместо расходующего бюджет polling loop.

## Дополнение 05.10.2026, пользовательская проверка build305

- B12: evidence commit `4236912364798b1358edd0ae84964e17f866c9ec` доставлен в `mac`, remote SHA verified. Его собственный [CI run37325030574](https://github.com/gorodtx/selection_translator_anki/actions/runs/37325030574) измерен как `completed/success`: пять применимых jobs success, notarize skipped. Это проверка текущего опубликованного commit, не приёмка нативного UI.
- B08 снова подтверждён как незакрытый дефект: пользователь прислал два снимка. В строке macOS Accessibility Translator включён, одновременно в приложении остаётся `Setup: Accessibility`. Root лично просмотрел оба снимка; успешный перевод и History из них не следуют. Повторять просьбу переключить тот же тумблер без нового диагноза недостаточно. Нужно выяснить соответствие разрешения текущему процессу/подписи и устранить конкретную причину; authoritative AX trust нельзя подменять наличием строки в настройках.
- B05 визуальная приёмка открыта заново: пользователь отверг иконку. На предоставленном снимке видна квадратная AppIcon в системной строке, она выглядит очень тёмной. Root отдельно просмотрел готовые `macOS/png/light/128.png` и `dark/128.png`: обе имеют светлую переднюю панель и клубок, поэтому сначала проверяется фактическое отображение/representation/cache, а не объявляется изменение утверждённой геометрии. Menu-bar знак этим снимком не проверен. Исторически принятые исходники сохраняются; новый результат должен быть принят отдельно.
- Native owner получил факты и оба пути напрямую через ответ на `msg_30289e89282b`; resumed diagnosis в той же самостоятельной сессии. Ровно три Orca-сессии сохраняются, новый subagent не создан. Desktop input остановлен; ручная работа пользователя не перехватывается.

Новые screenshots и hashes сохранены в [user-305-feedback.json](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/user-305-feedback.json>). Весь epic остаётся открытым.

Пользователь уточнил предмет визуального отказа: **квадратная иконка приложения**, показанная в системных настройках. Menu-bar линия этим steering не отвергнута и не меняется. Уточнение передано native owner напрямую.

## Дополнение 05.10.2026, независимый диагноз Accessibility

- Root read-only запросом только строки `kTCCServiceAccessibility/com.translator.desktop` подтвердил `auth_value=2`, но её40-byte requirement содержит CDHash build304 `0c68ccaa11c25394a315a7f36ebe4bced537e088`. У installed305 designated requirement `5dae68c3706841f4366dcf6d820e0ece6063a230`; exact PID37501 действительно запускает `/Applications/Translator.app/Contents/MacOS/Translator`. `codesign` requirement старой сборки для текущего bundle возвращает EXIT3, текущей EXIT0. Следовательно, ON относится к старой ad-hoc identity, authoritative false текущего приложения обоснован. Исправление не должно заменять AX trust чтением тумблера или убирать предупреждение при фактическом отказе.
- Новое требование порядка работ: закончить возможный ремонт AppIcon и зафиксировать окончательную подпись **до** новой ручной reauthorization. Иначе следующая переподпись снова инвалидирует только что выданный доступ. User grant/история/БД не очищаются ради исправления иконки. Ограничение ad-hoc updates остаётся явным до отдельного Developer ID решения.
- Фактическое отображение новой квадратной иконки в системной строке проверяется отдельно от Finder и PNG decode. Совпадение manifest само по себе не доказывает читаемость и принятие пользователем.

Доказательство: [independent-tcc305-review.json](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/independent-tcc305-review.json>). Доступ/подпись не изменялись этой диагностикой.

## Дополнение 05.10.2026, native appearance AppIcon

- B05: macOS Icon Services воспроизводит отвергнутую пользователем тёмную иконку при `NSWorkspace.icon(forFile:)` для installed path. Root лично просмотрел оба native32pt@2x PNG, включая Aqua drawing context; очень тёмная передняя панель и рельефный клубок совпадают с пользовательским кадром. `isTemplate=false`, выбран actual installed path, источник ICNS напрямую остаётся светлым. Это отдельное доказательство render failure, не corruption готовых PNG и не menu-bar template mistake.
- Установленный системный appearance `AppleIconAppearanceTheme=ClearDark`, tint `Graphite`. Пользовательскую системную настройку не меняем. Новое требование: собственные native appearance resources должны сохранять различение панелей, клубка и строк именно при выбранной ClearDark/Graphite, а не только при default/large Finder preview.
- Поддерживаемый исследуемый путь — Icon Composer `.icon` с режимами Default/Dark/Mono, сохранением исходной геометрии и десяти ICNS fallback representations. Обычная iOS dark/tinted схема appiconset не объявляется поддержкой macOS без измерения. Apple описывает эти режимы в [Icon Composer](https://developer.apple.com/icon-composer/) и [официальной инструкции](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).
- Native owner готовит минимальный compiler/source contract. Local CommandLineTools не содержит `actool`; используется существующий macos26 CI с официальным Xcode вместо установки большого Xcode. Узкий `.github/workflows/macos-icon-assets.yml` дополнительно передан native owner для resource-only compiler/probe, если нужен. Root выполняет review/Git/manual dispatch/artifact retrieval; gates прежних workflows сохраняются. Generated resource должен иметь exact source/CI SHA и compiler provenance; candidate проверяется в unlaunched isolated bundle через Icon Services до замены фактической установки. Compile success сам по себе не закрывает B05.

## Дополнение 05.10.2026, новые проверки качества ресурсов

| ID | Дополнительное требование | Состояние при обнаружении |
|---|---|---|
| B14 | Source digest/stable-tree guard охватывает реально используемые AppIcon appearance inputs/compiled resource и MenuBar PNG; mutation ресурса выявляется до signing, deterministic hash scope описан | IN_PROGRESS: текущий `scripts/macos_bundle_manifest.py` учитывает только AppIcon.icns из Resources |
| B15 | Official Icon Composer compiler provenance, exact source/artifact SHA, appearance Default/Dark/Mono-Clear и реальные16/32pt checks перед installed replacement; старые десять ICNS reps/16pt@2x geometry сохранены | IN_PROGRESS: официальный sample schema получен, compiler probe и runtime candidate ещё не выполнены |

Для B14 native ownership узко расширен на `scripts/macos_bundle_manifest.py`, только production resource inputs/contract. Root прочитал текущую `source_digest()` и сразу сообщил дефект владельцу `msg_f261e6054c48`; начальная реализация не меняет checksum при изменении MenuBar PNG. Корневые design/research/docs в shipped build hash и bundle не добавляются.

Для B15 macOS owner получил `.icon` schema из Apple Landmarks через validated206 ranges: прочитано101898bytes вместо скачивания336MBsample целиком. Root прочитал полученный `apple-landmarks-icon.json`, где видны groups/layers/image-name и appearance specialization; Apple artwork в проект не копируется. Перенос существующих semantic layers и native annotations не объявляется новой генерацией логотипа. Обычная catalog compilation и real Icon Services visual acceptance остаются отдельными gates.

## Дополнение 05.10.2026, результат official compiler probe

Source probe `252d89c` прошёл normal local gates и actual push/remote SHA. Manual [run37331657219](https://github.com/gorodtx/selection_translator_anki/actions/runs/37331657219), exact head252d89c, **FAIL**: official Xcode26.6 build17F113/SDK26.5 отклонил пять visible groups — разрешено максимум четыре. Дополнительные CoreSVG errors требуют диагностики. Новое ограничение B15: semantic layers можно объединять в совместимые groups, сохранять порядок/геометрию/цвет, не превышать compiler limit; успешные layers/source hashes не заменяют compiler validation.

Failed actool при этом создал Assets.car и AppIcon.icns. **Само наличие generated файлов при EXIT1 не является PASS.** Такой artifact не пакуется и не устанавливается; compiler provenance manifest не создан. Root скачал диагностический artifact, прочитал exact error и ответил native blocking ask; владелец делает узкое исправление и новый подтверждённый compiler run. Ничего не изменено в installed305/пользовательских разрешениях этой попыткой.

Дополнительный диагноз B15: native public SVG decoder воспроизвёл ошибку `gradientTransform` на пустых атрибутах `gradientTransform=""` в производных слоях. Предлагается удалить только эти no-op attributes, исторический master сохранить; before/after native raster hashes должны совпасть. Front/text/highlights можно объединить в одну совместимую group, итог три groups, исходный layer order/цвет сохраняются. Это узкая нормализация входов compiler, не новый рисунок. Source CI252d89c отдельно завершился success; compiler failure этим результатом не закрывается.

## Дополнение 05.10.2026, положительный контроль raster acceptance

При review готового retry Root обнаружил одинаковые native raster hashes трёх разных слоёв — back-panel/front-panel/text. Собственный SHA25632MBнулевого буфера **точно** совпал с reported `83ee4724…`; исходный harness сообщает2048×2048 и hash data provider. Значит прежнее before/after равенство для этих трёх слоёв не доказывает сохранение рисунка: это равенство пустых буферов. Retry остановлен **до commit/push**, native owner получил конкретный counterexample и возобновил ремонт; его предыдущий readiness не принимается как PASS.

Новое качество B15: каждый импортируемый слой обязан иметь положительный nonblank контроль — actual alpha/content counts и bounds, формат/длина native buffer, лично просмотренный raster/выход; исчезновение parser error не заменяет видимый результат. Supported import должен сохранять готовую геометрию/палитру. Если SVG patterns/filters не поддерживаются, допустим технический экспорт существующего слоя или эквивалентные поддерживаемые gradient references с валидированным render; новый рисунок и исторический master не создаются и не изменяются. [Собственный counterexample](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/blank-raster-counterexample.json>).

Дополнение B15,05.10.2026: PNG import принят как технический экспорт существующих пяти vector layers после независимых Root positive alpha/bounds/RGBA controls и личного просмотра. Exact historical geometry и fallbackICNS сохранены. Compiler input теперь3groups/5PNGs; actual official compiler и small Icon Services appearance по-прежнему обязательны до install. Старый all-zero equivalence claim отозван, новая проверка его не стирает.

Дополнение B15,05.10.2026: official compiler retry305a485/run37337286809 PASS, source/output provenance независимо проверена Root. PNG technical import принят compiler без CoreSVG errors. Следующий mandatory gate — actual small Icon Services Default/Dark/currentClearDark rendering isolated bundle; наличие compiled Assets.car и exit0 не закрывают native visual acceptance.

Дополнение B15,05.10.2026: compiler305a485 PASS, но staged Icon Services/named asset FAIL — knot/text missing, видны только панели. Приёмка требует всех пяти semantic layers в final composition, а не только положительных alpha counts импорта и compiler exit0. Неуспешный candidate запрещён к install; native fill/schema correction обязана сохранять утверждённое artwork, source/compiled hashes и small-size proof.

Дополнение B15,05.10.2026: actual compiled order должен совпадать с намеренным painter order. Icon Composer JSON описывает stack в обратном порядке относительно SVG paint array; Root independently подтвердил reversal через assetutil. Требуется explicit serialization order и verification конечных semantic details. Appearance declarations проверяются в exclusive sample schema с default/dark/mono, без конкурирующего plain fill; обещать успешный ClearDark до actual compiled render нельзя.

Дополнение B15,05.10.2026: supported specialization schema проверяется отдельно для root background и image layers. Sample layer schema нельзя автоматически применять к root. Compiler2de2b68 отверг JSON format; semantic equality и artwork preservation не являются schema PASS. Исправление обязано использовать measured/sample root declaration и сохранять correct paint order, после чего снова пройти exact compiler/native acceptance.

Дополнение B15,05.10.2026: root restoration7892411 не устранил formatFAIL. До дальнейшей production schema смены — один bounded known-valid control/default-dark variant batch, с точными declared appearance deltas и отдельной provenance. Слова Mono/Dark в UI design не доказывают raw JSON enum tokens. Цветовая декларация, compiler-valid поле и наблюдаемый runtime цвет — отдельные факты.
## Дополнение 05.10.2026, контроль schema без изменения установки

B15 дополнен bounded batch требованием: known-valid контроль и sample-based default/dark вариант должны иметь отдельные frozen inputs, hashes, exit codes, compiler logs и provenance. Overall CI success не заменяет результат каждого case. Ни один case не становится production автоматически. Native Icon Services при текущих ClearDark/Graphite и малых размерах проверяется до интеграции; перенос source metadata после compiler не должен подменять фактические input hashes. Исходный рисунок и меню не меняются. Batch source commit5c2747a прошёл normal gates и независимую Root проверку генератора; compile/native acceptance ещё ожидаются.

## Дополнение 05.10.2026, production resource checkpoint

- B14: common pre-sign packing и strict bytes/source/provenance/receipt guards реализованы в обоих builders; Root самостоятельно positive pack и4isolated mutation rejections PASS. Design/research/diagnostic inputs не копируются в приложение.
- B15: official batch compiler PASS обоих cases, staged ClearDark/Graphite16/32pt visual PASS, control выбран без нового рисунка. Exact13 compiler inputs/CAR/provenance сохранены, selection receipt отдельный. Local short/full306 strict signature/resource contract independently PASS.
- SourceCI5c2747a FAIL в существующем Apple fallback timer test учитывается отдельно. Test-only354bc92 заменяет scheduling-dependent sleep на Event и exact budget assertion;31tests и old-budget in-memory negative control PASS. Production timeouts не меняются. Новый реальный CI итогового source всё ещё обязателен.
- Actual installation306/пользовательский final grant/native UI/translation/history остаются pending. Shared desktop input требует текущей доступности, вопрос отправлен после reviewed signed bundle. До ответа выполняется независимая документация/Git delivery; весь эпик не объявляется завершённым.
- Проверенные старые результаты и ошибки не вычеркнуты. Перед остановкой каждого standalone сохранить точный native resume/cwd/branch/base/owned scope; один live nativeID не запускать повторно. Profile repository/video/DeveloperID/public hosting/release остаются ранее названными отдельными зависимостями.
