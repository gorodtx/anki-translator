# Translator Mono — журнал внедрения

История дополняется; PASS требует измерения на соответствующем уровне. Экспорт, сборка, установленное приложение, browser, upload, push и CI не подменяют друг друга. Epic — [EPIC-INTEGRATION.md](EPIC-INTEGRATION.md).

## B001 — 05.10.2026, запуск и владение

База: `/Users/den/Documents/dev/selection_translator_anki`, `mac`, HEAD `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Dirty подготовка сохранена. Прочитаны текущие AGENTS, четыре применимых навыка, CONTINUE, независимая история и handoff. Final manifest: 12/12 файлов совпали по SHA256/bytes и с источниками. Повторная генерация не запускалась.

Run `run_9d43c4e32803`. Ровно три самостоятельные сессии Orca:

| Роль | Terminal handle | Native ID и восстановление | Состояние |
|---|---|---|---|
| Translator-Brand-GitHub | `term_d2396908-a619-4d51-8870-c7db61de6df1` | `01a1030e-0fcc-7430-8c9d-070c3f569b23`, проверен собственным `CODEX_THREAD_ID`; `codex resume 01a1030e-0fcc-7430-8c9d-070c3f569b23` из cwd проекта | Coordinator, README/design/GitHub/Git |
| Translator-Brand-macOS | `term_efe4aa70-1e38-42f6-8007-cd19a98aa55c` | `01a10c36-041c-73d3-b4a5-b96090075d82`; fresh ID подтверждён собственным индексированным сообщением сессии; `codex resume 01a10c36-041c-73d3-b4a5-b96090075d82` из cwd проекта | task `task_da34bd59e066`, dispatch `ctx_55a74ec40a6c`, turn_started и ACCEPTED |
| Translator-Brand-Web | `term_ff8490f9-add0-4475-b0a3-7b058e318f08` | Ранее сохранённый `01a10317-15e0-7c12-a4ac-dcfddc86ce9d`; live ID повторно проверяется владельцем | task `task_431645af094f`, dispatch `ctx_3f3fce8391c7`, turn_started и ACCEPTED |

До resume проверить, что native ID не выполняется в другой вкладке/приложении. Заблокированная попытка старого macOS ID завершилась в shell; новый native ID отдельный. Модель macOS фактически показана TUI как GPT-6.1-Sol xhigh, YOLO mode; общие launcher permissions не менялись. Существующие Root/Web TUI также показывают GPT-6.1-Sol xhigh. Subagents/Agent/workflow/--bg не использовались.

Owned paths каждой роли — handoff; macOS/Web не используют index/commit. Root — единственный владелец общего журнала и редактор Penpot. Desktop GUI lock первоначально у Root для Social preview; остальные выполняют source/build или свои browser checks. Пользовательский лимит 40% daily сохранён; точный daily meter этой сессии недоступен, процент не выдумывается. Большие DB/VM проверки не повторяются.

## B002 — GitHub и исходники

`forge-access remote` подтвердил `github.com/gorodtx/selection_translator_anki.git` HTTPS. `forge-access auth github`: аккаунт `gorodtx`, user HTTP200, push ещё не проверен. Metadata repo GET: admin/push=true, default branch mac, homepage пустой. `gorodtx/gorodtx` GET404; полный доступный список аккаунта содержит 12 репозиториев, profile match отсутствует. Карточка профиля — NOT_DONE с зависимостью от существующего profile repository; новый репозиторий не создаётся автоматически.

README локально использует final PNG и принятую русскую подпись. Platform/download/ad-hoc ограничения сохранены. Remote render, общий push и CI ещё не проверены.

Penpot Root doctor: PASS, pluginConnected=true и ожидаемые file/page IDs. Более поздние doctor/overview соседей: `fetch failed`, UNKNOWN для их вызова. Изменения runtime/autostart не выполнялись.

## B003 — 05.10.2026, GitHub Social preview

Через существующий Firefox открыт отдельный tab целевых Settings, подтверждён аккаунт `gorodtx`. Выбран `design/final/github-repo-card.png` через штатный file picker. AX нажатие пункта upload само по себе не открыло picker; keyboard Tab/Return на реально выбранном пункте сработал. Coordinate action вернул `noWindowsAvailable`, сохранён как непройденная попытка, обходных UI технологий не использовалось. PNG1280×640/104880 bytes выбран по точному пути. После upload карта лично просмотрена в Settings.

Первый screenshot после reload не показал картинку: [наблюдение](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/social-preview-after-reload.png>). Оно не выдано за положительную проверку, причина пустого отображения отдельно не установлена. Независимый GraphQL read после reload подтвердил `usesCustomOpenGraphImage=true` и сохранённый [public image URL](https://repository-images.githubusercontent.com/1123960100/5166e0fa-be57-4ed3-8f02-de94d7fb5ef1). Фактический CDN GET: HTTP200, image/png, 104880 bytes; SHA256 `78e5d0c85926e507ee4ce7fa808111e3acda6db5c2d3db4836b7f60630af2deb` точно совпал с утверждённым источником. [Скачанный и лично просмотренный PNG](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/published-social-preview.png>), [saved metadata](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/saved-open-graph.json>), [проверка hashes](integration/github-assets.json).

Upload/save/persistence/actual image: PASS. Кеши и распространение в Telegram/других внешних платформах: NOT_DONE. macOS получил GUI lock для установки и приёмки. Общий push/CI пока NOT_DONE.

## B004 — выбор Git scope

Корневая `design/` содержит 231 файл/62 144 381 bytes на момент inventory. Подготовленные архивы сохраняются локально и исключены через `design/.gitignore`; ещё исключена точная дублирующая menu-bar `.penpot` копия. Канонический `.penpot`, геометрия, генераторы/codec, optical exports, reference и final assets сохраняются в Git. По именам private account/compose/cookies/credentials/token/.env совпадений нет; это ограниченный inventory, не заявление о всеобщем secret audit. Оба архива не применяются к runtime сборке и не входят в DMG.

## B005 — 05.10.2026, первый commit и проверка Web

Нормальный commit `db03fd9f9540eebcb6dadeafc4cb8c094337dcae` — `feat: adopt the approved Translator Mono identity`: 231 поимённо выбранный файл GitHub/design, без native/Web production paths. Первый gate остановил commit из-за ссылки на ещё не созданный native report; ожидаемый путь записан обычным текстом, normal commit повторён без bypass. Ruff, Python format и mypy прошли. [Первый FAIL](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/commit-design.log>), [повторный PASS](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/commit-design-retry.log>). База `6931540` остаётся предком HEAD.

Web returned `worker_done/succeeded` для локального scope, retained `ctx_3f3fce8391c7` без process action. Его native ID `01a10317-15e0-7c12-a4ac-dcfddc86ce9d` подтверждён независимым Orca search по собственному прежнему сообщению, title/cwd/branch; это исторический native mapping, отдельный live UUID пока не прочитан. Exact resume из cwd проекта: `codex resume '01a10317-15e0-7c12-a4ac-dcfddc86ce9d'`, только после остановки существующей сессии.

Root независимо перепроверил 13/13 production/report SHA и 6/6 screenshot SHA по manifest `a2521fd7526d882c6d8ee959ef9409446742fee3178ebcb2ca432a2b02d7d33b`, повторил оба `node --check`, просмотрел исходный diff и лично [desktop light](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/desktop-light.png>), [mobile390 dark/subpath](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/mobile-dark-subpath.png>) и [keyboard focus](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/keyboard-focus.png>). Исходный SF/system, blue-neutral, одна колонка и реальный пустой video slot сохранены. Browser/HTTP execution принадлежит Web и подтверждается его logs; Root не выдаёт чужой запуск за свой. Chromium PASS, Safari/WebKit NOT_DONE, видео ожидается, public deploy NOT_DONE. Полный отчёт: [web.md](integration/web.md).

Native build305 установлен с восстановимым backup304. Root прочитал resource-loading/packing diff; все три representations имеют 28×18 pt и `isTemplate`, оба builders копируют MenuBar до codesign. Меню/Settings/grant ещё проверяются владельцем: пользователь ответил «Settings открыты», ответ передан напрямую macOS в 13:38 UTC. Старый ad-hoc grant стал false — сохранение grants не объявляется PASS, TCC reset/auto-grant не выполняются.

## B006 — 05.10.2026, Web/native commits и независимое чтение bundle

`c2cd5c6` — `feat: integrate approved Translator Mono web branding`, ровно13 paths с manifest Web. `bb8ed09bdbe407e6b159abaaf79d84127dbedd06` — `feat: integrate Translator Mono native icons`, ровно12 frozen native paths, открытый native report не включён. Каждый normal commit прошёл Ruff/format/mypy; native дополнительно Swift release build94,43s. [Web gate log](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/commit-web.log>), [native gate log](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/commit-native.log>). Shared index пуст после commit; остальные changes — только журналы/отчёт.

Root проверил12/12 frozen native source hashes, strict installed codesign EXIT0, десять image representations ICNS и все три MenuBar PNG installed=source=approved. Реальный bundle305 сохраняет ID/LSUIElement, корневой `design/` в Resources отсутствует. [Фактический read-only результат](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/installed-resource-review.json>). Первый временный harness ошибочно считал `TOC ` image representation; затем исправлены счётчик и опечатка синтаксиса временного скрипта. Product/source для прохождения проверки не менялись.

Root лично просмотрел native [Finder](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/installed305-finder.png>), [Get Info](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/installed305-get-info.png>) и [local DMG](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/native/local305-dmg-finder.png>). Menu screenshots и actual native translation/history пока UNKNOWN: после ручного открытия Settings три поддерживаемых CUA attempts владельца всё ещё timeout, перезапуск приложения/подписи/инструментов не выполняется. Авторитетный false измерен собственным таймером приложения; Root отправил пользователю отдельную проверку ручного доступа, ⇧⌘T и History, ответ ожидается.

Повторный actual Settings screenshot GitHub теперь показывает сохранённую Social card в нижней части viewport: [UI capture](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/social-preview-saved-ui.png>). Полный CDN PNG проверен отдельно. Native Firefox coordinate scroll вернул `noWindowsAvailable`, keyboard Next не переместил viewport; это ограничения инструмента, не скрытые PASS. Повторная загрузка изображения не выполнялась.

## B007 — 05.10.2026, delivery checkpoint

Явный `forge-access push --transport token --ref HEAD:refs/heads/mac` dry-run завершился EXIT0 для source SHA `bb8ed09bdbe407e6b159abaaf79d84127dbedd06`: [receipt](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/push-dry-run.log>). Это ещё не actual branch acceptance. Последующий `--execute` запущен с теми же transport/ref; final receipt ожидается. Проверки выполняются штатным shared hook в отдельном checkout; их не отключали ради скорости. Пока этот Git процесс активен, index и новые commits не используются.

В 13:52 UTC native owner заморозил отчёт [macos.md](integration/macos.md): 17591bytes/SHA `1f0d045d0d284de27dab8628b7319241ba83cc853f45837044d7b3015ad658c4`, Root совпадение проверил. Сессия остаётся live, task `task_da34bd59e066` не закрыта, `worker_done` не прислан. Замороженный checkpoint содержит открытые B06/B08 и pending пользовательский ответ; freeze не является native UI PASS.

В 13:55 UTC Root выполнил read-only `defaults read com.translator.desktop accessibilityTrusted` → `0`, `hotKey` → `17:768`. Это собственное сохранённое состояние приложения, обновляемое его Settings timer; Root не выдал его за самостоятельный вызов AX API. Native PID/identity не менялись агентом. Пользовательский ответ на перевод/History пока отсутствует.

Повторный независимый Orca search нашёл актуальное собственное сообщение Web 05.10.2026 13:35:31 UTC с тем же native ID `01a10317-15e0-7c12-a4ac-dcfddc86ce9d`, cwd и branch. Таким образом mapping подтверждён текущим provider журналом этого захода, а не только старой заметкой. Дубликат сессии не запускался. Root/macOS/Web registry и точные resume commands сохранены выше; перед resume сначала проверить отсутствие live копии ID.

## B008 — 05.10.2026, source push, опубликованный README и CI

В14:06:37 UTC `forge-access ... --transport token --ref HEAD:refs/heads/mac --execute` завершился EXIT0, remote SHA ровно `bb8ed09bdbe407e6b159abaaf79d84127dbedd06`, `verified=true`: [фактический receipt](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/push-source.log>). Source push PASS. Общие hooks не отключались; большие БД/публичные release assets не отправлялись этой операцией.

[CI source commit](https://github.com/gorodtx/selection_translator_anki/actions/runs/37322053249) завершился `completed/success`: lint/types/tests, linux engine parity, swift sidecar, swiftui shell и app bundle —5success; notarize —skipped. Проверен именно headSha `bb8ed09…`. Bundle job отдельно прошёл runtime smoke, строгую подпись после tests, DMG contract и upload CI artifact. CI artifact не объявляется новым GitHub release. Следующий evidence commit требует собственной remote/CI проверки; её финальный receipt сохраняется вне Git после получения фактического SHA, чтобы не создавать бесконечный цикл документационного самоописания.

[Опубликованный README](https://github.com/gorodtx/selection_translator_anki/blob/mac/README.md): API blob SHA `3457bb3575deb6dff7c3ef75be3fe999bd43238d`. Actual server-rendered HTML содержит утверждённый img80×80 с alt и подписью; [выбранные image tags](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/published-readme-image-tags.json>). Его **реальный src** `/gorodtx/selection_translator_anki/raw/mac/design/final/translator-logo-1024.png` после redirect вернул HTTP200/image/png/213345bytes и SHA `f03ec4613c4c05c86ddde54441b46bec8e016519c27a362442b24979d9ffbcf7`, совпавший с final export. [Полученный PNG](</Users/den/Documents/dev/translator-evidence/2026-10-05/brand/github/published-readme-exact-src.png>) лично просмотрен Root. Published HTML/assets PASS; browser screenshot UNKNOWN. Native CUA navigation сначала отставала, clipboard read timeout, затем AX title/URL показали README; actual capture уже показал постороннюю текущую вкладку после смены desktop. Посторонний снимок не выдан за README evidence, перенесён в recoverable Trash, в Git не включён. Дальнейший desktop input остановлен, чтобы не мешать пользователю.

В14:16 UTC native owner получил явное решение **keep dispatch waiting**; idle TUI projection не трактуется как смерть/завершение сессии. Для бюджета40% он ожидает фактический grant/translation/History outcome через один blocking ask, без активных model polling циклов, новых sessions, signing и тестов. Пользовательский вопрос остаётся pending. B06/B08 открыты и весь epic не отмечен завершённым.
