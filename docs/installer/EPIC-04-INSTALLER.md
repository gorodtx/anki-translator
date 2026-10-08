# EPIC-04 · установка Translator на macOS без перетаскивания

Дата открытия: 08.10.2026. Статус: **B SELECTED / IMPLEMENTATION DEFERRED**. Пользователь выбрал B и отдельно указал: «пока к реализации не переходим». Выбор архитектуры не разрешает implementation.

## Задача и результат исследования

Пользователь скачивает установщик, открывает его и устанавливает Translator кнопкой или системным мастером; перенос в Applications мышью не требуется. После успешной установки доступна опция **«Удалить установщик»**, checkbox включён по умолчанию. Удаление означает безопасное перемещение конкретного скачанного файла в Корзину после verification и освобождения образа.

Исследование: [RESEARCH.md](RESEARCH.md). Официальный Google flow подтверждает DMG с PKG. Точный cleanup checkbox Google не проверен. Первоначальная рекомендация исследователя была A; после обсуждения пользователь выбрал **B: PKG в DMG с отдельным завершающим шагом для default-on checkbox**. Успех исследования и выбор B не означают, что новый installer существует или прошёл Gatekeeper.

## Зафиксированный scope

- Исследованы текущие packaging/runtime источники и официальные Google/Apple документы.
- Создаются только `docs/installer/EPIC-04-INSTALLER.md`, `RESEARCH.md`, `PROGRESS.md`.
- Native session: `01a10c36-041c-73d3-b4a5-b96090075d82`; работа самостоятельно, без child agents и дубля session.
- Base исследования: `mac@f7db5653ed7c503f554d4fadfc9e531bcda068b1`; base текущей docs-доставки — `ecd1da38406593f3b972433c95b177fc25fbc8d3`. Root передал этой существующей полной сессии Git lease только для трёх installer docs и dated append `design/PROGRESS.md`. Общие README/site и прочие journals остаются у Root; чужие design paths не включаются в index.
- Не меняются installed306, опубликованный `v0.3.1-rc.1`, backend functionality, user DB/History/Anki/settings/grants, runtime/VM/autostart, чужие design drafts. `.env`, secrets/raw env не читаются.
- Computer-use tests остановлены пользователем. Разрешение на implementation впоследствии не означает автоматическое разрешение новых UI tests, установки или публикации.

## Выбор архитектуры

| Вариант | Решение пользователя | Основной tradeoff |
| --- | --- | --- |
| **A · native installer в DMG** | Не выбран; первоначальная рекомендация исследователя | Точный checkbox и контролируемый rollback. Без отдельного elevation scope — только writable target; новый per-user target выбирается явно. |
| **B · PKG в DMG + завершающий шаг** | **Выбран пользователем; implementation отложена** | Системный мастер и admin authorization. Требование точного default-on checkbox сохраняется; отдельный helper/его безопасный запуск ещё предстоит спроектировать. |
| **C · self-install app** | Не выбран | Единая точка входа, но вмешательство в bootstrap, relaunch и permissions lifecycle; выше объём и риск. |

Не выбранный вариант не реализуется параллельно «на всякий случай». Отдельный installed target с тем же Bundle ID не создаётся молча вместо недоступной старой установки.

Ожидаемый будущий UX B: скачать DMG → открыть PKG → системный мастер → при необходимости подтвердить права администратора → успешная установка → завершающий шаг с «Удалить установщик» ON → безопасный eject/Trash → запуск Translator. Точные destination/admin и finish-helper mechanics пока не утверждены. Postinstall от root не получает право удалять пользовательский DMG или выдавать TCC grants.

## Текущий первый запуск: обсуждение после выбора B

Текущий опубликованный путь остаётся drag DMG. Ни PKG, ни завершающий checkbox пока не реализованы. Минимальная готовность к переводу и полная настройка приложения разделены в [RESEARCH.md](RESEARCH.md#текущий-сценарий-нового-пользователя).

По source review текущий first-run checklist считает offline DB, Accessibility и shortcut обязательными; Apple language pair, Dictionary, Anki и login item имеют собственные шаги. Backend может запуститься без DB; Services не требует AX grant; Google provider работает по сети. Поэтому незавершённый checklist не тождествен отсутствию любого способа перевода. Первое реальное lookup на чистом Mac не проверялось.

Для следующего обсуждения записана UX-потребность: понятный путь к первому переводу и отдельное подключение расширенных возможностей. Изменение setup gates, master onboarding или backend functionality **не разрешено выбором B** и не включено автоматически в installer implementation.

## Предлагаемые этапы после разрешения

1. Для выбранного B утвердить destination/admin policy, завершающий helper, подпись и ownership code paths; назначить ровно требуемый installer target/packaging scope.
2. Реализовать install transaction: payload verification, staging, точное завершение собственной app, backup/switch/recovery, final verification. Данные остаются вне транзакции app bundle.
3. Реализовать завершающий UX и безопасный cleanup с отдельными install/cleanup результатами. Сохранить approved native styling и artwork.
4. Выполнить целевые проверки ошибок на fixtures/изолированных temporary targets; не скачивать пользовательские БД для packaging tests.
5. Только при отдельном разрешении выполнить real downloaded install/update/UI/TCC acceptance на поддерживаемом Mac; затем отдельное решение о публичной доставке.

Implementation-этапы сейчас **NOT STARTED**; B выбран только как архитектура. Финансовое/организационное решение по Apple Developer Program остаётся отдельной зависимостью публичной дистрибуции.

## Будущие критерии приёмки

| ID | Проверяемый результат | Нужное доказательство; текущий статус |
| --- | --- | --- |
| I-01 | Установка без drag: открытие installer → действие установки → явный результат. | Реальная desktop проверка выбранного UX; **не выполнено**. |
| I-02 | Final checkbox «Удалить установщик» показан только при успешной установке; начальное состояние ON, отключение сохраняет источник. | Source/state checks + лично проверенный final screen; **не выполнено**. Для выбранного B требуется отдельный завершающий шаг; plain PKG не объявляется выполнением этого критерия. |
| I-03 | В destination попадает полный bundle: native executable, Python/backend, sidecar, AppIcon/MenuBar и build identity; подписанные resources не меняются после подписи. | Artifact manifest + strict codesign/resource verification; **не выполнено для нового installer**. |
| I-04 | `com.translator.desktop`, `LSUIElement`, accessory policy и Services сохранены. | Metadata/source + установленный runtime по отдельному разрешению; **не выполнено**. |
| I-05 | Установка в writable target не требует лишних прав; недоступный target/отмена admin prompt оставляет старую app. | Standard-user scenarios, cancel/deny; **не выполнено**. |
| I-06 | Running app определяется по точной identity/path/PID и штатно завершает свой child. Чужой/legacy backend не завершается. | Ownership checks и целевой update scenario; **не выполнено**. Broad pkill не допускается. |
| I-07 | Copy/verification/switch failure и crash между rename оставляют восстанавливаемую старую app; recovery не выдаёт ложный PASS. | Failure injection + transaction journal/recovery; **не выполнено**. |
| I-08 | Support/DB/History/settings/Anki-profile не читаются для копирования и не удаляются. Штатное завершение даёт History flush. | Fixtures, path-denial checks, отдельно разрешённый update контроль; **не выполнено**. Raw user data не публикуются. |
| I-09 | Cleanup работает только с доказанным исходным DMG/PKG; после detach перемещает его в Trash. | Identity check, detach status, Trash result URL; **не выполнено**. |
| I-10 | Busy mount, неизвестный source, file substitution, symlink, deny/отмена сохраняют installer и дают отдельный cleanup status. | Negative cases, без force eject/широкого rm; **не выполнено**. |
| I-11 | При повторном запуске/двух installers нет смешивания transactions или двойной замены app. | Lock/idempotency tests; **не выполнено**. |
| I-12 | Новая app показывает фактический AX trust; installer не выдаёт grant и не сбрасывает TCC. | Permission source review + отдельно разрешённая OS проверка update; **не выполнено**. |
| I-13 | Developer ID Application/Installer применены по типу артефакта, notarization/stapling проверены, clean-Mac Gatekeeper отдельно принят. | Distribution receipts + quarantined download first launch; **не выполнено; Developer Program отсутствует по ответу пользователя**. |
| I-14 | UI использует существующую native identity, системные controls, keyboard/focus/accessibility и approved ресурсы. | Source + light/dark/Retina/keyboard acceptance по разрешению; **не выполнено**. |

«Установлено» означает успешное копирование, переключение и verification установленной app. Готовность offline DB, Accessibility, Anki и login item показывается независимо и не выдаётся за завершённую установщиком настройку.

## Ограничения rollback и удаления

Rollback относится к app bundle. Возврат новой History/DB schema к старой не гарантируется и требует отдельного миграционного контракта. Backup хранится отдельно от user data и удаляется только по согласованной политике.

Cleanup запускается вне mounted image. Отсутствие безопасного handoff, неуспешный detach или неопределённый backing file оставляют исходник нетронутым. Default-on checkbox выражает выбор пользователя, а не разрешение удалять любые похожие файлы. При cleanup error корректная установка остаётся успешной с отдельным сообщением.

## Checkpoint исследования

- **DONE:** current code review, reconciliation истории, официальные Google/Apple facts, три варианта, первоначальная recommendation, выбор пользователя B, current first-run/minimum/full-feature разбор, зависимости и future acceptance matrix.
- **UNKNOWN:** реальный Google checkbox/default, новый installer runtime/cleanup, update TCC, Gatekeeper на чистом Mac, end-to-end пользователя.
- **PENDING USER:** отдельное разрешение implementation; destination/admin policy и допустимая первая поставка без Developer ID. Повторно выбирать A/B/C не требуется.
- **DELIVERY:** прежнее research находится в commit `ecd1da38406593f3b972433c95b177fc25fbc8d3`; remote receipt Root сохранён отдельно. B/first-run дополнения доставляет эта же standalone сессия по явно переданному Git lease, только четырьмя owned paths. Final commit/remote/public bytes/CI фиксируются после push в `INSTALLER-B-DELIVERY.json` и `.md` рядом с Root receipt; текущие future implementation критерии не становятся PASS от Git-доставки.

Журнал и exact resume command: [PROGRESS.md](PROGRESS.md). Реализация не начата.
