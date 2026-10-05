# Translator Mono — внедрение в web

05.10.2026. Результат: **APPROVED_LOGO_INTEGRATED; SOURCE_HTTP_CHROMIUM_PASS; SAFARI_UNVERIFIED; NO_PUBLIC_DEPLOY**. Настоящее видео ожидается. Это отчёт самостоятельной роли Translator-Brand-Web, не отчёт о native-приложении или общей Git-доставке.

## Сессия, база и продолжение

- Native Codex ID: `01a10317-15e0-7c12-a4ac-dcfddc86ce9d`; Orca handle `term_ff8490f9-add0-4475-b0a3-7b058e318f08`.
- Task `task_431645af094f`, Dispatch `ctx_3f3fce8391c7`, Run `run_9d43c4e32803`; Coordinator `term_d2396908-a619-4d51-8870-c7db61de6df1`.
- Cwd `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, base/начальный HEAD `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Финально проверенный HEAD `db03fd9f9540eebcb6dadeafc4cb8c094337dcae`: Coordinator параллельно создал `feat: adopt the approved Translator Mono identity`, ancestry базы повторно exit0. Этот коммит содержит общие design/root README, web paths остаются незакоммиченными; Git index/commit/push не изменялись этой ролью, собственного commit SHA нет.
- ID подтверждён самостоятельно `orca search 'Минимальный Presentation Layer реализован' --path /Users/den/Documents/dev/selection_translator_anki --agent codex --scope conversation --sort newest --limit 5 --json`: один hit, совпали ID/title/cwd/branch и прошлое собственное сообщение. Coordinator mapping `msg_e126fd2be046` сходится. Первичная guessed `terminal info` вернула invalid_argument; supported show/list подтвердили handle, но не UUID.

Точная команда из Orca search для **остановленной** сессии:

```bash
cd '/Users/den/Documents/dev/selection_translator_anki' && codex resume '01a10317-15e0-7c12-a4ac-dcfddc86ce9d'
```

Сессия сейчас сохраняется в существующем терминале: не запускать этот native ID одновременно второй раз. При продолжении перечитать актуальные AGENTS, re-list handles и сверить Git/переданную задачу. Coordinator владеет `design/PROGRESS.md`; native ID/resume/owned paths/result также записаны в разрешённом [presentation journal](../../docs/presentation/PROGRESS-DELIVERY.md) для добавления в общую registry.

## Принятые исходники и изменения

Перед правками проверены **все 10** подготовленных web paths из `design/delivery-verification.json`: каждый SHA совпал. Пять production exports совпали byte-for-byte с source и `design/translator-icon/asset-manifest.json`. Ни экспорт, ни artwork не перегенерированы.

| Production path | Утверждённый источник | Проверка |
| --- | --- | --- |
| `site/assets/icon.png` | `design/translator-icon/web/logo-64.png` | Small raster64×64 для logical32; SHA `ff35a8a41390da25b3cc38eb3988f9aaf0447c5b7b2509d8d250fb1bfa7f317a` |
| `site/assets/logo-dark-small.svg` | `design/translator-icon/web/logo-dark-small.svg` | Dark Small logical32; SHA `a078aaf19256818a7fc6d174b9aac198561892aec31959cd4d9d0e2ec659ab16` |
| `site/assets/favicon.svg` | `design/translator-icon/web/favicon.svg` | Tiny geometry, valid XML/unique IDs; SHA `f49615436130cb1e442e6c14d33fbdf1eea65643bac854076147282db3292a17` |
| `site/assets/favicon.ico` | `design/translator-icon/web/favicon.ico` | Реальные ICO16×16/32×32 entries/bounds; SHA `383ad0195e51803c4ce96cf028b289dffaa6fd3d478b1bcca05527fa6b516ee5` |
| `site/assets/apple-touch-icon.png` | `design/translator-icon/web/apple-touch-icon.png` | PNG180×180; SHA `24ef250c79f97b883db9abe2fb9e0b8c1b6904ef3a7cdf0bc14e2c2c18e2bc8a` |

SVG не содержат scripts/raster images/external href/animation. Icon64 и apple-touch180 лично просмотрены как файлы; actual Small/Dark/Tiny и Apple180 дополнительно просмотрены на диагностическом browser screenshot. Navbar `<picture>`/`logoDark`/CSS prepared изменения сохранены без переписывания. В этом заходе после validation изменены `logoProvisional=false`, комментарий media contract, favicon `sizes=any`/apple-touch `sizes=180x180` и актуальное состояние/provenance/preview lifecycle в site README. Assets, app.js и style.css сохранены по исходным SHA.

SF/system fonts, синяя/нейтральная палитра, одна колонка, один download CTA и честный пустой видео-слот сохранены. `video`, `poster`, `captions` — null; никакого fake screencast/Canvas/перевода. Inter из GitHub card не подключался. Абсолютные canonical/OG/Twitter URL не задавались: public hosting не подтверждён. Download по-прежнему относится к старому v0.3.0(295), Apple Silicon/macOS26+, DMG25,23МБ и ad-hoc/noDeveloperID/noApple notarization/publicGatekeeper UNKNOWN; брендинг не выдаётся за обновлённый публичный app release.

## Выполненные проверки

Все команды Python выполнялись через `uv run`. Evidence root: `/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web`; фактические argv/UTC/HEAD/exit/logSHA — в [журнале](../../docs/presentation/PROGRESS-DELIVERY.md).

| Уровень / команда | Фактический результат |
| --- | --- |
| `git status --short --branch`, `git log -5 --oneline`, `git merge-base --is-ancestor 6931540ad76a6ab7a5abe70d49c513e93e881d36 HEAD` | mac/base совпали, ancestry0; соседние dirty files сохранены |
| `uv run --no-project python …/validate_assets.py` | 10prepared hashes и5approved asset hashes MATCH; PNG/XML/ICO проверки EXIT0; [baseline-assets.json](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/baseline-assets.json) |
| `node --check site/app.js`, `node --check site/media.js` | Каждый EXIT0 |
| `uv run --no-project python …/check_http.py` | Local references без broken links;18HTTP200/byte-match для9files в root и `/translator/`; SVG/ICO/PNG/JS/CSS MIME фактически прочитаны; [результат](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/http-source-links.json) |
| `browser-check.js` через Playwright | Изолированный context, Chrome154; desktop1440×1000 light/dark и mobile390×844 light/reduced/root + dark/reduced/subpath; выбран правильный Small/DarkSmall currentSrc32px, no horizontal overflow |
| Keyboard/reduced motion | Tab→skip, Enter→main, Tab→CTA; outline solid3px; reduced transition0s/animations0; кнопка скачивания не активировалась |
| Favicon/navbar/browser | `<picture>` selected real variant; SVG/ICO/apple-touch реально decoded, ICO natural32 и PNG180; это local HTML/image acceptance, не проверка Safari tab icon или iOS home screen |
| Console/network | 0errors/0warnings/pageErrors0/HTTP4xx0/external resources0 на actual landing; лишь localhostrequests; [browser-final.json](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/browser-final.json) |
| Penpot shared `doctor`, `overview` | Оба EXIT1 `fetch failed`; live MCP UNKNOWN, не восстанавливался. Готовые exports использованы независимо; глобальные VM/MCP/profile/autostart не менялись |

Первый browser attempt вернул `Logo theme mismatch`, сохранён [RED](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/browser-attempt-1.json). Отдельное реальное измерение показало immediate dark=true/currentSrc=light и settled currentSrc=DarkSmall после picture selection/load: [timing](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/theme-selection-timing.json). Проверочный harness исправлен ожиданием фактического selected source и `decode`; production не изменялся ради обхода проверки. Обычная dark смена могла иметь одну150ms CSS transition; reduced mode проверен отдельно и дал0. Предыдущие RED/история остаются сохранёнными.

## Снимки лично просмотрены

Ни один снимок ниже не выдаётся за native app runtime или настоящую видеозапись. Пять первых — actual browser captures текущего лендинга; последний — диагностическая HTML-полоса реальных утверждённых exports, без реконструкции приложения.

- [Desktop light](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/desktop-light.png).
- [Desktop dark](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/desktop-dark.png).
- [Mobile390 light/reduced](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/mobile-light-reduced.png).
- [Mobile390 dark/subpath](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/mobile-dark-subpath.png).
- [Keyboard focus](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/keyboard-focus.png).
- [Small/Dark Small/Tiny/Apple180 диагностический render](/Users/den/Documents/dev/translator-evidence/2026-10-05/brand-web/approved-assets-browser.png).

## Остановка preview и границы доставки

Own static preview был запущен **только для actual checks**: `uv run --no-project python -m http.server 8873 --bind 127.0.0.1 --directory …/preview-root`, session58618, PID29720. Root/subpath fixture состоял только из шести symlinks на site, без DB/copied assets. Перед TERM подтверждён exact PID/command; `kill -TERM 29720` EXIT0, session EXIT143, post `lsof -nP -iTCP:8873 -sTCP:LISTEN` EXIT1/empty — ожидаемое подтверждение отсутствия listener. Browser contexts закрыты в finally. Шесть exact own symlinks удалены, production source не удалялся. Серверы/контейнеры фоном не оставлены; системный desktop GUI, installed app, profiles, TCC, Anki и network settings не тронуты.

Передать Coordinator ровно следующие13namedpaths, включая подготовленные ранее изменения; общий stage/commit/push выполняет Coordinator после своих normal gates:

```text
site/README.md
site/app.js
site/media.js
site/index.html
site/style.css
site/assets/icon.png
site/assets/logo-dark-small.svg
site/assets/favicon.svg
site/assets/favicon.ico
site/assets/apple-touch-icon.png
docs/presentation/PROGRESS-DELIVERY.md
docs/presentation/EPIC-03-PRESENTATION-LAYER.md
design/integration/web.md
```

Final bytes/SHA всех13paths и6PNG будут сохранены во внешнем `web-ready-manifest.json`, после последней записи journal; digest передаётся через Orca status. Снимки/внешние tools/logs не добавлять автоматически в Git. Предлагаемый English commit title: `feat: integrate approved Translator Mono web branding`; группировку с общими design assets выбирает Coordinator. Собственного staging/commit/push нет, normal Python/Swift gates и CI принадлежат Coordinator, здесь не дублировались.

Оставшиеся gates: **Safari/WebKit/physical-device rendering UNVERIFIED**; video/captions/poster **WAITING_USER_VIDEO**, actual playback не проверен; live Penpot **UNKNOWN**; public hosting/deploy/canonical/OG **NOT_DONE** и не авторизованы этим scope; D05 **BLOCKED** по сохранённым release условиям; Git/remote/CI **PENDING_COORDINATOR**. Web logo scope локально завершён, полный presentation/app/release не объявлен готовым. Shared daily ceiling40%, exact meter UNKNOWN; новых сессий/агентов/VM/DB waves/зависимостей нет.
