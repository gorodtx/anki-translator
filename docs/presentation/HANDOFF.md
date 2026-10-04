# Передача Presentation Layer — 04.10.2026

Статус: **минимальный layout принят локально; настоящее видео и новый логотип ожидаются; Git/публикация принадлежат Root**. Run `run_d864a8251060`, presentation owner `term_ff8490f9-add0-4475-b0a3-7b058e318f08`. Checkout `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, implementation base/HEAD `ab838767b29744f13463749c86e2443bf306e293`. Native app, backend, пользовательские профили и release files не менялись.

## Что передаётся

Короткий русский README и одна колонка статического лендинга: system/SF typography, существующая синяя/нейтральная палитра, light/dark, центральный слот настоящего видео, один download CTA и точные условия prerelease. Технические сведения перенесены в [development.md](../development.md). Новых dependencies/build tools нет. `site/media.js` — единственный контракт assets: video/poster/captions `null`, текущая иконка provisional только в metadata/docs. Это честный preview без записи приложения; Canvas/generated media/fixture translation/DB endpoint отсутствуют.

Исследование пяти README, пяти лендингов, официальных video/SQLite источников и 21st metadata/трёх реально просмотренных PNG находится в [RESEARCH.md](RESEARCH.md). Чужие assets/code не включены. Новый steering пользователя отменил агентную генерацию видео/лого и приостановил DB lab; первоначальные результаты и ошибки сохранены в журнале и внешнем archive.

## Точный план одного согласованного коммита

Предлагаемый English title: `feat: add a minimal Russian presentation for Translator`. README и site следует доставлять вместе, чтобы локальные ссылки оставались целыми. Только Root управляет `.gitignore`, индексом, normal gates, commit/push; presentation owner ничего не stage/commit/push. `.gitignore:314 /site` сейчас скрывает шесть site paths: Root должен узко разрешить source delivery без включения DB/архивов/генерируемых media и без обхода gates. Ниже ровно 18 presentation-owned файлов, без wildcard staging:

```text
README.md
docs/development.md
docs/presentation/21ST-REFERENCES-2026-10-04.json
docs/presentation/EPIC-03-PRESENTATION-LAYER.md
docs/presentation/HANDOFF.md
docs/presentation/PROGRESS-DELIVERY.md
docs/presentation/RESEARCH.md
docs/presentation/VIDEO-BRIEF.md
docs/presentation/evidence/minimal-desktop.png
docs/presentation/evidence/minimal-keyboard.png
docs/presentation/evidence/minimal-mobile-dark.png
docs/presentation/evidence/minimal-mobile-reduced.png
site/README.md
site/app.js
site/assets/icon.png
site/index.html
site/media.js
site/style.css
```

Ни `.playwright-mcp`, ни SQLite, ни generated WebM/poster, ни внешние reference PNG/logs не входят в этот список. Root отдельно записывает [delivery receipt](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation-handoff-receipt.json). Точные bytes/SHA256 всех 18 paths и четырёх PNG будут сохранены во внешнем `/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/presentation-freeze.json`; digest готового manifest передаётся через Orca после последнего изменения журнала.

## Проверено локально

Root `msg_e128f3ec607a` в 19:52UTC лично просмотрел четыре minimal PNG и принял layout, подтвердил HTTP200/byte-match `index.html`, Node syntax, whitespace diff и пустой индекс. Это read-only review Root, отдельный от browser checks presentation owner.

Presentation owner реально проверил Chromium desktop 1440×1000 и mobile 390×844: без horizontal overflow; light/dark; Tab → skip link → Enter/main → download focus outline, без скачивания DMG; reduced motion — transition 0s/animations 0; настоящая запись отсутствует, video hidden/src null/autoplay false/loop false/Canvas 0. Нормальная консоль: 0 errors/0 warnings, только локальные CSS/JS/icon/media requests. UA Chrome154 на MacIntel — browser identity, не доказательство Safari/physical macOS compatibility.

Четыре реальные screenshots приватного browser preview **лично просмотрены**:

- [Desktop](evidence/minimal-desktop.png): исходный capture до последней добавки `system-ui` fallback и focusable main; эти изменения не меняли показанный layout.
- [Keyboard focus](evidence/minimal-keyboard.png).
- [Mobile, reduced motion](evidence/minimal-mobile-reduced.png).
- [Mobile, dark](evidence/minimal-mobile-dark.png).

Это screenshots лендинга, **не записи native приложения**. Отдельный missing-video negative control через own browser route вернул expected404 и честный fallback «Видео пока недоступно», сохранил CTA; после снятия route source снова null. [Error screenshot](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/browser-transients-20261004T1955/presentation-minimal-video-error.png) лично просмотрен и хранится только внешне. Ошибка не скрыта под общим PASS. Семнадцать own browser transients (1 095 472 bytes) сохранены с SHA256 и удалены exact named paths: [manifest](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/browser-transients-20261004T1955/manifest.json). Чужие пути не чистились.

Финальная source проверка: 99 local Markdown links, пять HTML local references, valid refs JSON, existing Python command/module paths и byte-match текущей icon; corrected links EXIT0. Первый проход EXIT1 сохранил ошибочную GNOME directory link и ещё не созданный freeze path; GNOME link исправлен, pending freeze path указан как plain code до передачи. `node --check site/app.js` / `site/media.js` и tracked owned `git diff --check` — EXIT0. Source review исправил dark-hover контрастный дефект: actual final Chromium hover даёт text `rgb(11,21,35)` / background `rgb(99,170,255)`, reduced transition0s и нормальную консоль0; [raw result](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/final-dark-hover-browser.json). Это последняя правка CSS после четырёх PNG, не меняющая их non-hover layout.

Логи исходников/ссылок/Node/whitespace/base приведены в [PROGRESS-DELIVERY.md](PROGRESS-DELIVERY.md). Scoped checks не заменяют normal Git gates Root, CI, native acceptance или public runtime. Исторические generated-preview/readonly-DB PASS и RED сохранены и не перезапускались после остановки scope. VoiceOver, physical device и reduced-transparency/high-contrast rendering отдельной browser приёмкой здесь не подтверждены.

## Preview и дальнейшие gates

`http://127.0.0.1:8765/` оставлен для пользователя до Root acceptance. Это только собственный static loopback server, session37950; DB API отсутствует. Воспроизведение:

```bash
uv run --no-project python -m http.server 8765 --bind 127.0.0.1 --directory site
```

После передачи edits заморожены. Root может принять файлы/доставку и сообщить, когда собственный preview можно остановить; чужие процессы и installed app не трогаем.

| Gate | Текущий результат / конкретная зависимость |
| --- | --- |
| Russian README/minimal site/source/browser | Локально готовы; Root layout review accepted |
| Новый логотип / настоящая запись | WAITING_USER_VIDEO_LOGO; пользователь создаёт самостоятельно; [capture brief](VIDEO-BRIEF.md) |
| Настоящее playback, Safari/WebKit, mobile physical device | UNVERIFIED; видео ещё нет, новый codec/render/recording не подменять simulation |
| Git delivery / normal gates / CI | PENDING_ROOT; index/HEAD peer не изменял, /site ignore adjustment принадлежит Root |
| Public hosting / HTTPS / MIME / byte ranges / cache/CSP | NOT_DEPLOYED; выбирать и проверять после Root решения; localhost не public URL |
| D05 Developer ID/notarization/Gatekeeper | BLOCKED: Apple Developer Program отсутствует; ad-hoc prerelease, публичный Gatekeeper success не подтверждён; caveat рядом с CTA |
| DB web prototype | PAUSED_USER_STEERING; архивный readonly research не public product, права corpus UNKNOWN |
| Shared daily cap | 40% для двух существующих сессий, точный meter UNKNOWN; новых agents/VM/полных suites нет |

Полный EPIC-03 пока **не завершён**: layout готов независимо от пользовательских assets, но настоящий demonstration и публичная доставка ещё требуют своих фактов. Существующая полная сессия сохранена для продолжения; старые settled Dispatch IDs не использовались.
