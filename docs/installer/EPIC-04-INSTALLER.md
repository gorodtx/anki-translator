# EPIC-04 · установка Translator на macOS без перетаскивания

Дата открытия: 08.10.2026. Статус: **RESEARCH COMPLETED / DISCUSSION PENDING**. Реализация не разрешена до выбора пользователя.

## Задача и результат исследования

Пользователь скачивает установщик, открывает его и устанавливает Translator кнопкой или системным мастером; перенос в Applications мышью не требуется. После успешной установки доступна опция **«Удалить установщик»**, checkbox включён по умолчанию. Удаление означает безопасное перемещение конкретного скачанного файла в Корзину после verification и освобождения образа.

Исследование: [RESEARCH.md](RESEARCH.md). Официальный Google flow подтверждает DMG с PKG. Точный cleanup checkbox Google не проверен. Рекомендация — отдельный native installer в DMG; PKG и self-install рассмотрены как альтернативы. Успех исследования не означает, что новый installer существует или прошёл Gatekeeper.

## Зафиксированный scope

- Исследованы текущие packaging/runtime источники и официальные Google/Apple документы.
- Создаются только `docs/installer/EPIC-04-INSTALLER.md`, `RESEARCH.md`, `PROGRESS.md`.
- Native session: `01a10c36-041c-73d3-b4a5-b96090075d82`; работа самостоятельно, без child agents и дубля session.
- Base: `mac@f7db5653ed7c503f554d4fadfc9e531bcda068b1`. Root владеет Git index/commit/push и общей документацией.
- Не меняются installed306, опубликованный `v0.3.1-rc.1`, backend functionality, user DB/History/Anki/settings/grants, runtime/VM/autostart, чужие design drafts. `.env`, secrets/raw env не читаются.
- Computer-use tests остановлены пользователем. Разрешение на implementation впоследствии не означает автоматическое разрешение новых UI tests, установки или публикации.

## Выбор архитектуры

| Вариант | Решение пользователя | Основной tradeoff |
| --- | --- | --- |
| **A · native installer в DMG** | Ожидается; рекомендован | Точный checkbox и контролируемый rollback. Без отдельного elevation scope — только writable target; новый per-user target выбирается явно. |
| **B · PKG в DMG** | Ожидается | Ближе к устройству Google и системной admin authorization. Точный завершающий checkbox потребует дополнительного helper либо изменения требования. |
| **C · self-install app** | Ожидается | Единая точка входа, но вмешательство в bootstrap, relaunch и permissions lifecycle; выше объём и риск. |

Не выбранный вариант не реализуется параллельно «на всякий случай». Отдельный installed target с тем же Bundle ID не создаётся молча вместо недоступной старой установки.

## Предлагаемые этапы после разрешения

1. Зафиксировать выбранный вариант, destination/admin policy, подпись и ownership code paths; назначить ровно требуемый installer target/packaging scope.
2. Реализовать install transaction: payload verification, staging, точное завершение собственной app, backup/switch/recovery, final verification. Данные остаются вне транзакции app bundle.
3. Реализовать завершающий UX и безопасный cleanup с отдельными install/cleanup результатами. Сохранить approved native styling и artwork.
4. Выполнить целевые проверки ошибок на fixtures/изолированных temporary targets; не скачивать пользовательские БД для packaging tests.
5. Только при отдельном разрешении выполнить real downloaded install/update/UI/TCC acceptance на поддерживаемом Mac; затем отдельное решение о публичной доставке.

Все пять этапов сейчас **NOT STARTED**. Финансовое/организационное решение по Apple Developer Program остаётся отдельной зависимостью публичной дистрибуции.

## Будущие критерии приёмки

| ID | Проверяемый результат | Нужное доказательство; текущий статус |
| --- | --- | --- |
| I-01 | Установка без drag: открытие installer → действие установки → явный результат. | Реальная desktop проверка выбранного UX; **не выполнено**. |
| I-02 | Final checkbox «Удалить установщик» показан только при успешной установке; начальное состояние ON, отключение сохраняет источник. | Source/state checks + лично проверенный final screen; **не выполнено**. Для plain PKG контракт ещё не согласован. |
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

- **DONE:** current code review, reconciliation истории, официальные Google/Apple facts, три варианта, recommendation, зависимости и future acceptance matrix.
- **UNKNOWN:** реальный Google checkbox/default, новый installer runtime/cleanup, update TCC, Gatekeeper на чистом Mac, end-to-end пользователя.
- **PENDING USER:** A/B/C; для выбранного варианта destination/admin policy и допустимая первая поставка без Developer ID.
- **PENDING ROOT:** отдельная Git-доставка замороженных трёх документов; current HEAD/hashes переданы в финальном отчёте.

Журнал и exact resume command: [PROGRESS.md](PROGRESS.md). Реализация не начата.
