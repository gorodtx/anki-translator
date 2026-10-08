# Эпик 3 — Presentation Layer

Создан: 04.10.2026. Статус: **MINIMAL_LAYOUT_LOCAL_ACCEPTED; WAITING_USER_VIDEO_LOGO; ROOT_DELIVERY_PENDING**. Владелец после передачи: существующая полная сессия Translator1-Distribution, GPT-6.1-Sol xhigh. Main параллельно ведёт ручную приёмку native-приложения с пользователем. Новых агентов создавать не нужно.

## Действующий steering — 04.10.2026 19:38UTC

User instruction через Root `msg_4eb531224ca9` заменяет generated/demo часть прежнего scope: **пользователь сам записывает настоящее видео и создаёт новый логотип**. Задача peer — очень минимальные русский landing/README, практически без текста, с real-video integration slot, текущей иконкой только как provisional, system/native typography/material/spacing/motion. Не генерировать видео/лого, не рисовать app demo/mockup/переводы и не имитировать capture. Native app неизменен. DB checkpoint сохранён как исследование и **PAUSED**, дальнейшие DB implementation/checks прекращены. Первоначальные критерии ниже остаются историей; status table отражает новое решение. ACK `msg_84c04c61fd1a`.

Дополнение Root `msg_3759f3009620` (19:43UTC): одна колонка/короткий meaning line/central real-video/один CTA,30–50words без необходимых release details; SF/system/native palette, light/dark, thin purposeful material. Никаких features grids/how steps/faux OS/dup CTA/technical status/source digest paragraphs в public UI. Provisional icon помечается только metadata/docs. Native video controls/playsinline/preload metadata/noautoplay; CSS transform/opacity ≤150ms, reduced motion/keyboard immediate. Генерируемые assets удалены из active source, DB work paused, история внешне сохранена. **Delivery blocker:** Root нашёл `.gitignore:314 /site`; peer не меняет ignore/index, exact named site paths передаются Root для узкой delivery adjustment. Public URL/deploy/native runtime не заявляются.

Root read-only review `msg_e128f3ec607a` (19:52UTC) принял минимальный layout локально: лично просмотрел четыре PNG, подтвердил HTTP200/byte-match entry, Node syntax и diff whitespace. Peer отдельно проверил Chromium desktop/mobile/light/dark, keyboard skip/focus, reduced motion, empty и missing-video fallback. Это локальная приёмка presentation; настоящий footage, Safari playback, новый logo, Git/CI и public deploy остаются отдельными gates. Точный комплект и commit plan — [HANDOFF.md](HANDOFF.md), команды и границы — [журнал](PROGRESS-DELIVERY.md).

## Результат для пользователя

Два согласованных представления Translator: короткий русский GitHub README и русскоязычный лендинг. Посетитель сразу понимает сценарий «выделить английский текст → получить русский перевод», видит один убедительный пример и находит актуальное скачивание. Техническая документация доступна по ссылкам, не занимает первый экран.

В состав входит исследование и подготовка демонстрационного ролика; отдельным checkpoint — исследование интерактивного переводчика и поиска примеров в тех SQLite-базах, которые приложение скачивает. Это будущая возможность, а не обещание уже реализованной web-версии.

**Дизайн и код native-приложения не входят в этот эпик.** Не изменять SwiftUI/AppKit, системную типографику, Liquid Glass, layout, assets, анимации, перевод, историю, backend/helper и существующие настройки. Лендинг представляет текущий продукт, используя его настоящую идентичность и подтверждённые возможности.

## Актуальная база и факты

- Repository: `/Users/den/Documents/dev/selection_translator_anki`, branch `mac`, base initial brief `ea5dd631de468bb27d28af16e2b0725bcf7db28a`; implementation base `ab838767b29744f13463749c86e2443bf306e293`.
- [Prerelease v0.3.0](https://github.com/gorodtx/selection_translator_anki/releases/tag/v0.3.0): 0.3.0 (295), release tag `84b185256ccdcc7eae5a8a0114f6cec6f09c3004`, Apple Silicon, macOS 26+; DMG 25 229 806 bytes.
- Production source digest `c248d674a64b71546d3766d508431ac9dcde995af75e9f294f5064e4020b73fd`. Сохранены настоящие guest screenshots и измеренная функциональная приёмка в [эпике приложения](../release/EPIC-02-APPLICATION.md) и [progress](../release/PROGRESS-DELIVERY.md).
- Apple Developer Program отсутствует. D05 Developer ID/notarization/Gatekeeper BLOCKED. В публичном тексте рядом со скачиванием ясно обозначить предварительный выпуск и текущую границу установки; не обещать беспроблемный публичный первый запуск.
- Три SQLite-базы, 1 896 546 304 bytes, опубликованы отдельно в [db-a6f07d1e1c28](https://github.com/gorodtx/selection_translator_anki/releases/tag/db-a6f07d1e1c28). Кодовые релизы повторно их не публикуют. Не добавлять SQLite в Git, сайт или video assets.
- Primary language README/лендинга — русский. Английская версия сейчас не нужна. Поддержку Linux не стирать из документации, но главный пользовательский сценарий текущего захода — macOS EN→RU.
- Shared daily budget обеих существующих сессий: максимум 40% daily usage. Точный счётчик в доступных инструментах UNKNOWN. Не раздувать число сессий, не повторять VM/скачивание баз/полные native suites ради текста или сайта.

## Владение файлами и доставка

Presentation owner получает `README.md`, `docs/presentation/**`, новую директорию `site/**`, при необходимости отдельную `video/**` и технический migration document `docs/development.md`. Стек выбрать после исследования; не устанавливать React/shadcn/GSAP/Remotion только из-за наличия skill или компонента.

Main сохраняет владение native/backend/tests/release scripts, существующим `docs/release/**`, установленным приложением, пользовательскими профилями и shared Git index. После передачи Main не редактирует presentation-owned файлы поверх peer. Peer не меняет Git index/HEAD, gates, signing, tags, release assets, deployment/DNS или App Store без отдельной передачи этого владения. Подготовить логичный план named commits; send Main точные owned paths, diff и результаты проверок. Предыдущий frozen handoff P029 заменён новым ownership только в перечисленных presentation paths.

Работать до завершения доступного исследования и реализации, не останавливаться после плана. Не ждать пользователя для обратимых решений. Зависимость от новой записи Screen Studio, домена, лицензии или доступа фиксировать отдельно и продолжать остальные задачи. Публичный deploy — отдельный проверяемый этап; локальный preview не называть опубликованным сайтом.

## Подзадачи и проверяемая приёмка

| ID | Подзадача | Приёмка | Статус |
| --- | --- | --- | --- |
| P01 | Аудит README, product facts, assets, существующих design/motion правил и условий выпуска | Конкретные проблемы и подтверждённые продуктовые формулировки, пути/источники; никаких изменений app | PASS_SOURCE |
| P02 | Полное исследование хороших README и лендингов | Отдельный [RESEARCH.md](RESEARCH.md): минимум 5 релевантных README и 5 лендингов, прямые первичные ссылки/даты, сравнение, полезные приёмы, отклонённые варианты и причины | PASS_RESEARCH |
| P03 | 21st.dev MCP refs | Рассмотреть mechanics selection, contextual popup, product demo и камерные переходы. IDs/author/URL/лицензия и реальные preview observations; metadata не считать просмотром. Не копировать чужой брендинг и source без проверки лицензии | PASS_PREVIEW_SCOPE |
| P04 | Выбор production-пути для ролика | Сравнение Screen Studio, Remotion и хотя бы одного адекватного альтернативного подхода: достоверность, контроль анимаций, время, лицензия, exports, доступные инструменты, воспроизводимость. Рекомендация и fallback | SUPERSEDED_USER_CAPTURE |
| P05 | Сценарий одного убедительного демо | Уточнить [VIDEO-BRIEF.md](VIDEO-BRIEF.md): 20–35 секунд, выделение → Services → перевод; один главный пример, русский текст, понятные планы/тайминг, минимум вторичных действий | READY_FOR_USER_CAPTURE |
| P06 | Русский README | Короткий продуктовый README: иконка/название/суть → один demo → скачать macOS с актуальным prerelease → короткая настройка и нужные ссылки. Без стены technology badges/CLI/архитектуры. README-полотно переносится в docs с сохранением полезной информации | IMPLEMENTED_MINIMAL |
| P07 | Лендинг | Реально запускаемый responsive preview, README и сайт говорят об одном продукте. Один центральный demo, ясный CTA, существующая визуальная идентичность, точные platform/release условия. Нет фальшивой статистики, testimonials, работающих функций или несуществующего URL | PASS_MINIMAL_LOCAL; WAITING_REAL_ASSETS |
| P08 | Демонстрация без участия пользователя | Подготовить анимированный сценарий/композицию из доступных настоящих assets и собственных примеров. Code-based illustration маркировать как illustration; не выдавать её за screencast/runtime proof. Если выбран Remotion — исходники, preview, render command и проверенный короткий render; если не выбран — аргументированный простой вариант | SUPERSEDED_NO_GENERATION |
| P09 | Настоящий screencast и финальный монтаж | При наличии разрешённого footage — интеграция/титры/zoom/transitions/export. До новой записи пользователя сохранять готовый capture brief и composition без фальшивого DONE | WAITING_USER_VIDEO_LOGO |
| P10 | Отдельный checkpoint интерактивного переводчика/DB | Исследовать реальные SQLite schema/providers, browser WASM/File API/worker versus локальный read-only endpoint. Описать память/1.9GB/индексы/FTS/limits/лицензии/приватность/ошибки/совместимость; рекомендовать архитектуру и этапы | PASS_READ_ONLY_RESEARCH; PAUSED |
| P11 | Ограниченный interactive prototype | Реализовать без изменения native app, если это можно сделать изолированно и без пользователя. Selection → contextual translation UI с визуально согласованной motion; fixture versus real DB явно отличать. Никакой скрытой загрузки 1.9GB. При настоящей DB — read-only, ограниченные запросы, настоящие ответы, release/source identity и обработка ошибок | PAUSED_USER_STEERING |
| P12 | Проверки и evidence | Реальные desktop/mobile screenshots, keyboard/focus/reduced-motion, понятный loading/error/empty, ссылки/assets/build, playback и консоль. Запуски/версии/viewport/ошибки/ограничения и originals в [PROGRESS-DELIVERY.md](PROGRESS-DELIVERY.md) | PASS_SCOPED_BROWSER; REAL_PLAYBACK_UNVERIFIED |
| P13 | Логичная Git/hosting доставка | Точный named path plan, только собственные изменения, нормальные gates. Current local, commit, push, CI, preview и public deployment считаются отдельно. Hosting план/готовая конфигурация допустимы; DNS и новый внешний deploy не объявляются сделанными заранее | HANDOFF_PREPARED; ROOT_GIT_DEPLOY_PENDING |

## Обязательное содержание исследования

Исследование не сводить к галерее ссылок. Для каждого референса фиксировать автор/проект/прямой URL, дату обращения, проверенную популярность при её упоминании, первый экран, порядок информации, место демо/скачивания, что подходит Translator и что противоречит заданным рамкам. Репозитории Rectangle, Maccy, IINA, Kap и Keka можно рассмотреть как кандидатов; актуальность и пригодность проверить, а не предполагать.

Screen Studio — референс подачи и tool для настоящего capture, а не разрешение копировать сайт/бренд. Remotion — кандидат video-as-code; проверить текущие API, лицензию и локальный render. Не покупать платные templates или подписки и не включать cloud rendering ради первого прототипа. 21st.dev использовать по пользовательскому запросу; [первичная metadata подборка](21ST-REFERENCES-2026-10-04.json) уже получена, code не извлекался и визуальные previews ещё не просмотрены.

Интерактивный переводчик — отдельный checkpoint. Сначала закончить README/лендинг и выбрать video flow, затем изолированный proof-of-concept. Не переносить native business logic на новый стек и не публиковать огромную DB через сайт. Локальные пользовательские БД и Anki-данные не изменять. Публичная выдача dictionary examples требует проверки прав на контент; MIT license кода не означает автоматически ту же лицензию всех источников данных.

## Progress и критерий завершения

После исследования, выбора, реализации, ревью, запуска, просмотра screenshots и запроса добавлять датированную запись в [PROGRESS-DELIVERY.md](PROGRESS-DELIVERY.md): ID, действие, источник/base, конкретный результат, команда/выход или visual evidence, найденный дефект, следующий шаг и scope. Не стирать старые FAIL/PASS и требования. Эпик постоянно дополнять новыми знаниями/критериями; актуальные статусы менять с сохранением датированной истории.

Эпик завершён, когда короткий русский README и запускаемый лендинг представлены и проверены, исследование и video decision/capture brief полны, доступное demo реализовано, условные зависимости названы точно, DB checkpoint имеет проверенную архитектуру/PoC либо конкретное обоснование границы, а Git/hosting результат отделён от локальных проверок. Недоступный footage/hosting/лицензия не превращаются в выдуманный PASS.

## 05.10.2026 — Translator Mono, локальная web-приёмка

Обновление 2026-10-05T13:32:05.166328+00:00, Task task_431645af094f / Dispatch ctx_3f3fce8391c7 / Run run_9d43c4e32803. Новая база6931540ad76a6ab7a5abe70d49c513e93e881d36, роль Translator-Brand-Web; прежние даты/статусы выше сохранены. Пользователь принял artwork, пять production assets совпали с утверждёнными exports и manifest по bytes/SHA256; logoProvisional=false. Small32px navbar и Dark Small через picture/prefers-color-scheme, Tiny SVG/ICO16+32 и apple-touch180 интегрированы; существующие системные fonts/blue-neutral palette/one-column/CTA сохранены.

Текущий статус логотипа: APPROVED_INTEGRATED; local source/HTTP/Chromium PASS. Настоящее video/poster/captions остаются null и WAITING_USER_VIDEO: прежнее WAITING_USER_VIDEO_LOGO теперь применимо только к видео. Desktop1440/mobile390 light/dark/reduced/keyboard/favicons/root/subpath проверены,6actualPNG лично просмотрены; report [design/integration/web.md](../../design/integration/web.md). Browser initial theme mismatch RED сохранён: измеренное picture currentSrc обновлялось после media смены, harness исправлен ожиданием actualdecodedvariant; production не менялся для обхода проверки.

Safari/WebKit/physical devices и настоящая запись UNVERIFIED; livePenpot doctor/overview fetch failed и UNKNOWN, сервис не перезапускался. Own preview после actualchecks остановлен exactPID29720, listener8873 исчез; фоновый preview не оставлен. D05 ad-hoc prerelease/publicGatekeeper граница у CTA сохраняется; publichosting/deploy не выполнялись, Gitindex/commit/push/CI только Coordinator. Полный эпик не объявляется завершённым по приёмке логотипа.


## Дополнение 08.10.2026 — README, скачивание и установка

Новое поручение пользователя дополняет историю и заменяет публичный слоган: удалить «Перевод рядом. Из хаоса — в ясность.». Верх README — переданный пользователем `norm.png`, без перерисовки; широкая кликабельная панель по образцу Prettier. Референс структуры: https://github.com/toeverything/affine. Social preview и изображение внутри README проверяются отдельно.

- [ ] P08.1: сохранить точные bytes баннера, показать его первым в README, клик ведёт на Mac DMG.
- [ ] P08.2: короткие ссылки «Скачать для Mac», «GNOME / Arch Linux», «Обратная связь» с минимальными ассоциативными знаками; прежний слоган и prominent prerelease label убрать. Реальные ограничения подписи сохранить в условиях установки.
- [ ] P08.3: добавить компактные ссылки на фактически используемые технологии и три SQLite-базы; не выдавать общий AGENTS stack за стек проекта. Корпус переиспользуется, не загружается заново.
- [ ] P08.4: demo preview ведёт к скачиванию; настоящее видео остаётся отсутствующим, пока его не передаст пользователь. Native video controls не ломать ссылкой поверх плеера. Сайт сохраняет SF/system, палитру и одну колонку.
- [ ] P08.5: проверить source/HTML/JS/asset/link delivery отдельно. Computer-use и новая browser acceptance остановлены пользователем; не объявлять их пройденными.
- [ ] P08.6: отдельная полная macOS-сессия исследует Google Drive-подобную установку без drag, checkbox «Удалить установщик» по умолчанию включён; после исследования обсуждение с пользователем, реализация только после выбора. Владеет `docs/installer/`; общий Root журнал не правит.

Root: native01a1030e-0fcc-7430-8c9d-070c3f569b23, cwd `/Users/den/Documents/dev/selection_translator_anki`, branch mac, base f7db5653ed7c503f554d4fadfc9e531bcda068b1. Новый scope README/site/docs; production app и опубликованные release artifacts не меняются. Установщик — отдельный исследовательский этап, его код ещё не готов.


### P08 checkpoint — 08.10.2026

P08.1–P08.4 source PASS, P08.5 static/HTTP/GFM PASS; source commit1310b5f. Delivery ещё pending. New browser/CUA явно NOT_DONE_USER_STOPPED. P08.6 handoff PASS + receiving ACCEPTED; research ещё выполняется, implementation ожидает будущего пользовательского выбора. Требования и результаты выше сохранены, не вычеркнуты.


### P08 delivery checkpoint — 08.10.2026

P08.1–P08.5 source/static/public README delivery **PASS**: remoteffbd50b, firstbanner/public exact bytes, root/subpath HTTP, all download/data/technology links. Browser/CUA acceptance исключена текущим steering и не объявлена PASS. P08.6 standalone assignment и полный research **PASS**; обсуждение **PENDING USER**. Установщик не реализован по прямому условию пользователя «сначала research, потом обсуждение»; новый EPIC-04 сохраняет будущие14criteria. Новые CI/public site/video/Gatekeeper acceptance остаются отдельными уровнями.
