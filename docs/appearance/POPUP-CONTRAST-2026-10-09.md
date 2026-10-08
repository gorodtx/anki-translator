# Контраст нативного попапа, 09.10.2026

Задача получена напрямую от пользователя: белый текст перевода становится нечитаемым
над светлой страницей; работу перевода сохраняем. Роль — существующая самостоятельная
сессия Translator-Brand-Web, native ID `01a10317-15e0-7c12-a4ac-dcfddc86ce9d`.
Рабочий каталог `/Users/den/Documents/dev/selection_translator_anki`, ветка `mac`, база
`6a6cad838d5ab682707c59404233b9270de44269`. Индекс, установленное приложение и релиз
не входят в эту правку. Root подтвердил свободные popup-пути сообщением
`msg_d88ea03cfc23`; это координация ownership, а не визуальная приёмка.

## Причина и решение

Исходный `NSHostingView` рисовал текст соседом поверх `NSGlassEffectView`. Стекло могло
стать светлым над светлой страницей, тогда как текст сохранял белый цвет тёмной темы
приложения. Apple прямо описывает необходимость `contentView` для адаптивной читаемости
и запрещает этот sibling-порядок в
[WWDC25: Build an AppKit app with the new design, 17:30–18:42](https://developer.apple.com/videos/play/wwdc2025/310/).
Это совпадение исходной иерархии с описанным Apple механизмом; независимый живой
repro на странице пользователя не выполнялся.

Хостинг перенесён в `glass.contentView`. Один слой `.regular` Liquid Glass, системные
шрифты, радиусы 12/7 pt, отступы, геометрия, анимация размеров и управляющие действия
сохранены. Фабрика `makeSurface` позволяет проверять настоящую production-иерархию,
не показывая окно и не запуская приложение пользователя.

После присваивания `panel.contentView` отдельно вызывается `roundSurface`: только
после attachment доступен `container.superview`, чей слой тоже должен сохранить
cornerRadius/masksToBounds. Detached factory округляет container; production caller
повторяет обработку после attachment, как в исходном приложении.

Историческая заметка `popup-panel-rules.md` от 27.09 отмечала другой дефект:
`.secondary/.tertiary` вместе с выделяемым текстом внутри стекла превращались в
`.primary`. Поэтому вторичный текст использует адаптивный `.primary` с opacity 0.65,
а disabled-строки — opacity 0.4; выделенная активная строка сохраняет белый текст.
Так AppKit управляет контрастным foreground, а иерархия задаётся прозрачностью view.
Это визуальная корректировка, без изменения данных или логики перевода.

## Источники и ограничения доказательств

Внешняя папка evidence:
`/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast`.

- [Скриншот пользователя](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/user-reported-popup.png)
  SHA256 `38d57a41e3465ce868bf63e92fa94ed3c2a29322530dd310c7cb6c7ddfa40763`.
  Настоящий сообщённый пользователем дефект; это не новая съёмка агента.
- `tone-probe.swift` — диагностический specimen, а не приложение/реальный перевод.
  Hidden-window `cacheDisplay` создал пустые белые PNG. Лично просмотрены
  `tones-light-nested.png`, `tones-dark-nested.png`, `tones-dark-sibling.png`:
  **RED / непригодны для проверки пикселей**, не визуальный PASS.
- Native check использует production SwiftUI/AppKit исходники с явно заданным
  fixture `Loved` и отключённым IPC. Это проверка структуры/геометрии, не реальный
  lookup, не screenshot сайта и не проверка установленного приложения.
- Глобальная тема macOS, TCC, clipboard, Anki, профили, базы и установленный Translator
  не изменяются. Окна проверок остаются скрытыми. CUA, браузер, VM и сервер не запускаются.

## Журнал

- 09.10 00:38–00:43 MSK: прочитаны актуальные инструкции пользователя, skills
  `preserve-project-design`, `context-continuity`, Orca orchestration/CLI, matching
  CONTINUE и исторические popup-правила; `git status/log` и ancestry EXIT0.
  Чужие design drafts/deletion сохранены. Root уведомлён `msg_e5149628a1a4`,
  соседняя installer-сессия — `msg_7e7c63d5b9a0`; новые агенты не создавались.
- 09.10 00:42 MSK: официальный WWDC transcript прочитан; documentation `contentView`
  JS-only/Markdown fetch unavailable, детали взяты из WWDC, а не из недоступной страницы.
  Диагностический offscreen specimen compiled/run EXIT0, пиксельный результат RED.
  Ограничение передано Root `msg_a1677829dbaf`.
- 09.10 00:45–00:47 MSK: минимальная правка двух popup-файлов; `sh -n` и scoped
  `git diff --check` EXIT0. `git diff --quiet HEAD` для AppModel/IPC/TranslatorApp,
  TranslatorCore/backend/translate_logic EXIT0: функциональные исходники не менялись.
- 09.10 00:47 MSK: `uv run --no-sync ruff check .` PASS; `uv run --no-sync python -m mypy`
  PASS108. `uv run --no-sync python scripts/check_python_format.py` RED на трёх
  существовавших чужих untracked `design/translator-icon/github/revisions/{v2,v3,v4}/build-svg.py`;
  129 остальных файлов formatted. Чужие скрипты не правились, gates не обходились.
  Точные результаты: [ruff.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/ruff.log),
  [format.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/format.log),
  [mypy.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/mypy.log).
- 09.10 00:48–00:53 MSK: production release build EXIT0; 169 Swift tests EXIT0.
  Исходная sibling-иерархия дала ожидаемый RED/EXIT1, исправленная — GREEN/EXIT0
  во всех четырёх AppKit appearances. Проверены отсутствие sibling foreground,
  принадлежность host к glass.contentView, regular/radius, единственный владелец
  размера, resize 440×650→380×400, hidden state, неизменность fixture/IPC/footer.
  Каждый результат получен запуском отдельного production-source probe; это не
  измерение контраста пикселей. Повтор `check_python_format.py` сохранил **EXIT1**
  на тех же трёх чужих design scripts, [format-final.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/format-final.log).
- 09.10 00:56–00:58 MSK: обработан independent source review Root
  `msg_23b61f9b5d35`: извлечение фабрики перенесло округление до attachment и потеряло
  parent/root layer. Подтверждено чтением diff, исправлено вызовом `roundSurface`
  после attachment; native probe теперь создаёт настоящий `TranslationPanel` и
  дополнительно проверяет parent cornerRadius/masksToBounds. Старые 35 PASS и
  `handoff-before-corner-review.json` сохранены как ранняя ограниченная версия.
  Новые production release/native-final проверки выполняются; финальный freeze
  будет сформирован по их результатам. Root уведомлён `msg_184117608a06`.
- 09.10 00:59–01:00 MSK: final native probe **EXIT0, 39 PASS / 0 FAIL**, включая
  все четыре parent-layer assertions; production release rebuild **EXIT0**.
  Root source review `msg_0c31227f39a0` отдельно подтвердил post-attachment порядок,
  не заявляя pixel/runtime acceptance. Финальная проверка checksum inputs probe,
  scoped diff и base ancestry EXIT0; функциональные исходники снова без diff.

## Проверки и оставшиеся ограничения

- `swift build -c release` в `macos/Translator`: **EXIT0**, 106.43 s;
  [production-build.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/production-build.log),
  SHA256 `93bbc9bdc22e1600164a57a5ed2921e89864f78840d11719bd72b877f889cc7d`.
- `macos/Translator/scripts/swift-test.sh`: **EXIT0, 169 tests / 31 suites PASS**;
  [swift-tests.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/swift-tests.log),
  SHA256 `6f0847a1fe8dbfef1eeebbf07022accd299cb110be236b67f40065a3364468b5`.
- Native RED на извлечённой, но ещё неисправленной production-иерархии:
  `sh macos/Translator/scripts/popup-appearance-check.sh /Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/red`
  **EXIT1, 12 FAIL / 23 PASS**; 3 неправильных отношения host/glass во всех 4 темах.
  [red/check.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/red/check.log),
  SHA256 `12100591f6d0b5bf9b7764da4cca8202bfad400913908b8edc401562f0373a6e`.
  RED build — release/188.39 s; последующий regression probe — debug, а настоящий
  production release build проверен отдельно.

- Ранняя Native GREEN, **до** проверки root-layer attachment:
  `sh macos/Translator/scripts/popup-appearance-check.sh /Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/green`
  **EXIT0, 35 PASS / 0 FAIL**, debug build 211.15 s;
  [green/check.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/green/check.log),
  SHA256 `7d9dd1333650df079422286db3761ed14261a70dce48f82221d0a2bfe5f7450d`.
- Финальная Native GREEN после parent-layer исправления:
  `sh macos/Translator/scripts/popup-appearance-check.sh /Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/green-final`
  **EXIT0, 39 PASS / 0 FAIL**, debug build 122.83 s;
  [green-final/check.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/green-final/check.log).
  Утверждения о rounded edge/shadow в этом log проверяют **свойства слоя**,
  а не изображение тени, углов или контраст пикселей.
- Финальная production release сборка после parent-layer исправления:
  `swift build -c release`, **EXIT0**, 55.69 s;
  [production-build-final.log](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/production-build-final.log).
  169 тестов чистого TranslatorCore относятся к неизменённым функциональным
  исходникам; новый surface helper проверен дополнительным native probe.

09.10 00:54–00:56 MSK: промежуточные `git status/log`, ancestry, scoped diff check и
проверка отсутствия функционального diff EXIT0; HEAD остался равен базе `6a6cad8`.
Два собственных временных Swift packages после trap отсутствуют; процесс probe
PID13040 завершён, окна не показывались. Итоговый [handoff.json](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/handoff.json)
содержит точные SHA256 пяти путей и evidence, cleanup и пределы каждого результата;
[source.patch](/Users/den/Documents/dev/translator-evidence/2026-10-09/popup-contrast/source.patch)
содержит только два UI-файла. Ни серверов, ни контейнеров этот проход не запускал.
После final-run подтверждено удаление третьего собственного временного package
и завершение PID35757. Пять именованных путей заморожены для Root; общий Git index
и HEAD не изменены этой сессией.

Фактическая читаемость на светлом/тёмном/пёстром фоне, выделение текста,
hover/keyboard, reduced transparency и установленная сборка требуют отдельной
пиксельной/desktop приёмки: скрытый AppKit-тест этого не доказывает.

Правка подготовлена в пяти именованных путях: `PopupPanel.swift`,
`TranslationPopupView.swift`, `scripts/popup-appearance-check.swift`,
`scripts/popup-appearance-check.sh` под `macos/Translator/` и этот отчёт.
Отчёт и manifest передаются Root; общий эпик и прежние RED не закрываются этой
ограниченной source/offscreen проверкой. Commit/push/CI/install/release для новой
правки **NOT_DONE**; имеющаяся сборка пользователя не заменялась.

Сессия сохраняется; после её остановки возобновлять единственный экземпляр командой:
`cd '/Users/den/Documents/dev/selection_translator_anki' && codex resume '01a10317-15e0-7c12-a4ac-dcfddc86ce9d'`.
