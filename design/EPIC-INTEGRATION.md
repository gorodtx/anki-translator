# Translator Mono — внедрение

Дата начала: 05.10.2026. Основание: прямое поручение пользователя внедрить принятый набор из `final/`, без повторной генерации. Исходная база — `mac`, `6931540ad76a6ab7a5abe70d49c513e93e881d36`. Снимок подготовки — [delivery-verification.json](delivery-verification.json); полный контракт — [THREE-AGENT-HANDOFF.md](THREE-AGENT-HANDOFF.md). История дополняется; прежние результаты подготовки не переписываются.

## Владельцы и требования

Работают ровно три самостоятельные Orca-сессии. GitHub владеет README, дизайном, Social preview, карточкой профиля и общей Git-доставкой. macOS владеет ресурсами приложения, template-знаком, двумя путями сборки и установленной копией. Web владеет сайтом, favicon и приёмкой браузеров. Полные границы перечислены в handoff. Индекс и Git операции сериализованы у GitHub. Один редактор Penpot — GitHub; готовые рисунки не меняются.

| ID | Требование и доказательство | Начальное состояние |
|---|---|---|
| B01 | Все 12 final exports совпадают с manifest и источниками по SHA256/bytes | PASS: проверено 05.10.2026 |
| B02 | Новый логотип и короткая русская подача в README; ссылки и ad-hoc ограничения сохранены; реальный GitHub render после push | IN_PROGRESS |
| B03 | Social preview: загрузка выбранной RU card, сохранение, повторное чтение и изображение; внешние кеши отдельно | IN_PROGRESS |
| B04 | Дополнительная карточка profile README с сохранением оформления либо точная отсутствующая зависимость | NOT_DONE: `gorodtx/gorodtx` отсутствует в доступном списке 12 репозиториев; прямой GET 404 |
| B05 | 10 ICNS representations и оптические размеры сохраняются; установленный AppIcon просмотрен | IN_PROGRESS: macOS |
| B06 | Непрерывный menu template 28×18 pt, 1x/2x/3x; вид light/dark/Retina и открытие меню | IN_PROGRESS: macOS |
| B07 | Оба пути сборки пакуют ресурсы до подписи; strict codesign; bundle/DMG проверены отдельно | IN_PROGRESS: macOS |
| B08 | Восстановимая замена фактической установки, exact PID, сохранение данных/grants; Settings/About/перевод/история | IN_PROGRESS: macOS |
| B09 | Web логотип обеих тем, favicon/apple-touch, единый media contract; стиль сайта сохранён | IN_PROGRESS: Web |
| B10 | HTTP root/subpath, desktop/mobile390, light/dark, focus/keyboard/reduced motion/console, просмотр PNG | IN_PROGRESS: Web |
| B11 | Chromium и Safari/WebKit имеют отдельные фактические результаты | IN_PROGRESS: Web |
| B12 | Поимённые логические коммиты, normal gates, общий push, remote SHA и CI финального SHA | NOT_DONE |
| B13 | Три role reports и registry native ID/resume/owned paths/evidence перед остановкой | IN_PROGRESS |

## Границы публичной доставки

Новый публичный release, hosting/domain и аватарка пользователя этой задачей не выбраны. Существующий `v0.3.0` и его assets сохраняются. Настоящее видео, poster/captions пока отсутствуют; имитация не допускается. Большие SQLite-базы не загружаются повторно. Дизайн и рабочие отчёты остаются в репозитории, но корневая `design/` не входит в app/DMG.

## Новые знания 05.10.2026

- Подходящая Web-сессия переиспользована. Resume сохранённого macOS ID `01a08ff5-3879-78f0-a8ea-d0d6a318ce2d` вернул native lock «This conversation is open in another app». Попытка завершена без работы; новая полноценная macOS-сессия запущена в той же третьей вкладке. Заблокированный ID не запускается параллельно.
- GitHub API подтверждает аккаунт `gorodtx`, admin/push у целевого репозитория и default branch `mac`. Это не доказательство push.
- Root `penpot-tool doctor` сначала подтвердил подключение и правильные file/page IDs. Поздние отдельные вызовы соседей получили `fetch failed`; эти наблюдения сохраняются отдельно. Runtime/MCP/VM не перезапускаются, внедрение использует проверенные экспорты.

Текущее движение и доказательства — [PROGRESS.md](PROGRESS.md); итоговые отчёты — `integration/`.

## Дополнение 05.10.2026, приёмка интеграции

- B03: сохранённый GitHub Social preview подтверждён GraphQL и HTTP200 image/png; actual CDN bytes104880/SHA совпадают с утверждённой RU карточкой. Внешнее распространение и кеши отдельно NOT_DONE.
- B09/B10: Web локально принят владельцем, Root сверил13file/6screenshot hashes и лично просмотрел desktop/mobile/focus. Chromium и HTTP root/subpath PASS; B11 Safari/WebKit остаётся NOT_DONE. Настоящего видео ещё нет; null слот сохранён.
- B05/B07: оба native builder, strict codesign и локальный DMG измерены macOS; установлен build305, отдельные Finder/Get Info screenshots доступны. Реальный menu light/dark/Retina и Settings/About/перевод/история продолжают проверяться.
- Новое требование B08: ad-hoc подпись новой сборки изменила identity и реальный Accessibility trust стал false. Недостаточно сохранённой старой настройки: приёмка shortcut требует authoritative trust после ручной reauthorization пользователя. Не сбрасывать TCC, не обходить trust и не переподписывать сборку после reauthorization. Пользователь подтвердил открытие Settings через настоящее меню.
- B12: source/design commit `db03fd9` прошёл normal gates после штатного исправления broken future Markdown link. Web/native коммиты и общий push/CI ещё ожидаются; базы не загружались.

## Дополнение 05.10.2026, source delivery checkpoint

- B12: Web13paths зафиксированы в `c2cd5c6`, native12paths в `bb8ed09`; normal gates прошли, installed305 bytes не изменились. Явный token dry-run для `HEAD:refs/heads/mac` прошёл; actual push и CI проверяются отдельно.
- B13: все native IDs/resume commands и role reports сохранены; Web terminal retained, native task остаётся live с открытыми B06/B08. Публикация source с pending acceptance не закрывает эти пункты и весь epic.
- Уточнение B04: измерено отсутствие `gorodtx/gorodtx` именно в доступном списке12repo плюс GET404. Эти факты не доказывают отсутствие любого скрытого/private репозитория. Для публичной карточки требуется доступный подходящий profile README repository; account avatar/Pins остаются вне изменения.
- Новая воспроизводимость B05: ICNS включает десять image representations плюс служебный `TOC ` chunk. Счётчик проверки обязан отличать container metadata от representations; Root исправил временный harness, approved artwork не менялся.

## Дополнение 05.10.2026, измеренная внешняя доставка

- B12 source PASS: `bb8ed09` actual push/remote SHA verified; CI run37322053249 completed/success,5applicable jobs success/notarize skipped. Evidence commit требует отдельной проверки своего SHA; новые данные дополняют журнал, прежние snapshots сохраняются.
- B02 published HTML/assets PASS: GitHub server отдаёт утверждённый img80×80 и подпись; exact src HTTP200/PNG/SHA совпадает с approved export. Browser visual screenshot остаётся UNKNOWN после пользовательской смены desktop; чужой capture удалён из evidence recoverably, не выдан за результат Translator.
- B03 PASS — upload/save/public image; B04 dependency declared — нужен доступный public profile README repository; account/Pins не менялись.
- B06/B08 всё ещё открыты: личные native visual checks и новый Accessibility/shortcut/History outcome требуют доступного наблюдения/ответа пользователя. Сохранение source/CI результата не закрывает этот участок. Ровно три самостоятельные sessions сохраняются; native ожидает один blocking outcome вместо расходующего бюджет polling loop.
