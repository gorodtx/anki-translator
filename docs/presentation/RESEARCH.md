# Исследование — Presentation Layer Translator

Статус на 04.10.2026: **RESEARCH_COMPLETE; MINIMAL_LAYOUT_LOCAL_ACCEPTED; WAITING_USER_VIDEO_LOGO**. Translator1-Distribution принял прямой handoff от `ab838767b29744f13463749c86e2443bf306e293`, branch `mac`, Run `run_d864a8251060`. Первоначальный brief ниже сохранён как история; актуальные выводы — в датированном исследовании после него. Требования: [эпик](EPIC-03-PRESENTATION-LAYER.md).

## Действующее решение после user steering 19:38UTC

Пользователь сам готовит real screencast и новый logo; сообщение Root `msg_4eb531224ca9`/ACK `msg_84c04c61fd1a`. Прежний Canvas/MediaRecorder/illustrated selection flow **SUPERSEDED**, DB PoC **PAUSED**. Реально достигнутые source/browser/WebM/DB результаты ниже сохраняются исторически, не объявляются текущим продуктом. Код/render/PNG перенесены в [external archive](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/superseded-20261004T1939), public active site не содержит generated frames, fixture translations, DB endpoint или видео. Текущая реализация — минимальный vanilla layout/system font/short native CSS feedback; `site/media.js` real video/poster/captions пока null, provisional existing icon replaceable. README17lines, техническое содержимое отдельно.

Дополнительно прочитаны `apple-design`, `minimalist-ui`, `emil-design-eng` из `/Users/den/.agents/skills`. Generic serif, pastel palette/bento, faux OS chrome, scroll-reveal и ambient motion не заменяют native identity и прямой minimal scope. Применяем spacing/type hierarchy/ответ на нажатие/visible focus/reduced motion, без новых libraries. Current video play/decode ждут настоящего footage; будущий demo не должен autoplay/loop.

Root принял локальный layout 19:52UTC (`msg_e128f3ec607a`) после собственного read-only source/HTTP/PNG review. Четыре текущих browser screenshots, keyboard/reduced-motion/missing-asset checks и source verification перечислены в [handoff](HANDOFF.md). Пустой slot не доказывает playback; Safari, настоящее видео/новый logo и публичный hosting ещё не проверены. D05 ad-hoc/Gatekeeper ограничение сохранено рядом с CTA. Исследовательские 21st/DB/generated-preview результаты ниже остаются датированной историей; активный сайт их не импортирует.

| Before | After | Why |
| --- | --- | --- |
| Нарисованная selection сценка/24s generated WebM | Честный пустой real-video slot, controls доступны после actual asset | Новое прямое решение пользователя; не подменять запись иллюстрацией |
| Hero + steps/features/setup + много paragraphs | Один заголовок/одна строка/видео/CTA/platform/signing detail | Предметный показ и минимальная подача; необходимые условия выпуска не скрываются |
| Broad animation/interactive fixture | Короткое CSS press feedback, no motion on keyboard/reduced state | Обратная связь без новой app simulation и лишнего движения |
| Code/DB material в public README | Linked development/research, paused lab archive | Сохранить техническую пользу без technology wall |

Concrete minimal brief `msg_3759f3009620`: один meaning line, one column/central real video/one CTA,30–50words excludingreleaseconditions; никаких public project-status/provenance paragraphs, provisional icon только metadata. Native controls/preload metadata/noautoplay. SF/system palette, light/dark, short transform/opacity feedback; zero imported template/framework. `.gitignore:314 /site` — source delivery conflict Root owns; peer не force-stages/меняет ignore. Все earlier research/render результаты сохраняются как superseded. Public deployment/actual supplied-video playback остаются отдельными UNKNOWN.

## Проверенные начальные источники

- [Screen Studio](https://screen.studio/): официальный сайт представляет продуктовые записи экрана, zoom/motion/framing. Это источник о возможностях capture; рекламные claims не измерения Translator.
- [Remotion fundamentals](https://www.remotion.dev/docs/the-fundamentals): видео задаётся React-композицией и временем/кадрами. Подходит для программируемых титров, переходов и композиции.
- [Remotion Player](https://www.remotion.dev/docs/player): та же video-композиция может воспроизводиться в React-приложении. Текущие API/размер/лицензия и необходимость React для нашего сайта требуют дальнейшей проверки.
- [21st.dev metadata](21ST-REFERENCES-2026-10-04.json): два бесплатных MCP search, шесть results. Source IDs/author/preview/video URLs сохранены; это retrieval metadata, не просмотр previews, не license approval и не импорт source.

Начальная рекомендация Main, ещё не итог research: настоящий Screen Studio capture приложения + code-based титры/переходы при необходимости. До footage можно реализовать собственный story/composition и site prototype из подтверждённых assets. Анимированную web-иллюстрацию не называть записью native-приложения.

## Что должен заполнить владелец

1. Фактический аудит нынешнего README: устаревший Linux-first CTA, English-first текст, badges и CLI на первом экране; проверить каждый проблемный claim по текущему продукту.
2. Сравнительная таблица README и лендингов: прямые источники, даты, популярность только после проверки, механика, применимость, отклонённые варианты.
3. Просмотр подходящих 21st.dev previews, выбор небольшой подборки и источник/лицензия для каждой адаптации.
4. Сравнение video tools и решение: настоящий capture, программируемая композиция, web demo, exports, license, time/cost, доступность и fallback.
5. Рекомендованный story/контент и обоснование короткого русского README; перенос полезных технических материалов.
6. Обоснованный минимальный стек сайта/демо, hosting path, build/preview и scoped проверки.
7. Реальная schema и архитектура read-only DB checkpoint; размеры, память, индекс/query plan, limits, приватность, provenance/лицензии и безопасный локальный PoC.
8. Финальная рекомендация, реализованные решения, исходники/preview/evidence и конкретные unresolved зависимости. Обновлять по мере знаний, сохранять прежние выводы с датами.

## 04.10.2026 — исследование до нового steering 19:38UTC (история)

Дата обращения ко всем первичным источникам ниже:04.10.2026. Выбран standalone HTML/CSS/JavaScript: для одного сценария React/GSAP/сборщик не дают необходимой возможности. Нет внешних fonts/analytics/package installation. System font, blue accent, небольшая glass panel и короткое затухающее движение опираются на `DesignSystem.swift` и реально просмотренный [исторический popup](../release/evidence/c248d6-guest-offline-popup.jpg). Native app остаётся неизменным. Сайт — presentation, не второй backend client.

Одна собственная фраза «The small blue bird is sitting near the window.» → «Маленькая голубая птичка сидит возле окна.» совпадает с реально измеренным историческим guest сценарием. Новая browser animation честно обозначена как illustration, не macOS capture и не latency benchmark. Настоящий screenshot имеет отдельную подпись с источником. Для master — Screen Studio, сейчас собственная Canvas-композиция/короткий WebM. DB lab изолирован от public landing и не загружает базу.

### Пять README, содержимое прочитано

| Проект / автор / прямой первичный URL | Порядок / что адаптируем | Что отклоняем |
| --- | --- | --- |
| [Rectangle / rxhanson](https://github.com/rxhanson/Rectangle) | Задача → требования → download/website → usage → development. Платформа и загрузка до технических деталей | Огромный список shortcuts; minimum OS website10.15+ против README14+, чужие значения не копируем |
| [Maccy / p0deje](https://github.com/p0deje/Maccy) | Utility purpose → official site → features → download → keyboard usage. Одно действие и знакомый macOS UI | Brew/advanced defaults на первом экране; абсолютная приватность не подходит optional network providers Translator |
| [IINA / IINA team](https://github.com/iina/iina) | Назначение → website/releases → features → stable/beta/nightly → build. Явно отделить prerelease от production | Каталог features/build commands убираем в linked docs; assets не копируем |
| [Kap / Wulkano](https://github.com/wulkano/Kap) | Get Kap/platform downloads → короткие recording steps → contribution/plugins. Простые install/setup steps | Community/plugins/unsupported dev builds не должны вытеснять demo |
| [Keka / aonez](https://github.com/aonez/Keka) | Purpose → website/current download → legacy → support; repo в основном issues/wiki. Один актуальный CTA | Public repo не доказывает open-source license всего приложения; не заимствуем claims |

GitHub public README sections действительно прочитаны, API auth отдельно verified protected `forge-access` HTTP200; это не push auth/CI/runtime. Не используем popularity как доказательство: звёзды/продажи/ratings не заявляются и не переносятся в продукт.

### Пять лендингов, browser review

Все открыты в own browser tab HTTP200; PNG реально просмотрены. Оригиналы — [внешние reference evidence](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/references/). Чужие assets не входят в сайт.

| Проект / URL / автор | Первый экран и CTA | Адаптация / отклонение / граница |
| --- | --- | --- |
| [Rectangle](https://rectangleapp.com/) / Ryan Hanson | Большая иконка, одно предложение, download/platform, затем Pro | Прямая задача/CTA; иконка без demo менее убедительна, upsell не нужен |
| [Maccy](https://maccy.app/) / Alex Rodionov | Название/benefit/2CTA слева, menu UI справа, OS под кнопкой | Маленький utility показывать native окном; не копировать testimonials/AppStore promise/fake-sites warning |
| [IINA](https://iina.io/) / IINA team | Большой реальный интерфейс, download/version/platform/notes | Читаемый масштаб demo, release notes рядом; patterned background/plugins не нужны |
| [Kap](https://getkap.co/) / Wulkano | Action headline, Get Kap/platform, gradient frame | Один сценарий; gradient чужой. Media blank в early PNG, playback чужого видео не проверен |
| [Keka](https://www.keka.io/ru/) / aonez | Русский purpose/mascot/AppStore + direct download/version/size | Русская подача и size/version; чужие green/mascot отклонены. Parser0lines, early blank сохранён; loaded PNG после3s реально просмотрен |

Дополнительный [Screen Studio](https://screen.studio/) framing reference: zoom на читаемом фрагменте, крупный предметный demo. Это механика подачи; его branding/ролики/social proof не копируем.

### 21st.dev: источники, visual scope и лицензии

MCP доступен; Root сделал2FREE search, peer третий `selection bubble menu native product demo` limit3. AI generation capability выключен. `get_component`, installation, account/bookmark mutations не вызывались. `free` filter не является license grant. [Metadata JSON](21ST-REFERENCES-2026-10-04.json) хранит IDs/author/URLs, visual status отдельно.

| ID / автор / URL | Проверено | Решение | License |
| --- | --- | --- | --- |
| 26926 / laziekiki / [Selection Bubble Menu](https://21st.dev/@laziekiki/components/selection-bubble-menu) | PNG лично просмотрен: selection и маленькая floating toolbar; flip/preserve описаны metadata | Собственная vanilla bounds clamp, сохранение selection, Escape/focus. React/framer-motion source/dark bar не импортируем | UNKNOWN, source/license не извлекались |
| 4710 / vaib215 / [Product Mockup](https://21st.dev/@vaib215/components/hero-with-product-mockup) | PNG: текст слева, stacked browser/mobile справа | Предметный visual полезен; device stack/pastel/универсальный slogan отклонены | UNKNOWN |
| 12330 / jean.duthil13 / [MacBook Neo Hero](https://21st.dev/@jean.duthil13/components/mac-book-neo-hero) | PNG: чужие Apple devices/branding; scroll scrub только metadata | Отказ: frame sequence/scroll pinning не объясняют перевод, чужой branding | UNKNOWN |
| 2572 / dhmnpunit / [macOS Dock](https://21st.dev/@dhmnpunit/components/mac-os-dock) | Только metadata | Не нужен fake Dock/GSAP | UNKNOWN |
| 10464 / 0xUrvish / [Dynamic Toolbar](https://21st.dev/@0xUrvish/components/dynamic-toolbar) | Только metadata | Controls framework не нужен одному сценарию | UNKNOWN |
| 12401 / serafimcloud / [Input Bar](https://21st.dev/@serafimcloud/components/input-bar) | Только metadata | Chat/attachments не относятся к продукту | UNKNOWN |

Третий search также вернул23394/saurabh-2607 Great UI Animated Select и2531/al11o Inline Dropdown: нерелевантные dropdown, metadata only/license UNKNOWN. CLI CDN403 сохранён; browser preview URLs HTTP200. Hover-video/motion этих demos не просмотрены: PNG не доказывает качество движения. Никакой код/assets не скопирован.

### Видео: сравнение и production путь

| Подход / официальные источники | Возможности / лицензия | Решение |
| --- | --- | --- |
| [Screen Studio guide](https://screen.studio/guide), [exports](https://screen.studio/guide/explanation-of-export-settings), [terms](https://screen.studio/legal/terms-of-service) | Настоящий capture, zoom/cursor/framing, Export to File MP4/GIF. Proprietary subscription/order terms; пользовательская entitlement не проверена | Пользователь уже может записывать: рекомендован master1080p/30fps без cloud upload/новой покупки, fake speedup или склейки разных запусков |
| [Remotion Player](https://www.remotion.dev/docs/player), [license/pricing](https://www.remotion.dev/docs/license/pricing) | React/frame composition, programmable titles/render. Free individuals/companies≤3people;4+company license; team size UNKNOWN | Не blanket MIT/free. Новый React/render stack не оправдан одним роликом, не устанавливаем |
| [Kap](https://github.com/wulkano/Kap), [exports site](https://getkap.co/) | MIT source, MP4/WebM/GIF/APNG recording | Не установлен/не запускался; второй recorder не нужен, его web stack не переносим в native |
| Canvas + [captureStream](https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/captureStream) + [MediaRecorder](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder) | Локальный WebM из собственной composition, browser codec capabilities/`isTypeSupported` | Выбран short preview без paid renderer. Это illustration; нужны actual render/playback. ffmpeg/ffprobe локально не найдены, MP4 render не заявляется |

Рекомендация: real Screen Studio master после native walkthrough + собственные титры; code composition сейчас — готовый storyboard/README poster/verified preview. Без музыки, чужих logos и fake cursor поверх actual footage. [Capture brief](VIDEO-BRIEF.md).

### Отдельный DB checkpoint

Read-only source: [examples provider](../../translate_logic/infrastructure/language_base/provider.py), [defs provider](../../translate_logic/infrastructure/language_base/definitions_provider.py), [paths](../../translate_logic/infrastructure/language_base/locations.py), [pinned lock](../../scripts/db-bundle.lock.json). Existing store `~/Library/Application Support/Translator/db`: primary1 779 474 432/fallback71 847 936/defs45 223 936 bytes, сумма1 896 546 304. Только downloadable DB, user history/settings не открывались. Sizes совпадают с lock; полный SHA scan сейчас не запускался, hash identity independently verified не заявляется.

Actual schema: FTS5 `examples_fts(en, ru UNINDEXED)` в обеих examples DB; primary `lexicon`/`lexicon_forms` PRIMARY KEY; defs `defs`/`defs_forms`/`defs_phrases`, `idx_defs_key_score`. `EXPLAIN QUERY PLAN`: FTS virtual index, PK и covering index. `LIMIT3`, mode=ro/query_only, cache2MiB, progress timeout500ms, unchanged size/mtime в [actual log](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/presentation/20261004T191642.022823Z-indexed-db-queries-and-final-research.log). Это не integrity scan. «small blue bird» FTS0rows, `bird` lexicon0rows, defs3rows с нерелевантными/разговорными смыслами: нельзя выдавать первый sense/пример за перевод произвольной фразы.

| Архитектура | I/O / память / совместимость | Решение |
| --- | --- | --- |
| in-memory WASM / File.arrayBuffer |1.9GB плюс buffers/heap/copies; mobile quota непредсказуема, file picker требует пользователя | Не добавляем в public landing. Это обоснованный memory risk, не измеренный browser предел |
| [Official SQLite WASM/OPFS](https://sqlite.org/wasm/doc/trunk/persistence.md) / own worker/OO1 | OPFS import — дополнительная копия/quota; standard VFS требует COOP/COEP/SharedArrayBuffer, SAH pool имеет иные ограничения; browser locking/Safari нужны отдельные gates | Будущий small licensed pack с явным consent. [Worker1/Promiser deprecated2026-04-15](https://sqlite.org/wasm/doc/trunk/api-worker1.md), не использовать как новый adapter |
| Fixed loopback read-only endpoint | Existing DB/индексы/cache2MiB; max3rows, query≤80chars/500ms, bounded response | Выбран isolated PoC: explicit --db-dir,127.0.0.1, same-origin/Host checks, noCORS/noSQL API/no public bind. Static public build без API остаётся fixture |
| Hosted service/range VFS | Rights/hosting/rate limits/auth/privacy/release identity обязательны | Не prerequisite лендинга; DB upload/public endpoint/deploy не выполнены |

Приватность: selection на landing остаётся в browser. Только Submit отдельного lab передаёт короткий query в localhost. Нет history/Anki/providers reads/writes. Fixture — собственный текст; real DB responses маркируются и не экспортируются в public assets.

Provenance: actual primary meta перечисляет `Tatoeba,News-Commentary,GlobalVoices,TED2020,QED,OpenSubtitles`; lexicon meta указывает [Kaikki English](https://kaikki.org/dictionary/English/index.html), extracted Wiktionary. [Tatoeba terms§6](https://tatoeba.org/en/terms_of_use) требуют CC-BY attribution; FTS schema не хранит per-row автора/лицензию/corpus. [OPUS index](https://opus.nlpl.eu/) не даёт автоматического разрешения всего bundle; точный OpenSubtitles page недоступен. Kaikki current dump отличается по времени от pinned build. Public redistribution rights каждого corpus/derived pack UNKNOWN: нужен provenance manifest/licensed curated pack. [SQLite public domain](https://sqlite.org/copyright.html) относится к engine, не к данным. Local exploration не означает разрешение public republication; новых uploads/копий/DB builds нет.

### Прежний README и scope проверки

Прочитаны348lines: Linux-first CTA/CLI, повторные bilingual sections/technology badges вытесняли macOS demo. Устарели~55MB/LaunchAgent-first install/model setup/release paths. Полезные Linux commands/shared architecture/diagnostics перенесены в русский [development.md](../development.md), maintained [macos.md](../macos.md) остаётся источником macOS details.

Current facts из handoff/[эпика приложения](../release/EPIC-02-APPLICATION.md): v0.3.0build295/tag84, sourcec248, Apple Silicon/macOS26+, DMG25 229 806bytes. D05BLOCKED/noAppleDeveloperProgram: ad-hoc, Developer ID/notarization/public Gatekeeper UNKNOWN; возле CTA явно. Локальная реализация/evidence — [progress](PROGRESS-DELIVERY.md). Source/browser preview не равны commit/push/CI/deploy/native acceptance. Shared40%/meterUNKNOWN, без новых агентов/VM/full suites.
