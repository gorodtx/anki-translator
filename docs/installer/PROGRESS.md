# EPIC-04 · журнал исследования установщика macOS

## 2026-10-08 · 13:17 UTC · ACCEPTED

- Статус: **ACCEPTED — самостоятельное research, implementation не разрешена до ответа пользователя**.
- Provider: Codex; native session ID: `01a10c36-041c-73d3-b4a5-b96090075d82`, существующая полная Orca-сессия из входящего задания. Новый native ID, subagents, Agent/workflow и `--bg` не создавались.
- Роль: `Translator-Installer-Research-macOS`.
- Фактический cwd: `/Users/den/Documents/dev/selection_translator_anki`.
- Фактическая branch: `mac`.
- Base задания и измеренный HEAD: `f7db5653ed7c503f554d4fadfc9e531bcda068b1`; `git merge-base --is-ancestor <base> HEAD` завершился 0.
- Owned paths, только: `docs/installer/EPIC-04-INSTALLER.md`, `docs/installer/RESEARCH.md`, `docs/installer/PROGRESS.md`.
- Git index/commit/push принадлежат Root. Чужие untracked `design/final/github-repo-card-*`, `design/translator-icon/github/revisions/` и удалённый reference asset обнаружены в status; не изменялись.
- Прочитаны действующие пользовательские AGENTS.md, `/Users/den/AGENTS.md`, skills `context-continuity` и `preserve-project-design`; дополнительных AGENTS.md в `docs` не найдено.
- Новая задача заменяет завершённую branding-задачу. Исследуются no-drag установка и включённый по умолчанию checkbox «Удалить установщик» после успешной установки.
- Граница: читать код и официальные источники, создать research/epic/progress, затем предложить выбор. Installed306, опубликованный `v0.3.1-rc.1`, runtime/VM/autostart, grants, DB/History/Anki не менять. Computer-use тесты остановлены. `.env`, секреты и raw env не читать.

Следующий шаг: сверить актуальный packaging/runtime lifecycle, восстановить относящиеся к установке решения через CONTINUE/history и проверить официальные Google/Apple источники. История — evidence, не разрешение реализации.

Resume этой же сессии, только когда она остановлена и не открыта одновременно:

```sh
cd /Users/den/Documents/dev/selection_translator_anki && codex resume 01a10c36-041c-73d3-b4a5-b96090075d82
```

## 2026-10-08 · 13:26 UTC · факты и границы

- Сверены CONTINUE, релевантная проектная память и независимый history search. Исторический `scripts/install_macos.sh` отсутствует в текущем checkout; старые install/rollback/runtime результаты не присвоены новому installer.
- Прочитаны текущие `package_macos_dmg.sh`, `build_macos_app.sh`, workflow source и native bootstrap/selection/defaults/login-item/data/history источники. Сейчас DMG содержит app + Applications symlink; installer helper/PKG отсутствуют.
- Google admin source прямо описывает `GoogleDrive.pkg` внутри DMG. Точный cleanup checkbox и default-on не подтверждены официальной инструкцией и не проверялись на бинарном installer.
- Применён skill `/Users/den/.agents/skills/agent-reach/SKILL.md`: `agent-reach doctor --json` и публичный Jina Reader для страницы Google, не прочитанной обычным fetch, и JS-only Apple API. Ни profile/cookies, ни GUI, ни аккаунты не использовались.
- Apple источники подтверждают роли Developer ID/notarization, пользовательскую выдачу Accessibility, Trash API; локальный `man hdiutil` различает detach и unmount. Для безопасного cleanup требуется handoff вне mounted image и доказанный backing file; работоспособность этого будущего механизма пока UNKNOWN.
- Обязательные зависимости: пользователь выбирает A/B/C; destination/admin policy фиксируется до реализации; Developer Program нужен для стандартной подписанной публичной дистрибуции. Его отсутствие сообщено пользователем, не проверкой credentials.

## 2026-10-08 · 13:32 UTC · RESEARCH COMPLETED / DISCUSSION PENDING

- Созданы [RESEARCH.md](RESEARCH.md) и [EPIC-04-INSTALLER.md](EPIC-04-INSTALLER.md): три конкретных варианта, рекомендация A, предварительный объём, install/update/rollback/data/cleanup контракт и 14 будущих acceptance критериев. Все implementation/runtime критерии остаются NOT STARTED/не выполнено.
- **Summary path:** `/Users/den/Documents/dev/selection_translator_anki/docs/installer/RESEARCH.md`. Epic path: `/Users/den/Documents/dev/selection_translator_anki/docs/installer/EPIC-04-INSTALLER.md`. Continuity path: этот `PROGRESS.md`.
- Измеренный текущий HEAD: `ffbd50bd00071b7900952985dc185188778aa973`, branch `mac`, cwd `/Users/den/Documents/dev/selection_translator_anki`. Base `f7db5653ed7c503f554d4fadfc9e531bcda068b1` остаётся ancestor. Root commits `1310b5f` и `ffbd50b` изменили presentation/audit paths; packaging/runtime источники между base и этим HEAD не изменены.
- Canonical GitHub `gorodtx/anki-translator` сообщён Root в checkpoint. API repoID/redirect/push этим исследователем не проверялись; remote delivery не объявляется собственным PASS.
- Проверка документов: `uv run --no-project python` проверил существование относительных links, отсутствие trailing whitespace и финальные newline — PASS. `git diff --check` — PASS для tracked diff. Финальная проверка всех трёх owned файлов и SHA-256 выполняется после этой записи и перед передачей Root.
- Собственные изменения ограничены тремя owned Markdown paths. Чужие design drafts/reference deletion остались нетронутыми. Git index/commit/push не выполнялись.
- App builds, test suites, DB downloads, установку, runtime probes, grants/History/Anki/autostart/VM и computer-use не выполнял. Installed306 и public RC не менял; их нынешнее runtime состояние не выдаётся за измеренное этой сессией.
- **Передача Root:** замороженные три owned файла, measured HEAD и SHA-256 — в финальном ответе. Root доставляет их отдельно. После freeze файлы не дополняются до нового сообщения пользователя/Root.
- **Следующий шаг:** обсудить A (native helper в DMG, рекомендуется), B (PKG с отдельным решением точного cleanup UX) или C (self-install). Implementation остаётся pending ответа пользователя; публичный release и desktop acceptance потребуют отдельного scope/разрешения.

Exact resume command той же полной сессии, только после её остановки; не открывать одновременно второй экземпляр native ID:

```sh
cd /Users/den/Documents/dev/selection_translator_anki && codex resume 01a10c36-041c-73d3-b4a5-b96090075d82
```

## 2026-10-08 · после research · B SELECTED / IMPLEMENTATION DEFERRED

- Прямой ответ пользователя: **«зафиксируй вариант b но пока к реализации не переходим»**. Архитектурный выбор закрыт: **DMG + PKG + отдельный завершающий шаг с checkbox «Удалить установщик», default ON**. Реализация не разрешена; повторного вопроса A/B/C не требуется.
- Пользователь запросил объяснение текущей установки, первого перевода и полного набора возможностей. Прочитаны актуальные `docs/macos.md`, `Setup.swift`, `SetupCard.swift`, General/Sources/Anki/Advanced panes, `KeyCombo.swift`, relevant AppModel/App lifecycle и Google provider source. Это code/document review; runtime/GUI действия не выполнялись.
- Current first-run: drag DMG, ad-hoc first-open может блокироваться, embedded backend стартует с app, незавершённый Setup открывает General. Свежий shortcut default по коду — **Option + Command + T**; существующий профиль может хранить другое значение, фактический пользовательский config не читался.
- Минимальный сценарий: Services без AX grant либо hotkey с явным AX grant, плюс работающий backend и доступный source. Google provider сетевой, без пользовательского API key, не читает локальные DB. Успех полного первого lookup на чистом Mac не измерен. Apple pair загружается пользовательским действием в Sources.
- UX-находка: текущий checklist считает все три offline DB, AX и shortcut обязательными, хотя backend стартует без DB и Services не требует AX. Незавершённый Setup не равен доказанной невозможности любого перевода. Изменение gates/onboarding не входит автоматически в выбранный installer scope.
- Full-feature путь документирован отдельно: DB около 1,90 ГБ, Apple pair/Dictionary, Anki + AnkiConnect + deck/note type/field mapping, images/upsert и opt-in login item. Connection/readiness/real Anki effects различаются; пользовательские данные и grants не проверялись.
- Сначала Root попросил сохранить прежний frozen research; B был подтверждён в ответе пользователя без edits. Затем Root явно разрешил следующий docs-only checkpoint B/first-run, указав приоритет пользовательского steering над freeze. Старые записи ACCEPTED/research/freeze сохранены как история.

## 2026-10-08 · 13:43 UTC · следующий отдельный checkpoint

- Фактические cwd `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, HEAD **`ecd1da38406593f3b972433c95b177fc25fbc8d3`**. Commit измерен локально; Root доставил им прежний research. Его dry-run/actual push и remote SHA этим исследователем не проверялись.
- Изменения только в трёх owned документах: **EPIC-04-INSTALLER.md** — B/current status и обсуждение first-run; **RESEARCH.md** — выбранный B, сохранённая initial recommendation/history и подробный minimum/full-feature сценарий; **PROGRESS.md** — этот decision/continuity checkpoint.
- Base исследования остаётся `f7db5653ed7c503f554d4fadfc9e531bcda068b1`; delivered research checkpoint — `ecd1da38406593f3b972433c95b177fc25fbc8d3`. Root owns index/commit/push, README/site/shared journals; они не редактировались.
- **Summary path:** `/Users/den/Documents/dev/selection_translator_anki/docs/installer/RESEARCH.md`, раздел «Текущий сценарий нового пользователя». Epic и журнал — соседние owned файлы.
- **Ready for Root:** B/first-run docs-only дополнения готовы к отдельной доставке после scoped text/link/diff checks. Итоговые named SHA-256 и measured HEAD выдаются в финальном ответе; self-hash PROGRESS внутрь самого файла не записывается.
- Никаких app builds, runtime probes, DB downloads, install/grant/settings/History/Anki/autostart/VM/UI действий, Git staging/commit/push не выполнялось. Foreign design drafts не изменялись.
- **Осталось:** ждать отдельного разрешения реализации B; затем уточнить destination/admin/finish-helper/signing policy. До такого разрешения — только обсуждение. Desktop acceptance и public release требуют отдельного scope.

Сессия retained: Codex `01a10c36-041c-73d3-b4a5-b96090075d82`. Для возобновления после остановки, без одновременного дубля:

```sh
cd /Users/den/Documents/dev/selection_translator_anki && codex resume 01a10c36-041c-73d3-b4a5-b96090075d82
```

## 2026-10-08 · 13:52 UTC · ACCEPTED: отдельная Git-доставка B checkpoint

- Root передал exclusive Git index/commit/push lease этой существующей standalone сессии. Разрешены **только** три `docs/installer/*.md` и dated append `design/PROGRESS.md`. README/site/прочие journals остаются у Root. Foreign design drafts/deletion сохраняются; installer implementation по-прежнему **DEFERRED_BY_USER**.
- Измерены cwd `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, HEAD/base доставки **`ecd1da38406593f3b972433c95b177fc25fbc8d3`**, ancestor check EXIT0; staged paths до начала пусты. Base исследования `f7db5653ed7c503f554d4fadfc9e531bcda068b1` сохранён.
- Входящий READY manifest перепроверен SHA-256: EPIC `959aac2fa344a80dad7c87b2ef3e1d1e8499da1e34c1a59be5455da7fe297771`, RESEARCH `9ec45c11ec46c94f606f9f1f9a4770097d580bb3f645b30aaf67857f98d52823`, PROGRESS `b8e299c09974e1b3830f62a7774d7430199af65cbf74fa78c0ad1cf455565c4e` — все совпали. Delivery lease записи далее изменяют final docs hashes; новые значения сохраняются в delivery receipt.
- Прочитаны `forge-access/SKILL.md`, `references/protocol.md` и глобальная Git gate policy. `orca-git-gates doctor` PASS: shared hooks активны, local override отсутствует. Forge remote HTTPS `gorodtx/selection_translator_anki.git`; auth account `gorodtx`, API200. Это preflight, а не push PASS.
- Root receipt `/Users/den/Documents/dev/translator-evidence/2026-10-08/readme/DELIVERY.json` прочитан без изменений. Его ffbd50b production CI success и ecd1 remote receipt — peer results до независимой текущей forge проверки.
- План доставки: named staging четырёх paths → normal ASCII-English logical commit → explicit token `HEAD:refs/heads/mac` dry-run → execute → exact remote SHA/public docs → actual final CI. Только обязательные global gates, без дополнительных app/runtime/build/UI действий и без bypass.
- На момент этой записи commit/push/public verification/final CI **PENDING**. Завершённые результаты, final HEAD, hashes, время и CI URL будут записаны во внешние `/Users/den/Documents/dev/translator-evidence/2026-10-08/readme/INSTALLER-B-DELIVERY.json` и `.md`; Root receipt не редактируется. Commit не может содержать собственный SHA, поэтому self-reference commits для этих результатов не создаются.
- Native ID `01a10c36-041c-73d3-b4a5-b96090075d82`; summary — `docs/installer/RESEARCH.md` + указанный новый delivery receipt. После остановки resume этой же сессии: `cd /Users/den/Documents/dev/selection_translator_anki && codex resume 01a10c36-041c-73d3-b4a5-b96090075d82`; не дублировать live native ID.
- После docs-доставки остаётся ждать отдельного implementation указания. Public site/video/signing и будущий installer/runtime acceptance остаются pending, а не выполненными этой передачей.
