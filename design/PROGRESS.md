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
