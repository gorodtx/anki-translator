# Онлайн-демо — журнал

## 13.10.2026 — D01/D02: исследование и контракт

- Роль: Root, Codex; native ID `01a1030e-0fcc-7430-8c9d-070c3f569b23`.
- cwd: `/Users/den/Documents/dev/selection_translator_anki`; branch `mac`; base/HEAD `9ccf0ad0c3536e18a77f53fe488341d55dc4b08d`.
- Owned paths этого этапа: `docs/demo/RESEARCH.md`, `docs/demo/EPIC-05-BROWSER-DEMO.md`, `docs/demo/PROGRESS.md`; датированные перекрёстные ссылки в presentation epic/progress.
- Прежние задачи прекращены по steering пользователя; текущие чужие design drafts, удалённый site video и `.codex/` не редактировались.
- Прочитаны context-continuity, preserve-project-design, project continuation capsule, исторический DB checkpoint. Данные истории проверены по текущим site, Apple provider, IPC server и translation pipeline.
- Шаблоны проверены по README, GitHub trees и actual LICENSE. AstroWind MIT; Astroship actual GPL v3 расходится с README GPL-2.0; Cruip README содержит GPL/дополнительные ограничения. Код/зависимости шаблонов не импортировались.
- Проверены официальные API/docs noVNC, Guacamole, Appetize, BrowserStack, AWS EC2 Mac и macOS Tahoe SLA. npm metadata noVNC: `1.7.0`, MPL-2.0. Actual native host/client compatibility не проверена.
- `forge-access remote` подтвердил HTTPS origin `gorodtx/selection_translator_anki.git`; `forge-access auth github` — аккаунт `gorodtx`, HTTP200. Это API-account evidence, не push auth.
- Пользователю отправлены отдельные вопросы о формате демо и наличии Mac-хоста. Ответы пока отсутствуют; настоящий macOS stream сохранён как исходный запрос.

| Уровень | Результат | Evidence / граница |
| --- | --- | --- |
| Контекст/current source | PASS | branch/log/status; `site/`; SelectionCapture; Apple provider; local IPC; translation pipeline |
| Template/API research | PASS | Точные ссылки, tree SHA и лицензии в RESEARCH.md |
| Визуальная приёмка шаблонов | NOT_DONE | Исходники/документация прочитаны, чужие live pages не принимались как наши UI |
| Решение native/web | NOT_DONE | Ответ пользователя ожидается |
| Live demo source/runtime | NOT_DONE | Страница, broker и выделенный host ещё не созданы |
| Browser/native acceptance | NOT_DONE | Runtime отсутствует; desktop не контролировался |
| Commit/push/CI | NOT_DONE | Этот этап сохранён локально; публикация не заявляется |
| Public deployment | NOT_DONE | URL/host не выбран |

Следующая работа: получить формат/host, затем реализовать D05/D06 в рамках существующего дизайна. Доступ к рабочему Mac посетителям не открывался; платные ресурсы не создавались. Эпик остаётся незавершённым.

Resume:

```sh
cd /Users/den/Documents/dev/selection_translator_anki && codex resume 01a1030e-0fcc-7430-8c9d-070c3f569b23
```

Не запускать этот native ID второй раз, пока текущая сессия работает. При продолжении сначала сверить Git и текущий пользовательский ответ, затем читать только этот журнал и исследование.

## 13.10.2026 — круговая сцена: discovery перед реализацией

Новый визуальный steering записан добавлением в эпик: Montserrat, полукруг/спираль вокруг неизменного центрального пространства, редактируемый текст, native-style popup, Cloudscape, сокращённая menu bar, glass buttons, FAQ и OS-aware download. Страницы пяти 21st references прочитаны; визуальное движение компонентов не принималось по одному описанию. Реальная папка шрифта найдена: `/Users/den/Downloads/Montserrat/`; variable upright/italic и OFL доступны. Production UI/code/assets не менялись.

Отправлены три discovery-вопроса: runtime источников, granularity selection и idle motion. Ответы ожидаются. Новые packages/skills не устанавливались; нужные design skills уже доступны. D03/D05/D06 остаются NOT_DONE. Следующий шаг — закрепить ответы и interaction contract, затем приступать к source implementation.

## 13.10.2026 — v0 source и локальная приёмка

Ответы пользователя получены: реальный серверный backend + Apple-style browser UI, desktop drag/touch tap, статичная дуга, перевод кнопкой. Созданы `web/`, `web_backend/`, `deploy/translator/`; dependency group web и отдельный CI. React/TS strict, Tailwind4/shadcn aliases проверены `npx shadcn@latest info --json`. apple-design установлен: `/Users/den/.agents/skills/apple-design/SKILL.md`, 282 строки; permanent usage rule добавлен в `web/AGENTS.md`. Связь с native app/style/data не менялась.

Collective session `term_818dd9d4-7c17-4282-a7d0-e1e05bb009d9` вернула ACK: Caddy не редактируется параллельно; наш scope — `/opt/translator`, project translator, существующая external network и только новый hostname block. Read-only baseline: Linux, Caddy2.11.6; HTTPS kt/app200; Caddyfile SHA256 `b196a6471adc8ee38261841df8dd7764b3d0726f3b7924a24355250a1393ba02`. Публичная routing configuration на этом checkpoint ещё не менялась.

На сервер впервые загружены три DB assets, все pinned SHA256 совпали. Подготовленный скрипт повторного code deployment выдаёт REUSE для совпадающих файлов. Git/image DB corpus не содержит.

Проверки:

- `uv run --group web ruff check web_backend tests/test_web_backend.py` — PASS.
- `uv run --group web python -m mypy --strict web_backend` — PASS; общий mypy — 110 sources PASS.
- HTTP adapter tests — 6 PASS: validation/isolation, body/chunk limit, concurrency/recovery, provider outage, deadline recovery, bounded rate.
- Полный Python suite в clean checkout — 305 PASS, 3 SKIP, 105.42s. SKIP не считается runtime acceptance.
- `npm run build` — PASS; TypeScript strict; JS ~424KB/~137KB gzip, CSS ~21KB/~5.5KB gzip; Montserrat WOFF2~204KB.
- `npm test -- --maxWorkers=1` — 2 PASS (platform detection, iPad/Android fallback).
- Local Firefox157 headless — drag selection реально выбрало `all Greek to me`; touch selection выбрало всю фразу; 390px без horizontal overflow; FAQ opens; page errors0. Source/local browser acceptance, **не live translation**.
- Первый browser pass выявил touch selection collapse и чёрный кадр после theme change. Исправлены; повторный PASS и light/dark PNG лично просмотрены.
- Impeccable detector: три warning по Montserrat. Шрифт прямо задан пользователем, поэтому не заменялся generic recommendation.

![Desktop light](evidence/desktop-light.png)
![Desktop dark](evidence/desktop-dark.png)
![Mobile tap](evidence/mobile-light.png)

Git checks выполняются в отдельном clean checkout `/Users/den/Documents/dev/translator-browser-checkout`, branch `translator/browser-demo`, base `9ccf0ad`. Причина: shared format check встречает три чужих untracked `design/translator-icon/github/revisions/*/build-svg.py`; эти drafts не изменены и не исключены обходом hooks. В clean checkout штатный format check PASS. Код/БД/история пользователя не сбрасывались.

README session подтвердила отсутствие overlap, canonical repository `gorodtx/selection-translator` и завершила свой Claude PID87530; её native resume сохранён внешним owner journal. Дополнительные агенты не создавались. Собственный localhost preview после проверки остановлен; браузер закрыт.

Остаётся: guarded Caddy change, final Git delivery, real deployed HTTP/DB checks, live browser screenshots, resource measurement и повторная проверка kt/app.
