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
