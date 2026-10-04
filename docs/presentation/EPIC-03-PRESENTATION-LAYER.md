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
