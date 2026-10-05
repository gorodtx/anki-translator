# Translator · Mono icon system

Локальная векторная реконструкция пользовательского эталона `logo_translator.png`. Сохранены две перекрывающиеся панели, белый клубок, три убывающие полоски и палитра ivory/graphite. Геометрия и слои редактируются в Penpot; материал передан градиентами, толщиной, мягкими тенями и highlights. Растровая микрофактура референса буквально не воспроизводится.

[Открыть файл в локальном Penpot](http://localhost:9085/#/workspace?team-id=76adeac8-81da-81cd-8008-be12ef29e5bd&file-id=76adeac8-81da-81cd-8008-be13d9a96e83&page-id=76adeac8-81da-81cd-8008-be13d9a96e84). Для входа без ручного переноса пароля выполните `/Users/den/.local/bin/penpot-local open`. Учётная запись и browser profile локальные; они не входят в этот пакет. Общая настройка инструментов описана в `/Users/den/.config/agent-access/design-tools/README.md`.

В файле 23 макета: исходные 15 (два объёмных master, восемь светлых/тёмных оптических вариантов и пять symbols), четыре новых варианта знака для панели и четыре макета GitHub. Исходный референс помещён рядом и заблокирован. Независимый переносимый исходник со всеми дополнениями — [Translator-Mono.penpot](penpot/Translator-Mono.penpot). Галерея исходной системы — [preview/index.html](preview/index.html), статический просмотр — [contact-sheet.png](preview/contact-sheet.png).

Дополнение для верхней панели — [menu-bar/README.md](menu-bar/README.md): одна непрерывная белая линия «клубок → ровный выход», прозрачные SVG/PNG, оптический Tiny и готовый Xcode template asset. Квадратные аватары и репокарты GitHub по пользовательскому template — [github/README.md](github/README.md). Новые макеты добавлены в тот же файл Penpot; предыдущий архив `Translator-Mono-Icon-Kit.zip` сохранён как первоначальная поставка, а новые файлы переданы отдельно в `Translator-Panel-and-GitHub-Kit.zip`.

| Уровень | Файлы | Назначение |
|---|---|---|
| MASTER | `master/logo-master*.svg`, PNG 2048×2048 | Большие изображения, About, installer |
| APP ICON | `macOS/png/light`, `macOS/png/dark` | 16, 32, 64, 128, 256, 512, 1024 px |
| macOS | `AppIcon.iconset`, `AppIcon.appiconset`, `AppIcon.icns` и отдельный Dark-набор | Standalone app и Xcode |
| SYMBOL | `symbol/logo-symbol*.svg` | Full, Small, Tiny, Dark, Mono без внешнего фона |
| WEB | `web/logo*.svg`, favicon SVG/ICO/PNG, apple-touch 180 | Навигация, браузеры и Safari |
| PWA | 192, 512, maskable 512 и manifest | Обычный и безопасный для маски варианты |
| Android | foreground/background SVG и `res/` с VectorDrawable/adaptive-icon | Ресурсы для интеграции в Android |
| Animation | `animation-ready.svg`, `logo-animated.svg`, CSS, demo | Однократный переход «хаос → ясность» |

Оптические варианты меняют конструкцию: 1024 — семь петель, 256/128 — шесть, 64 — пять, 32 — три, 16 — одна крупная петля и две строки. На маленьких размерах увеличена толщина, убраны мелкие тени и смещены полоски внутрь диагональной панели. В Retina-наборе геометрия выбирается по логическому размеру: `16@2x` использует вариант 16 pt, а не вариант 32 pt.

Одноцветный symbol содержит два compound paths с прозрачными вырезами. Он принимает `currentColor` при inline SVG и пригоден для template artwork; внедрение в macOS menu bar в этой задаче не выполнено. Dark-symbol имеет светлый тонкий край задней панели. PWA maskable сохраняет знак внутри центральной безопасной окружности; Android foreground использует отдельный масштаб для adaptive mask.

Для navbar подготовлен отдельный Dark Small с той же оптической геометрией 32 pt. Сайт выбирает его через `<picture>` и `prefers-color-scheme`; централизованная настройка — `media.logoDark`. При нескольких inline SVG на одной странице разделите их ID по экземплярам; `<img>` изолирует внутренние IDs самостоятельно.

Пять зафиксированных параметров находятся в [geometry.json](geometry.json): Bézier-формы задней и передней панелей; положение и размер клубка; полоски шириной 292/250/168 и высотой 44 на координатной сетке 1024; верхний левый свет и тени вниз вправо. Малые варианты имеют собственные толщины и координаты в `penpot/create-master.js`. Семантические SVG IDs: `back-panel`, `chaos`, `chaos-01…`, `front-panel`, `text`, `line-1/2/3`; объёмные master также содержат `shadows` и `highlights`.

Для повторного экспорта нужен запущенный общий Penpot MCP и подключённый плагин именно этого файла/страницы:

```sh
node design/translator-icon/penpot/export-assets.mjs
node design/translator-icon/build-kit.mjs
macos/Translator/scripts/make_icon.sh
```

Сборка PNG использует `sharp@0.34.5`. На этом Mac берётся уже установленная зависимость официального MCP; на другой машине её можно установить из этого `package.json`. `pack-icns.mjs` сохраняет восемь PNG representations вместе с ICC profile; 16/32 px кодирует в родные `ic04/ic05` с premultiplied ARGB planes. Их формат сверён с выводом Apple `iconutil` и проверен его обратным чтением: alpha и непрозрачные RGB совпадают, максимальная погрешность на полупрозрачном крае меньше 1/255. Это устраняет белый fringe, который возникал при прямой упаковке этих малых variants штатным `iconutil`. `asset-manifest.json` содержит размеры, источник и SHA256 для 94 файлов; сам manifest — 95-й файл без собственного циклического checksum. `export-manifest.json` связывает SVG с board IDs. Конструктор при повторном запуске восстанавливает функцию в plugin storage и сохраняет существующий master; начальное создание требует пустой страницы. Остальные construction snippets нужны для реконструкции, не для обычного экспорта.

Микроанимация длится 1,4 секунды и заканчивается статическим знаком. При `prefers-reduced-motion: reduce` все пять анимированных элементов сразу статичны. Demo имеет кнопку повторения, а production SVG не содержит JavaScript или внешних зависимостей.

Ресурсы `Resources/AppIcon.icns`, `icons/main_icon.png` и `site/assets` подготовлены локально из этого набора. Сайт сохраняет системную типографику, layout и свою прежнюю палитру; `logoProvisional=true` оставлен до визуальной приёмки пользователем. Приложение на компьютере не переустанавливалось; приёмка Finder/Dock установленного build, Safari и Android runtime требует отдельного запуска. Commit, push и публикация в этой задаче не выполнялись.
