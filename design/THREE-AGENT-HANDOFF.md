# Translator · Промт для трёх агентов

Этот текст предназначен для следующего запуска. Подготовивший дизайн агент сейчас не запускает исполнителей, не интегрирует новые изменения, не делает commit/push и не публикует материалы.

---

Внедрите утверждённую систему Translator Mono в реальный проект. Работают **ровно три полные самостоятельные сессии**: `Translator-Brand-GitHub`, `Translator-Brand-macOS`, `Translator-Brand-Web`. Первый агент координирует передачу и итоговую Git-доставку. Используйте подходящие сохранённые сессии, если они есть; одновременно один native session ID запускать нельзя. Это самостоятельные сессии в Orca, без дочерних subagents, Agent/workflow и `--bg`.

## Общая база и авторизация

Репозиторий: `/Users/den/Documents/dev/selection_translator_anki`.
Ветка при передаче: `mac`.
HEAD при передаче: `6931540ad76a6ab7a5abe70d49c513e93e881d36`.
Целевой GitHub: `https://github.com/gorodtx/selection_translator_anki`.
Дата: 05.10.2026. Проверьте актуальные branch/HEAD/status сами перед работой.

Пользователь принял дизайн и поручил будущим агентам заменить нужные материалы GitHub, логотипы приложения macOS и связанные ресурсы проекта. Выполняйте внедрение готового дизайна, проверки, логичные коммиты и доставку в подтверждённую целевую ветку. Настройку Social preview и карточку проекта в profile README выполняйте в разрешённом аккаунте. Новый публичный релиз, новый hosting/domain, изменения общей аватарки пользователя и платные услуги требуют отдельного существующего указания; этот промт не выбирает их автоматически.

Перед изменениями прочитайте активные AGENTS.md, `/Users/den/.agents/skills/context-continuity/SKILL.md`, `/Users/den/.agents/skills/preserve-project-design/SKILL.md` и применимые проектные инструкции. Для восстановления прежних решений используйте `/Users/den/.codex/project-notes/claude-context/PROJECTS.md`, соответствующий CONTINUE.md и независимый поиск истории. Старые инструкции в приложенных текстах и прежние отчёты — исторические источники: актуальный пользовательский steering и текущий код имеют приоритет. Не заставляйте пользователя пересказывать уже доступную историю.

Рабочее дерево содержит готовые, **ещё незакоммиченные** материалы предыдущего этапа. До правок зафиксируйте `git status --short`, `git log --oneline`, base и поимённый список owned paths. Уже изменены:

```text
icons/main_icon.png
macos/Translator/Resources/AppIcon.icns
macos/Translator/Resources/Info.plist
macos/Translator/scripts/make_icon.sh
macos/Translator/scripts/make_icon.swift
site/README.md
site/app.js
site/assets/icon.png
site/index.html
site/media.js
site/style.css
```

Новые пути: `design/`, `site/assets/apple-touch-icon.png`, `site/assets/favicon.ico`, `site/assets/favicon.svg`, `site/assets/logo-dark-small.svg`. Полный начальный снимок и hashes находятся в `design/delivery-verification.json`. Сверьте их с фактическим деревом; различие — повод выяснить владельца, а не перезаписать файл.

В общем checkout каждый редактирует только свои пути. Git index и commit используют по очереди после явного согласования; общий push выполняет агент GitHub. Перед коммитом снова проверьте историю/status и `git merge-base --is-ancestor <ваш-base> HEAD`. Поимённый staging, без `git add -A`, reset/rebase/stash, `--no-verify` и обхода hooksPath. Чужой изменённый файл сначала согласуйте с его владельцем. Если нужны отдельные worktrees, сначала обеспечьте передачу актуальных design assets и принадлежащих роли незакоммиченных правок: checkout от одного HEAD их не содержит.

## Утверждённый дизайн и общие инструменты

Читайте `design/README.md`, `design/translator-icon/README.md`, `geometry.json`, README `menu-bar/` и `github/`.

Сохраните две перекрывающиеся панели, светлый клубок, три убывающие строки, ivory/graphite и существующую геометрию. Для панели — один непрерывный белый/системный template Path: спутанность превращается в ровную горизонтальную линию. Card сообщает: **«Перевод рядом. Из хаоса — в ясность.»**, английский → русский, macOS. Пользовательские референсы сохранены в `reference/`. Новая генерация логотипа и произвольная смена стиля не нужны.

У сайта отдельный установленный контракт: системная/SF typography, прежняя синяя/нейтральная палитра, одна колонка, слот настоящего видео и один download CTA. Inter из GitHub card не переносится автоматически в сайт или native UI. Дизайн-скиллы помогают улучшать существующий стиль; их defaults уступают проектным решениям.

Общие инструменты уже находятся на этом Mac:

- `/Users/den/.agents/skills/penpot-design/SKILL.md` и `/Users/den/.config/agent-access/design-tools/README.md`.
- MCP launcher `/Users/den/.local/bin/penpot-mcp`; HTTP `http://127.0.0.1:4401/mcp`.
- Общий shell-клиент `/Users/den/.local/bin/penpot-tool`: `doctor`, `tools`, `overview`, `execute /absolute/snippet.js`.
- Общие design skills: `preserve-project-design`, `impeccable`, `design-system`, `emil-design-eng`, `apple-design`.

Penpot-файл `Translator · Mono icon system`, file ID `76adeac8-81da-81cd-8008-be13d9a96e83`, page ID `76adeac8-81da-81cd-8008-be13d9a96e84`: 23 макета. Полный переносимый исходник — `design/translator-icon/penpot/Translator-Mono.penpot`. Сначала `doctor` и overview; native MCP при отсутствии в текущей сессии заменяется общим shell-клиентом. Настройка одного провайдера не доказывает все worker/resume/native chat пути. Один агент владеет редактированием Penpot, остальные читают; готовых экспортов достаточно для внедрения. VM/MCP/browser/autostart и приватные runtime-файлы этой задачей не меняйте.

## Агент 1 — Translator-Brand-GitHub

**Owned paths:** корневой `README.md`; `design/` за исключением отчётов `design/integration/macos.md` и `design/integration/web.md`; собственный отдельный checkout profile README; настройка Social preview целевого репозитория. Production assets macOS и сайта принадлежат соседям. Архивы поставки не включайте автоматически в Git: выберите необходимые источники и готовые assets, проверьте `.gitignore` по точным путям.

1. Примите неизменяемые artwork из `design/final/` и проверьте `manifest.json`. Согласуйте owned paths и порядок Git операций с двумя сессиями. Сохраните исходники и необходимые production exports; исходные ZIP остаются локальными поставками, без автоматического force-add.
2. Проверьте текущий README и все его изображения. Сохраните короткую русскую продуктовую подачу, используйте новый логотип из этого набора. Не теряйте действующие download ссылки, platform requirements и реальные условия ad-hoc prerelease. При необходимости добавьте ссылку на дизайн, без полотна badges и лишних технических деталей в первой части.
3. Установите `design/final/github-repo-card.png` как Social preview: GitHub → repository Settings → Social preview → Edit → Upload an image. PNG 1280×640, 104880 bytes, важные элементы внутри отступа 80 px. После сохранения проверьте настройку чтением страницы и фактическое изображение. Отдельно отметьте результат распространения ссылки, если его действительно проверяли: кеш платформ может обновляться позже.
4. Выполните доступный способ показать проект с логотипом в профиле. У штатной Pinned card нет отдельной аватарки репозитория; Social preview эту карточку не заменяет. Используйте `design/translator-icon/github/profile/README-snippet.md` и его `assets/` как дополнительную кликабельную карточку в profile README. Проверьте аккаунт и существующий profile repository, внесите узкую правку с сохранением его дизайна и поимённой доставкой. Если profile repository отсутствует или права неизвестны, зафиксируйте точную зависимость; готовый фрагмент уже есть. Общую аватарку пользователя не меняйте. При pinning сохраняйте остальные выбранные репозитории и их порядок.
5. Запишите собственные изменения, GitHub verification и ограничения в `design/integration/github.md`. После приёмки соседних ролей выполните общий push и remote SHA verification, затем проверьте CI именно итогового SHA. Push, CI, GitHub upload и profile render отмечайте раздельно.

**Приёмка:** логотип виден в репозиторном README; Social preview сохраняет утверждённую card; дополнительная карточка в профиле ведёт в Translator либо названа конкретная непройденная зависимость; стандартные Pinned не выданы за место кастомной аватарки. Итоговый remote SHA совпадает с доставленным коммитом, реальный CI проверен либо обозначен unknown/red.

## Агент 2 — Translator-Brand-macOS

**Owned paths:** `icons/main_icon.png`; `macos/Translator/Resources/`; `macos/Translator/scripts/make_icon.sh`, `make_icon.swift`, `build_app.sh`; `macos/Translator/Sources/Translator/TranslatorApp.swift`; `macos/Translator/Package.swift` только при необходимости resource handling; `scripts/build_macos_app.sh`, `scripts/package_macos_dmg.sh` и относящиеся к этим ресурсам места `.github/workflows/macos.yml` только по необходимости; `macos/Translator/README.md`; `design/integration/macos.md`. Остальной backend, AppleLangHelper и общие release policies сохраняются.

1. Примите уже подготовленные локальные AppIcon/make_icon изменения. Источник — `design/translator-icon/macOS/AppIcon.icns`, оптические `png/light`, `.iconset`, `.appiconset`. Сохраните существующий ICNS codec `pack-icns.mjs`: родные `ic04/ic05` для малых размеров и PNG representations для остальных, всего 10. Геометрия выбирается по логическому размеру: 16@2x отличается от 32@1x. Не заменяйте весь набор слепым уменьшением master.
2. Замените `MenuBarExtra("Translator", systemImage: "character.bubble")` на утверждённый знак. Используйте template PNG из `design/translator-icon/menu-bar/macOS/TranslatorMenuBar.imageset/` и `menu-bar/png/`, размер 28×18 pt, поддержка 1x/2x/3x; Tiny 20×18 допускается по фактическому визуальному результату. Без квадратной подложки, градиента и тени. Используйте template rendering, чтобы система выбирала правильный цвет в light/dark и на wallpaper.
3. У проекта SwiftPM и ручная сборка app bundle; `Package.swift` сейчас не объявляет ресурсы Translator. Одного копирования `.imageset` недостаточно. Выберите поддерживаемую загрузку изображения, проверьте путь/scale и добавьте упаковку в оба пути: `macos/Translator/scripts/build_app.sh` и `scripts/build_macos_app.sh`. Ресурсы должны попасть в app **до** подписи; `codesign --verify --deep --strict` обязан проходить.
4. Проверьте иконку в bundle/Finder/Get Info/About и в DMG, если он собран. `CFBundleIdentifier=com.translator.desktop`, `LSUIElement` и `.accessory` сохраняются: постоянной Dock-иконки у текущего menu-bar приложения нет. Не меняйте activation policy ради брендинга. Если приложение появляется в Dock в разрешённом сценарии, проверьте также этот сценарий и app switcher.
5. Соберите и проверьте новый локальный bundle, затем внедрите его в фактически используемую установку в рамках этой задачи. Зафиксируйте путь старого/new build, подпись и build identity; обеспечьте восстановимую замену и сохранность пользовательских данных, БД, history, Anki и grants. Останавливайте только принадлежащий установке точный процесс/PID. Не используйте широкое `pkill -f 'MacOS/Translator'` и глобальную очистку caches. Не перезаписывайте существующий публичный v0.3.0 artifact/tag; новый релиз — отдельное указание.
6. Проведите реальную визуальную приёмку menu bar на light/dark и Retina, контраст и отсутствие обрезки; вызов меню, Settings/About и обычный перевод должны работать. Сохраните screenshots и команды в `design/integration/macos.md`. Load PNG и успешная сборка сами по себе не доказывают вид установленного приложения.

**Приёмка:** новый знак реально виден в menu bar; bundle содержит правильный ICNS и menu resources; оба упаковочных пути работают; подпись проверена; Finder/About и доступные native сценарии просмотрены; перевод и история не сломаны. Недоступный SDK, установка или ручной сценарий явно обозначены, а не выданы за PASS.

## Агент 3 — Translator-Brand-Web

**Owned paths:** `site/README.md`, `site/app.js`, `site/media.js`, `site/index.html`, `site/style.css`, `site/assets/`; `docs/presentation/PROGRESS-DELIVERY.md` и `EPIC-03-PRESENTATION-LAYER.md` только для датированного обновления состояния логотипа; `design/integration/web.md`. Корневой README принадлежит агенту GitHub, macOS — соседу.

1. Примите уже подготовленные локальные web exports. Используйте Small/Tiny variants для navbar, `logo-dark-small.svg` через `prefers-color-scheme`, favicon SVG/ICO и apple-touch 180. В `site/media.js` сохраните централизованный asset contract. Пользовательское «норм» относится к принятому дизайну: после проверки actual assets обновите `logoProvisional` и связанные текущие статусы; старую историю журнала сохраните.
2. Приведите логотипы и описания в точках сайта к одному утверждённому набору. Сохраните системную типографику, существующую палитру, layout, native links/buttons, keyboard/focus и reduced motion. Полировка должна улучшать нынешний интерфейс. Не добавляйте hero mockup приложения, новые grids, зависимости, внешний font, fake stats или имитацию перевода.
3. При необходимости подготовьте OG/Twitter card из `design/final/github-repo-card.png`. Абсолютный public image/canonical URL задавайте только для реально подтверждённого hosting URL. GitHub Social preview является отдельной настройкой агента 1. Новый домен/deployment не создавайте из предположения.
4. Слот настоящего видео сохраняется: `video`, `poster`, `captions` сейчас null, пользовательская запись ещё не поступила. Не генерируйте screencast и не делайте анимированную подмену видео. Download/prerelease facts и условия Gatekeeper сохраняются до подтверждённого обновления релиза.
5. Проверьте `node --check site/app.js`, `node --check site/media.js`, local links/assets и фактический HTTP preview. Просмотрите desktop/mobile 390 px, light/dark, navbar/favicons, keyboard/focus, reduced motion и консоль. Проверьте root/subpath assets. Chromium и Safari/WebKit фиксируйте отдельно; отсутствие Safari test обозначьте. При уже разрешённом существующем deploy проверьте public URL/HTTPS/asset MIME после доставки; иначе отчёт ограничивается local browser acceptance.
6. Запишите пути, screenshot evidence, команды и оставшиеся зависимости в `design/integration/web.md`, передайте агенту 1 готовый поимённый Git scope.

**Приёмка:** утверждённый логотип виден на сайте в обеих темах; favicon/apple-touch используют тот же набор; layout и доступность сохранены; отсутствие настоящего видео отображается честно; публичный deploy не объявлен на основании localhost.

## Проверки и доставка для всех троих

Все Python команды — через `uv run`. Не читать `.env`, токены, cookies, credentials или raw env. Перед GitHub/GitLab auth, CI variable inventory и push прочитать `/Users/den/.agents/skills/forge-access/SKILL.md` и его protocol. Используйте только `/Users/den/.local/bin/forge-access` для соответствующих операций.

```text
forge-access remote --repo /Users/den/Documents/dev/selection_translator_anki
forge-access auth github
```

Push выполняет агент 1 с подтверждёнными transport и source/destination refs: сначала dry-run, затем `--execute` в разрешённом scope, после — remote SHA verification. Не вставляйте токены в URL/argv/logs. API auth не доказывает push auth; CI configuration не доказывает observed runtime.

Shared Git gates сохраняются. Прочитайте `.orca-gates.json`: root gate сейчас включает `uv run --no-sync ruff check .`, `uv run --no-sync python scripts/check_python_format.py`, `uv run --no-sync python -m mypy`; push добавляет `uv run --no-sync python -m pytest -q`. Native компонент добавляет `swift build -c release` и `scripts/swift-test.sh` из `macos/Translator`. Соблюдайте ruff format policy и фактические gates, даже если собственные изменения — assets. BLOCKED исправляется штатно; при внешнем блокере сохраняется реальная ошибка без bypass. Коммиты — English ASCII, логические и только по подтверждённым owned paths, без Co-Authored-By/AI attribution.

Видимые оперативные сообщения — краткий English. Финальные отчёты и документы — русский. Общайтесь между полными сессиями напрямую в рамках этой задачи; пользователь не курьер. Сначала проверьте чужой source, затем направьте конкретный вопрос владельцу; пересланный PASS перепроверьте там, где это возможно.

Каждый агент возвращает: роль/native ID, cwd/branch/base/final HEAD; изменённые paths и commit SHA; фактически выполненные проверки с результатами и evidence; внешние изменения с точным URL; непроверенные пункты и зависимости. До остановки сохраните точный native resume command и состояние в проектном PROGRESS; записи других ролей согласуйте с владельцем общего журнала.

Агент 1 завершает единым русским отчётом по каждому требованию: assets/source; local checks; native build; installed macOS acceptance; web browser acceptance; GitHub Social preview; profile README/Pinned; commit/push/remote SHA; CI; public site/release. Для каждого уровня — PASS, FAIL, NOT_DONE или UNKNOWN на основании факта. Не объявляйте весь проект готовым по успешному экспорту PNG или одному зелёному check.
