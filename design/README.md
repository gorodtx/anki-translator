# Translator · Готовый дизайн

Текущее внедрение: [эпик](EPIC-INTEGRATION.md), [журнал](PROGRESS.md), отчёты [GitHub](integration/github.md), [macOS](integration/macos.md) и [Web](integration/web.md). Source доставлен в `mac` до `5c2747a`; local commits354bc92/bfac4d1 ожидают общей доставки. Official batch compiler PASS; Root лично просмотрел восстановленные клубок и три строки при ClearDark/Graphite, принял control. Ресурс и strict provenance guard интегрированы в оба builders; local short/full306 independently signature/resource PASS. **Реальная установка306** в `/Applications` independently strict signature/resource/source identity PASS; backend/DB3/installed Apple pair healthy, данные сохранены. Source CI5c2747a — FAIL в существующем wall-clock Apple fallback test; deterministic test repair354bc92 прошёл local checks, fresh final CI ещё нужен. Final Accessibility grant/actual UI/translation/History и пользовательская оценка AppIcon ещё pending. Artwork и menu-bar линия сохраняются; staged visual/build/backend ping не заменяют пользовательскую приёмку. Ниже сохранена датированная история подготовки.

Дата передачи: **05.10.2026**. Пользователь принял направление и попросил закончить файлы, собрать их в `design/` и подготовить план для трёх будущих агентов. Этот этап готовит материалы; интеграция в установленное приложение, GitHub и публичный сайт передана следующему запуску.

## Файлы для использования

В [final/](final/) собраны точные копии готовых экспортов с короткими именами. Они совпадают с исходными файлами по SHA256; это не новая перерисовка.

| Файл | Формат и размер | Куда использовать |
|---|---|---|
| [translator-logo.png](final/translator-logo.png) | PNG, 2048×2048, прозрачные внешние углы | Основной большой логотип |
| [translator-logo-1024.png](final/translator-logo-1024.png) | PNG, 1024×1024 | Обычная вставка и передача |
| [translator-logo-dark.png](final/translator-logo-dark.png) | PNG, 2048×2048 | Тёмный вариант |
| [translator-logo.svg](final/translator-logo.svg), [translator-logo-dark.svg](final/translator-logo-dark.svg) | SVG | Масштабируемые master |
| [translator-line-white.png](final/translator-line-white.png) | PNG, 560×360, прозрачный фон | Белый знак «клубок → ровная линия» |
| [translator-line-white.svg](final/translator-line-white.svg) | SVG, один непрерывный Path | Векторный белый знак |
| [github-avatar.png](final/github-avatar.png) | PNG, 500×500, непрозрачный фон | Квадратный аватар, безопасный для круглого кадрирования |
| [github-avatar-dark.png](final/github-avatar-dark.png) | PNG, 500×500 | Тёмный аватар |
| [github-repo-card.png](final/github-repo-card.png) | PNG, 1280×640, русский текст | Основной GitHub Social preview |
| [github-repo-card-en.png](final/github-repo-card-en.png) | PNG, 1280×640, английский текст | Английский Social preview |
| [macos-AppIcon.icns](final/macos-AppIcon.icns) | ICNS, 10 representations | Иконка bundle macOS |

Точные источники, размеры и контрольные суммы перечислены в [manifest.json](final/manifest.json).

## Исходники и полный комплект

- [translator-icon/README.md](translator-icon/README.md) — master, оптические размеры 16–1024, Light/Dark, symbols, web/favicon, PWA, Android и короткая анимация.
- [translator-icon/menu-bar/README.md](translator-icon/menu-bar/README.md) — белая линия, Tiny, чёрный template и ресурсы 1x/2x/3x для macOS.
- [translator-icon/github/README.md](translator-icon/github/README.md) — аватары, RU/EN card, шаблон пользователя и готовый фрагмент README профиля.
- [Translator-Mono.penpot](translator-icon/penpot/Translator-Mono.penpot) — полный переносимый проект с 23 макетами.
- [THREE-AGENT-HANDOFF.md](THREE-AGENT-HANDOFF.md) — готовый общий промт с тремя ролями и условиями приёмки.
- `Translator-Design-Delivery.zip` — локальный единый комплект: эти документы, `final/` и исходная система `translator-icon/`. Предыдущие ZIP и одинаковая дополнительная копия `.penpot` не вложены повторно. Архив не включён в Git; исходники и экспорты доступны в перечисленных папках.

Предыдущие локальные поставки `Translator-Mono-Icon-Kit.zip` и `Translator-Panel-and-GitHub-Kit.zip` сохранены вне Git. Первый архив фиксирует первоначальные 15 макетов; актуальный переносимый проект содержит 23.

Локальный [Penpot](http://localhost:9085/#/workspace?team-id=76adeac8-81da-81cd-8008-be12ef29e5bd&file-id=76adeac8-81da-81cd-8008-be13d9a96e83&page-id=76adeac8-81da-81cd-8008-be13d9a96e84) и общий MCP доступны через `/Users/den/.local/bin/penpot-tool`. Проверка `doctor` на этом этапе подтвердила `pluginConnected=true`, текущие file/page IDs и пять инструментов. Настройки общего хоста находятся в `/Users/den/.config/agent-access/design-tools/README.md`; секреты, browser profiles, compose и runtime в этот комплект не входят.

## Что готово и что ещё предстоит

Готовы локальные PNG/SVG/ICNS, оптические варианты, исходники Penpot, белый знак панели, аватары и карточки GitHub. Основная идея: **«Перевод рядом. Из хаоса — в ясность.»** Продуктовые подписи соответствуют текущему английский → русский на macOS.

Проверены экспортные размеры и прозрачность, SVG, native AppKit load, отступ 80 px для Social preview, круглая маска аватара, шрифты Inter в card и CRC архивов. У готовых PNG GitHub непрозрачный фон и размер меньше 1 MB. Проверка копий и сохранности файлов вне `design/` — [delivery-verification.json](delivery-verification.json). Размер, SHA256 и CRC единого архива — в отдельном [package-verification.json](package-verification.json).

Ранее в рабочем дереве уже были локально подготовлены `icons/main_icon.png`, `Resources/AppIcon.icns`, генераторы ICNS и ресурсы сайта. Они остаются незакоммиченными. На этом этапе код приложения и сайта не меняется: `MenuBarExtra` всё ещё использует `character.bubble`, сайт сохраняет `logoProvisional=true`. Установленное приложение не обновлено, GitHub Social preview не загружен, профиль не изменён, новый сайт и релиз не опубликованы. Commit/push не выполнены.

Штатная карточка Pinned на GitHub не имеет отдельного поля аватара репозитория. Social preview используется при распространении ссылки; картинку проекта на странице профиля можно разместить в profile README с помощью готовых `translator-icon/github/profile/`. Смена общей аватарки пользователя не входит в задачу. [GitHub: Social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview), [GitHub: Pinned](https://docs.github.com/en/account-and-profile/how-tos/profile-customization/pinning-items-to-your-profile).
