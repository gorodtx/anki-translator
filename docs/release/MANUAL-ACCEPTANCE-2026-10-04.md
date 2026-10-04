# Ручная приёмка Translator — 04.10.2026

Владелец: Main + пользователь, который сам кликает native-приложение. Статус: **WAITING_FOR_USER_WALKTHROUGH**. Presentation Layer передан соседней сессии и не должен менять app UI или мешать этому проходу.

## Правила фактической проверки

Перед первым сценарием записать actual app path/version/build/source identity. Опубликованный кандидат: v0.3.0 (295), tag84b1852, sourcec248. Нельзя переносить результат теста установленной старой версии на новый артефакт.

После каждого пользовательского шага дописывать: действие/ожидание, наблюдение пользователя, source/runtime/log подтверждение Main, PASS/FAIL/UNKNOWN, screenshot при наличии, найденный дефект и исправление/повторная проверка. Пользователь сам ведёт GUI; Main не меняет текущие Settings/профили и не закрывает приложение ради параллельного сайта.

## Последовательность

1. Версия и текущая установка → запуск → Settings/Sources readiness.
2. Простая фраза EN→RU через подтверждённый Services путь.
3. History → повторное открытие результата → сохранение после normal Quit/restart.
4. Физический input/hotkey и конкретные дополнительные приложения с записью названий/версий.
5. Anki: только после явного определения рабочего синхронизированного профиля; собственный test note, без изменения чужих карточек.
6. VoiceOver/несколько дисплеев и физический drag при доступном оборудовании.

D05 public Gatekeeper/signing остаётся отдельным внешним блокером; локальный ручной проход не объявляется notarization acceptance. Старые измерения сохраняются в [эпике приложения](EPIC-02-APPLICATION.md); новые наблюдения этого прохода ещё отсутствуют.

## M001 — 04.10.2026: установленная версия отличается от release-кандидата

Main read-only прочитал Info.plist: `/Users/den/Library/Application Support/Translator/releases/current/Translator.app` — 0.3.0 (282). `~/Applications/Translator.app` указывает на этот же app; `/Applications/Translator.app` при проверке отсутствует. Installed build-info.json в ожидаемом Resources path не найден, поэтому source identity установленной копии не подтверждена этим чтением. Это проверка файлов установки, не новый GUI/runtime сценарий.

Для приёмки опубликованного кандидата нужен 0.3.0 (295). Локальный проверенный образ: [Translator-0.3.0-macos-arm64.dmg](/Users/den/Documents/dev/translator-evidence/2026-10-03/delivery/final-assets-tag-clean/Translator-0.3.0-macos-arm64.dmg). Это уже проверенные release bytes; отдельный браузерный quarantined download/Gatekeeper сценарий остаётся D05.

Пользователь сам выполняет normal Quit старой копии, открывает локальный образ, физически переносит Translator.app в Applications и запускает новую копию. Main не закрывал приложение, не копировал app, не менял Settings/профили и не открывал Anki. После действий пользователя записать фактическую версию, наблюдения первого запуска и readiness.

## M002 — 2026-10-04T20:07:18.003943+00:00 — пользовательский FAIL Accessibility и Settings

Пользователь подтвердил два дефекта на текущей установке: разрешение видно включённым в macOS, Setup сообщает denied/capture не запускается; уже открытые Settings не выходят вперёд при выборе из menu bar. Actual screenshots сохранены без редактирования в native-hotfix/user-accessibility-enabled.png и user-app-accessibility-denied.png. Main выполняет исправления самостоятельно; это новая явная инструкция, прежняя граница read-only сайта не запрещает native hotfix/restart. Live installed Info.plist build282 подтверждён. Actual grant/selected text/menu acceptance после исправления пока не выполнены.

## M003 — 2026-10-04T20:31:06.625879+00:00 — новая копия реально запущена

Installed0.3.0(300)/source30adcf27/nativebyte-match/sealPASS; oldexactPID69352 остановлен, new shell28849/backend28866/helper28867 подтверждены. Current UDS ping подтверждает3DB и AppleENRUinstalled. История не очищалась, базы повторно не скачивались. System Settings row Translator=1 лично прочитан; appstoredtrust=0. UI changed between observation/click: stale element action rejected, toggle не был изменён Main. User получил два конкретных native test вопроса; не считаем отсутствие ответа согласием/успехом. Legacy bootstrap5 отмечен A29, ordinary app runtime recovered.


### M004 — 2026-10-04T20:43:15.415286+00:00: реальный ответ на build300

Пользователь: «Settings остаются позади или не появляются». Accessibility toggle включён, перевод не работает. **Оба физические сценария FAIL**, предыдущие unit/runtime/Z-order результаты остаются в своём измеренном объёме. Дополнительно обнаружены дубликаты Spotlight; пользователь запросил оставить одну рабочую копию. Root продолжает самостоятельно.


### M005 — 2026-10-04T20:54:11.949428+00:00: canonical302 для новой физической проверки

Одна /Applications/Translator.app, source43af6cb, seal verified, backend/helper/DB3/Applepair/history IPC PASS. tccd signature mismatch доказан, saved shortcut **⇧⌘T**. Пользователю отправлены конкретные steps для exact installed copy и обоих bugs. **A27/A28 WAITING_USER**, A30 duplicate cleanup PASS. Нет нового public release и утверждения «всё исправлено».
