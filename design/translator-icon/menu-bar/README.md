# Translator · Из запутанности в ясность

Дополнение к существующему Mono icon system. Единственный примитив знака — одна непрерывная линия со скруглёнными концами: слева компактный клубок, справа ровный горизонтальный участок. Белый цвет, прозрачный фон. Связь с прежним логотипом сохранена через мотив распутывания.

Основной готовый файл: [translator-line-white.svg](translator-line-white.svg). Растровый аналог с прозрачностью: [translator-line-white.png](translator-line-white.png), 560×360. Оба подходят для вставки в макет, презентацию или страницу. Тёмный фон в просмотре нужен только для видимости белой линии и не входит в эти файлы.

Для маленькой панели на пользовательском скриншоте предусмотрен логический размер 28×18 pt: `png/translator-line-white.png`, `@2x` и `@3x`. Отдельный Tiny 20×18 pt имеет более простую геометрию, чтобы пересечения не сливались. PNG получены напрямую из вектора, а не уменьшением большого растра.

| Ресурс | Применение |
|---|---|
| `translator-line-white.svg` | Белый вектор, масштабируется без потери качества |
| `translator-line-white.png` | Белый знак 560×360 на прозрачном фоне |
| `svg/translator-line-currentColor.svg` | Inline SVG с цветом от CSS `color` |
| `svg/translator-line-black.svg` | Чёрная версия той же линии |
| `svg/translator-line-tiny-white.svg` | Упрощённый знак 20×18 |
| `png/` | 1x/2x/3x для панели и большой PNG 1120×720 |
| `macOS/TranslatorMenuBar.imageset` | Готовый template asset для Xcode |
| `penpot/*.svg`, `penpot/*.png` | Нативные экспорты четырёх новых макетов |
| `penpot/manifest.json` | Связь файлов с editable boards и path IDs |
| `preview/index.html`, `preview/preview.png` | Просмотр крупно и в реальном размере |

В [том же локальном Penpot-файле](http://localhost:9085/#/workspace?team-id=76adeac8-81da-81cd-8008-be12ef29e5bd&file-id=76adeac8-81da-81cd-8008-be13d9a96e83&page-id=76adeac8-81da-81cd-8008-be13d9a96e84) добавлены `MENU BAR · White · 28 × 18`, `MENU BAR · Template · 28 × 18`, `MENU BAR · Tiny · 20 × 18` и отдельный Graphite preview. В каждом один редактируемый Path. Исходные 15 макетов и заблокированный референс сохранены. Актуальный переносимый полный проект — [Translator-Mono.penpot](../penpot/Translator-Mono.penpot). Локальная копия `penpot/Translator-Mono-with-MenuBar.penpot` имеет те же байты и не дублируется в Git.

Для macOS перетащите `TranslatorMenuBar.imageset` в существующий asset catalog приложения. В нём уже задан `template-rendering-intent: template`; операционная система использует alpha-маску для правильного цвета. При ручной загрузке изображения задайте те же параметры:

```swift
let image = NSImage(named: "TranslatorMenuBar")
image?.size = NSSize(width: 28, height: 18)
image?.isTemplate = true
statusItem.button?.image = image
```

Настройка установленного приложения и замена его действующей menu-bar icon в эту задачу не входят. Здесь передан готовый ресурс для вставки. Большой Dock app icon из основного набора остаётся отдельным ресурсом.

Геометрия находится в `geometry.json`: один `M`, семь кубических сегментов и финальный горизонтальный `L` в основном знаке; Tiny содержит пять кубических сегментов и `L`. SVG не требуют шрифтов, фильтров, изображений, скриптов или внешних ссылок. Повторная сборка в этом проекте:

```sh
node design/translator-icon/menu-bar/penpot/build-in-penpot.mjs
node design/translator-icon/menu-bar/build-ready-assets.mjs
```

Первой команде нужен общий Penpot MCP с подключённым именно этим файлом. Вторая использует уже установленный `sharp` общего runtime на этом Mac.
